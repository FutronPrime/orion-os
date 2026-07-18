#!/usr/bin/env bash
# orion-transcribe.sh — multi-engine video/audio transcription cascade.
#
# WHY: no single transcriber wins every case. Hosted LLM URL-ingest is fast but rejects long
# (>~2h) videos; yt-dlp captions hit HTTP 429 and don't exist for many live VODs; cloud
# quotas run out. This orchestrator TRIES engines in order until ONE succeeds, so you never
# hit a "can't transcribe" wall again. The local chunked-whisper engine is the SOVEREIGN
# FLOOR: it handles ANY length, needs no captions, and has no rate limits.
#
# Engine order (each a capability seam; skip/reorder with --engines):
#   1. gemini             — optional `gemini` CLI transcription (fast; skipped if CLI absent)
#   2. ytdlp-subs         — yt-dlp auto/uploaded captions (cheap when present)
#   3. local-whisper      — yt-dlp audio -> ffmpeg CHUNK -> whisper per chunk -> stitch (ANY length, sovereign)
#   4. transcribe-anything — optional pip engine (insanely-fast-whisper), auto-installed on demand
#   5. aws-transcribe     — optional cloud last resort (needs AWS creds + S3 bucket in env)
#
# Open-source engines this design draws from (technique = local chunked whisper + engine variety):
#   transcribe-anything, buzz, vibe, AI-Video-Transcriber, long-video-transcripts,
#   aws-video-transcriber.
#
# Usage:
#   orion-transcribe.sh <url|id> [--out FILE] [--ingest] [--ingest-db PATH] [--model base]
#                        [--engines gemini,local-whisper] [--chunk-secs 600] [--lang en]
#                        [--frames] [--scene 0.3] [--interval 30] [--max 60]
#   orion-transcribe.sh --file urls.txt [--ingest --ingest-db ./transcripts.db]
#   orion-transcribe.sh --local <audio_or_video_file> [--out FILE] [--frames]
#
# --frames: after a transcript succeeds, extract VISUAL keyframes INLINE (self-contained;
#   ffmpeg scene-change detection, yt-dlp <=720p fetch for remote sources). Frames land in
#   `<id>-frames/` alongside the transcript with a frames.md index. Frame failure NEVER fails
#   the transcript. Tune with --scene (scene-cut threshold, default 0.3), --interval (seconds
#   for the fps fallback when <2 scene cuts, default 30), --max (max frames, default 60).
#
# Dependencies: yt-dlp, ffmpeg/ffprobe, and one of `whisper` (openai-whisper) or `mlx_whisper`.
# Optional: `gemini` CLI, `transcribe-anything`, `aws` CLI. --frames uses only ffmpeg + yt-dlp.
#
# Exit 0 if a transcript was produced by ANY engine; 3 if every engine failed (with a diagnosis).
set -uo pipefail

WORK="${TMPDIR:-/tmp}/orion-transcribe.$$"
MODEL="base"; CHUNK=600; LANG="en"; OUT=""; INGEST=0; INGEST_DB=""; LOCAL=""; FILE=""
FRAMES=0; SCENE="0.3"; INTERVAL=30; FRAMESMAX=60; CUR_SRC=""
ENGINES="gemini,ytdlp-subs,local-whisper,transcribe-anything,aws-transcribe"
URLS=()

log(){ printf '[cascade] %s\n' "$*" >&2; }
die(){ log "ERROR: $*"; rm -rf "$WORK" 2>/dev/null; exit 2; }
vid(){ printf '%s' "$1" | sed -E 's#.*[?&]v=([^&]+).*#\1#; s#.*/shorts/([^/?]+).*#\1#; s#.*/live/([^/?]+).*#\1#; s#.*youtu\.be/([^/?]+).*#\1#'; }

while [ $# -gt 0 ]; do case "$1" in
  --out) OUT="$2"; shift 2;;
  --ingest) INGEST=1; shift;;
  --ingest-db) INGEST_DB="$2"; INGEST=1; shift 2;;
  --model) MODEL="$2"; shift 2;;
  --engines) ENGINES="$2"; shift 2;;
  --chunk-secs) CHUNK="$2"; shift 2;;
  --lang) LANG="$2"; shift 2;;
  --local) LOCAL="$2"; shift 2;;
  --file) FILE="$2"; shift 2;;
  --frames) FRAMES=1; shift;;
  --scene) SCENE="$2"; shift 2;;
  --interval) INTERVAL="$2"; shift 2;;
  --max) FRAMESMAX="$2"; shift 2;;
  -h|--help) sed -n '2,41p' "$0"; exit 0;;
  *) URLS+=("$1"); shift;;
esac; done

