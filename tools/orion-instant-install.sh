#!/usr/bin/env bash
# orion-instant-install.sh — wire the ORION instant-capability bundle into a host.
#
# WHAT IT DOES (and ONLY this):
#   1. Prints the plan before doing anything.
#   2. Checks for ffmpeg / yt-dlp / whisper|mlx_whisper / gh — REPORTS what's missing, installs NOTHING.
#   3. Points at the reference tools already in tools/ (orion-transcribe.sh, orion-skill-search.sh),
#      chmod +x-ing them if needed, and (best-effort) symlinks them into ~/.local/bin if that's on PATH.
#   4. Prints the one line to load ORION_INSTANT_CAPABILITY.md into a host's system prompt.
#   5. Prints the path to the machine-readable manifest (orion-capability-manifest.json).
#
# It is idempotent, uses NO sudo, and performs NO destructive operations. Nothing is auto-executed;
# nothing is auto-installed. Missing dependencies are reported with the command you'd run yourself.
#
# Usage: tools/orion-instant-install.sh [--bindir DIR] [--no-link]
set -uo pipefail

# Resolve this script's directory (the tools/ dir) and the repo root, robustly.
SELF="${BASH_SOURCE[0]}"
TOOLS_DIR="$(cd "$(dirname "$SELF")" && pwd)"
ROOT_DIR="$(cd "$TOOLS_DIR/.." && pwd)"

BINDIR="${HOME:-/tmp}/.local/bin"
DO_LINK=1

while [ $# -gt 0 ]; do case "$1" in
  --bindir) BINDIR="$2"; shift 2;;
  --no-link) DO_LINK=0; shift;;
  -h|--help) sed -n '2,18p' "$SELF"; exit 0;;
  *) echo "unknown arg: $1 (see --help)" >&2; exit 2;;
esac; done

say(){ printf '%s\n' "$*"; }
hr(){ printf -- '----------------------------------------------------------------------\n'; }

CAP_DOC="$ROOT_DIR/ORION_INSTANT_CAPABILITY.md"
MANIFEST="$TOOLS_DIR/orion-capability-manifest.json"
TRANSCRIBE="$TOOLS_DIR/orion-transcribe.sh"
SKILLSEARCH="$TOOLS_DIR/orion-skill-search.sh"

hr
say "ORION instant-capability installer"
say "Repo root : $ROOT_DIR"
say "Tools dir : $TOOLS_DIR"
hr
say "PLAN (nothing runs until you read this):"
say "  1. Check host tools (ffmpeg/yt-dlp/whisper/gh) — report only, install nothing."
say "  2. Make the reference tools executable and (optionally) link them onto PATH."
say "  3. Print the one line to load the operating mode into a host system prompt."
say "  4. Print the manifest path."
hr

# ---------- 1. dependency check (report-only; installs NOTHING) ----------
say "[1/4] Host tool check (report-only):"
check(){ # label cmd install-hint
  local label="$1" cmd="$2" hint="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '  [ok]      %-14s -> %s\n' "$label" "$(command -v "$cmd")"
  else
    printf '  [missing] %-14s   install: %s\n' "$label" "$hint"
  fi
}
check "ffmpeg"  ffmpeg  "https://ffmpeg.org/download.html (or: brew install ffmpeg / apt install ffmpeg)"
check "ffprobe" ffprobe "ships with ffmpeg"
check "yt-dlp"  yt-dlp  "pipx install yt-dlp  (or: pip install -U yt-dlp)"
if command -v whisper >/dev/null 2>&1; then
  printf '  [ok]      %-14s -> %s\n' "whisper" "$(command -v whisper)"
elif command -v mlx_whisper >/dev/null 2>&1; then
  printf '  [ok]      %-14s -> %s\n' "mlx_whisper" "$(command -v mlx_whisper)"
else
  printf '  [missing] %-14s   install: %s\n' "whisper" "pip install openai-whisper  (Apple Silicon: pip install mlx-whisper)"
fi
check "gh"      gh      "https://cli.github.com  (or: brew install gh / apt install gh)"
say "  (Missing tools only disable the seams that need them; the discipline layer still runs.)"
hr

# ---------- 2. point at the reference tools ----------
say "[2/4] Reference tools in $TOOLS_DIR:"
point_at(){ # path
  local p="$1"
  if [ -f "$p" ]; then
    [ -x "$p" ] || chmod +x "$p" 2>/dev/null || true
    printf '  [ready]   %s\n' "$p"
  else
    printf '  [absent]  %s (expected in tools/)\n' "$p"
  fi
}
point_at "$TRANSCRIBE"
point_at "$SKILLSEARCH"

if [ "$DO_LINK" = 1 ]; then
  case ":${PATH}:" in
    *":$BINDIR:"*)
      mkdir -p "$BINDIR" 2>/dev/null || true
      for t in "$TRANSCRIBE" "$SKILLSEARCH"; do
        [ -f "$t" ] || continue
        ln -sf "$t" "$BINDIR/$(basename "$t")" 2>/dev/null \
          && printf '  [link]    %s -> %s\n' "$BINDIR/$(basename "$t")" "$t" \
          || printf '  [note]    could not link %s (non-fatal)\n' "$(basename "$t")"
      done ;;
    *)
      printf '  [note]    %s is not on PATH — skipping symlinks. Call the tools by path,\n' "$BINDIR"
      printf '            or add %s to PATH and re-run.\n' "$BINDIR" ;;
  esac
else
  say "  [note]    --no-link given; not touching PATH."
fi
hr

# ---------- 3. load the operating mode ----------
say "[3/4] Load the operating mode into your host:"
if [ -f "$CAP_DOC" ]; then
  say "  Paste the contents of this file into the host system-prompt / persistent-instructions slot:"
  say "    $CAP_DOC"
  say "  Shell one-liners to copy it out:"
  say "    cat \"$CAP_DOC\"                 # then paste into the host's persistent instructions"
  if command -v pbcopy >/dev/null 2>&1; then
    say "    pbcopy < \"$CAP_DOC\"           # macOS: copies it to your clipboard"
  elif command -v xclip >/dev/null 2>&1; then
    say "    xclip -sel clip < \"$CAP_DOC\"  # Linux/X11: copies it to your clipboard"
  fi
  say "  That turns the discipline gates + orchestration loop on for EVERY message."
else
  say "  [absent]  $CAP_DOC not found — expected at repo root."
fi
hr

# ---------- 4. manifest path ----------
say "[4/4] Machine-readable capability manifest:"
if [ -f "$MANIFEST" ]; then
  say "  $MANIFEST"
  say "  Point a broker/orchestrator at it to enumerate the capability seams."
else
  say "  [absent]  $MANIFEST not found — expected in tools/."
fi
hr
say "Done. No files were deleted, no packages installed, no sudo used. Re-run anytime (idempotent)."
exit 0