mkdir -p "$WORK"
trap 'rm -rf "$WORK" 2>/dev/null' EXIT
has(){ printf '%s' ",$ENGINES," | grep -q ",$1,"; }

# --- ingest helper (optional user-provided SQLite knowledge DB) ---
# Writes to a `transcripts(video_id, title, transcript)` table. Enable with --ingest-db PATH.
# The table is created if the DB file exists but the table does not.
ingest_db(){ # id title transcript_file
  [ "$INGEST" = 1 ] || return 0
  [ -n "$INGEST_DB" ] || { log "ingest: no --ingest-db PATH given, skipping"; return 0; }
  command -v python3 >/dev/null 2>&1 || { log "ingest: python3 missing, skipping"; return 0; }
  local id="$1" title="$2" f="$3"
  python3 - "$INGEST_DB" "$id" "$title" "$f" <<'PY' 2>/dev/null || true
import sys, sqlite3, pathlib
db, vid, title, f = sys.argv[1:5]
t = pathlib.Path(f).read_text(errors="ignore")
c = sqlite3.connect(db)
c.execute("CREATE TABLE IF NOT EXISTS transcripts(video_id TEXT PRIMARY KEY, title TEXT, transcript TEXT)")
try:
    c.execute("INSERT INTO transcripts(video_id,title,transcript) VALUES(?,?,?)", (vid, title, t))
except Exception:
    c.execute("UPDATE transcripts SET transcript=?,title=? WHERE video_id=?", (t, title, vid))
c.commit(); c.close()
PY
  log "ingested $id into $INGEST_DB"
}

# --- ENGINE 1: optional `gemini` CLI transcription (skipped if absent) ---
engine_gemini(){ # src outfile
  command -v gemini >/dev/null 2>&1 || { log "gemini: CLI not installed, skipping"; return 1; }
  local src="$1" out="$2"
  log "gemini: attempting CLI transcription…"
  # Best-effort: ask the gemini CLI to transcribe the given URL/file to plain text.
  # CLIs vary; treat any non-empty stdout as success, else fall through to the next engine.
  gemini -p "Transcribe the audio at this source to plain text, verbatim, no commentary: $src" \
    > "$out" 2>>"$WORK/gemini.err" || return 1
  [ -s "$out" ] && { log "gemini: SUCCESS ($(wc -c <"$out") bytes)"; return 0; }
  return 1
}

# --- ENGINE 3: local chunked whisper (the sovereign floor) ---
engine_local_whisper(){ # url_or_id outfile
  local src="$1" out="$2" id; id="$(vid "$src")"; [ -n "$id" ] || id="local"
  command -v ffmpeg >/dev/null || { log "local-whisper: no ffmpeg"; return 1; }
  local WCLI=""; command -v whisper >/dev/null && WCLI="whisper"
  if [ -z "$WCLI" ] && command -v mlx_whisper >/dev/null; then WCLI="mlx_whisper"; fi
  [ -n "$WCLI" ] || { log "local-whisper: no whisper CLI (pip install openai-whisper or mlx-whisper)"; return 1; }
  local audio="$WORK/$id.m4a"
  # If the source is a local file, use it directly; otherwise fetch bestaudio with yt-dlp.
  if [ -f "$src" ]; then
    audio="$src"
  elif [ ! -s "$audio" ]; then
    command -v yt-dlp >/dev/null || { log "local-whisper: no yt-dlp for remote source"; return 1; }
    log "local-whisper: fetching audio (yt-dlp bestaudio)…"
    yt-dlp -q --no-warnings -f "bestaudio[ext=m4a]/bestaudio/best" -o "$audio" "$src" 2>>"$WORK/yt.err" \
      || yt-dlp -q --no-warnings --extractor-args "youtube:player_client=android,ios,web" \
           -f "bestaudio/best" -o "$audio" "$src" 2>>"$WORK/yt.err" \
      || { log "local-whisper: audio fetch failed ($(tail -1 "$WORK/yt.err" 2>/dev/null))"; return 1; }
  fi
  local dur; dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$audio" 2>/dev/null | cut -d. -f1); dur=${dur:-0}
  log "local-whisper: audio ${dur}s -> ${CHUNK}s chunks, whisper=$WCLI model=$MODEL"
  mkdir -p "$WORK/chunks"
  ffmpeg -v error -i "$audio" -f segment -segment_time "$CHUNK" -c copy "$WORK/chunks/c%04d.m4a" 2>>"$WORK/ff.err" \
    || ffmpeg -v error -i "$audio" -f segment -segment_time "$CHUNK" -ac 1 -ar 16000 "$WORK/chunks/c%04d.wav" 2>>"$WORK/ff.err"
  : > "$out"
  local n=0 ok=0
  for chunk in "$WORK/chunks/"c*; do
    [ -e "$chunk" ] || continue
    n=$((n+1))
    if [ "$WCLI" = "whisper" ]; then
      whisper "$chunk" --model "$MODEL" --language "$LANG" --output_format txt \
        --output_dir "$WORK/chunks" --fp16 False >/dev/null 2>>"$WORK/w.err" \
        && { cat "${chunk%.*}.txt" >> "$out" 2>/dev/null; printf '\n' >> "$out"; ok=$((ok+1)); } \
        || log "local-whisper: chunk $n failed"
    else
      mlx_whisper "$chunk" --model "mlx-community/whisper-${MODEL}" --language "$LANG" \
        --output-dir "$WORK/chunks" >/dev/null 2>>"$WORK/w.err" \
        && { cat "${chunk%.*}.txt" >> "$out" 2>/dev/null; printf '\n' >> "$out"; ok=$((ok+1)); }
    fi
    log "local-whisper: chunk $n done ($ok ok)"
  done
  [ -s "$out" ] && { log "local-whisper: SUCCESS ($ok/$n chunks, $(wc -c <"$out") bytes)"; return 0; }
  return 1
}

# --- ENGINE 4: transcribe-anything (auto-install on demand) ---
engine_transcribe_anything(){ # url outfile
  command -v transcribe-anything >/dev/null 2>&1 || {
    log "transcribe-anything: installing (pip)…"
    python3 -m pip install --quiet transcribe-anything >/dev/null 2>&1 || { log "install failed"; return 1; }
  }
  local d="$WORK/ta"; mkdir -p "$d"
  transcribe-anything "$1" --model "$MODEL" --output_dir "$d" >/dev/null 2>>"$WORK/ta.err" || return 1
  local f; f=$(find "$d" -name "*.txt" | head -1); [ -s "$f" ] && { cp "$f" "$2"; return 0; }
  return 1
}

# --- ENGINE 5: AWS Transcribe (cloud last resort) ---
engine_aws(){ # url outfile
  [ -n "${AWS_TRANSCRIBE_BUCKET:-}" ] || { log "aws-transcribe: set AWS_TRANSCRIBE_BUCKET to enable"; return 1; }
  command -v aws >/dev/null || { log "aws-transcribe: aws cli missing"; return 1; }
  log "aws-transcribe: not auto-run without confirmed bucket/cost; seam declared."
  return 1
}

# --- INLINE visual keyframe extraction (--frames; self-contained: ffmpeg + yt-dlp only) ---
# Runs AFTER a transcript succeeds. Never fails the transcript: every error path returns 0.
extract_frames(){ # src id transcript_file
  local src="$1" id="$2" tfile="$3" video=""
  command -v ffmpeg >/dev/null 2>&1 || { log "frames: no ffmpeg; keyframes skipped (transcript OK)"; return 0; }
  if [ -f "$src" ]; then
    video="$src"
  else
    command -v yt-dlp >/dev/null 2>&1 || { log "frames: no yt-dlp for remote source; keyframes skipped (transcript OK)"; return 0; }
    video="$WORK/${id}-video.mp4"
    if [ ! -s "$video" ]; then
      log "frames: fetching video (yt-dlp <=720p mp4)…"
      yt-dlp -q --no-warnings -f "bestvideo[height<=720][ext=mp4]/best[height<=720]/best" \
        -o "$video" "$src" 2>>"$WORK/frames-yt.err" \
        || { log "frames: video fetch failed ($(tail -1 "$WORK/frames-yt.err" 2>/dev/null)); keyframes skipped (transcript OK)"; return 0; }
    fi
  fi
  [ -s "$video" ] || { log "frames: no video available; keyframes skipped (transcript OK)"; return 0; }
  local outdir; outdir="$(dirname "$tfile")/${id}-frames"; mkdir -p "$outdir"
  log "frames: scene-detect (scene>$SCENE, max $FRAMESMAX) -> $outdir"
  ffmpeg -v error -i "$video" -vf "select='gt(scene,$SCENE)',showinfo" -vsync vfr \
    -frames:v "$FRAMESMAX" "$outdir/frame-%04d.jpg" 2>>"$WORK/frames-ff.err" || true
  local cnt; cnt=$(find "$outdir" -name 'frame-*.jpg' 2>/dev/null | wc -l | tr -d ' '); cnt=${cnt:-0}
  if [ "$cnt" -lt 2 ]; then
    log "frames: scene-detect yielded $cnt; falling back to interval (1 frame / ${INTERVAL}s)"
    rm -f "$outdir"/frame-*.jpg 2>/dev/null
    ffmpeg -v error -i "$video" -vf "fps=1/$INTERVAL" -frames:v "$FRAMESMAX" \
      "$outdir/frame-%04d.jpg" 2>>"$WORK/frames-ff.err" || true
    cnt=$(find "$outdir" -name 'frame-*.jpg' 2>/dev/null | wc -l | tr -d ' '); cnt=${cnt:-0}
  fi
  { # frames.md index (self-contained, relative image links)
    printf '# Keyframes — %s\n\n' "$id"
    printf -- '- Source: `%s`\n' "$src"
    printf -- '- Transcript: `%s`\n' "$tfile"
    printf -- '- Frames extracted: %s\n' "$cnt"
    printf -- '- Method: ffmpeg scene-change (scene>%s); interval fallback 1/%ss; max %s\n\n' "$SCENE" "$INTERVAL" "$FRAMESMAX"
    local fr
    for fr in "$outdir"/frame-*.jpg; do
      [ -e "$fr" ] || continue
      printf -- '- ![%s](%s)\n' "$(basename "$fr")" "$(basename "$fr")"
    done
  } > "$outdir/frames.md" 2>/dev/null || true
  log "frames: done ($cnt frame(s) -> $outdir)"
  return 0
}

# --- orchestrate ONE source through the cascade ---
run_one(){
  local src="$1" id title outfile
  CUR_SRC="$src"
  id="$(vid "$src")"; [ -n "$id" ] || id="item"
  outfile="${OUT:-$WORK/$id.txt}"
  title="video $id"

  if [ -n "$LOCAL" ]; then
    log "local file -> gemini, then local-whisper"
    engine_gemini "$LOCAL" "$outfile" && { finish "$id" "$title" "$outfile"; return 0; }
    engine_local_whisper "$LOCAL" "$outfile" && { finish "$id" "$title" "$outfile"; return 0; }
    log "all local-file engines failed"; return 1
  fi

  for e in $(printf '%s' "$ENGINES" | tr ',' ' '); do
    log "-> trying engine: $e"
    case "$e" in
      gemini)
        engine_gemini "$src" "$outfile" && [ -s "$outfile" ] \
          && { finish "$id" "$title" "$outfile"; return 0; } ;;
      ytdlp-subs)
        command -v yt-dlp >/dev/null || { log "ytdlp-subs: no yt-dlp"; continue; }
        yt-dlp -q --skip-download --write-auto-sub --write-sub --sub-lang "${LANG}.*" \
          --sub-format vtt --sleep-requests 2 -o "$WORK/%(id)s.%(ext)s" "$src" 2>>"$WORK/y.err"
        local vtt; vtt=$(find "$WORK" -name "$id*.vtt" | head -1)
        if [ -s "$vtt" ]; then
          sed -E '/-->/d; /^WEBVTT/d; /^[0-9]+$/d; /^$/d' "$vtt" | awk '!seen[$0]++' > "$outfile"
          [ -s "$outfile" ] && { finish "$id" "$title" "$outfile"; return 0; }
        fi ;;
      local-whisper)   engine_local_whisper "$src" "$outfile" && { finish "$id" "$title" "$outfile"; return 0; } ;;
      transcribe-anything) engine_transcribe_anything "$src" "$outfile" && { finish "$id" "$title" "$outfile"; return 0; } ;;
      aws-transcribe)  engine_aws "$src" "$outfile" && { finish "$id" "$title" "$outfile"; return 0; } ;;
      *) log "unknown engine '$e' — skipping" ;;
    esac
  done
  log "DIAGNOSIS: all requested engines failed for $id. Check $WORK/*.err. The local-whisper floor needs ffmpeg+whisper+enough disk for the audio."
  return 1
}

finish(){ # id title outfile
  local id="$1" title="$2" f="$3"
  log "SUCCESS: $id -> $f ($(wc -c <"$f" 2>/dev/null) bytes)"
  ingest_db "$id" "$title" "$f"
  [ "$FRAMES" = 1 ] && extract_frames "$CUR_SRC" "$id" "$f"
  printf '%s\t%s\n' "$id" "$f"
}

# --- main ---
rc=0
if [ -n "$FILE" ]; then
  while IFS= read -r line; do line="${line%%#*}"; line="$(printf '%s' "$line" | xargs)"; [ -n "$line" ] && URLS+=("$line"); done < "$FILE"
fi
if [ -n "$LOCAL" ]; then run_one "$LOCAL" || rc=3
else
  [ ${#URLS[@]} -gt 0 ] || die "no url/id given (see --help)"
  for u in "${URLS[@]}"; do run_one "$u" || rc=3; done
fi
exit $rc
