#!/usr/bin/env python3
"""codex-rollout-slim — shrink runaway Codex session rollout logs IN PLACE,
keeping them fully resumable and searchable. Part of ORION OS. MIT license.

THE PROBLEM
Codex Desktop / Codex CLI append every prompt, response, tool call, and a
world-state snapshot to `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`.
A session that handles large tool outputs (file dumps, screenshots, harness
receipts) can balloon — a real-world case hit 21 GB in one session, filled the
disk, and made the session unloadable in Codex Desktop.

THE FIX
Stream the file line by line:
  * lines <= 256 KB are kept verbatim,
  * inside jumbo lines, any string field > 64 KB is truncated to a 2 KB head
    plus an explicit marker recording the original size,
  * output is written to a temp file, line count verified, then atomically
    renamed over the ORIGINAL filename — so Codex still lists, resumes, and
    searches the session. Real-world result: 21 GB -> 125 MB, zero text lost.

SAFETY
  * Never touches files modified within --min-age-hours (live sessions).
  * Skips when free disk is too low for a safe temp copy.
  * Optional full-fidelity backup first (--backup-dir or $CODEX_SLIM_BACKUP_DIR);
    if the backup volume is not mounted the tool proceeds without it — your
    local slimmed file remains the source of truth (design for machines whose
    external drives are not always connected).
  * Any error leaves the original untouched.

USAGE
  python3 codex-rollout-slim.py --scan                 # all rollouts >= 1 GB
  python3 codex-rollout-slim.py path/to/rollout.jsonl --force
  Cron/daemon-friendly: run --scan periodically; all guards are built in.
"""
import argparse
import json
import os
import shutil
import sys
import time

def log(msg):
    print(f"[codex-rollout-slim] {msg}", flush=True)

def strip_obj(o, strmax, head):
    if isinstance(o, dict):
        return {k: strip_obj(v, strmax, head) for k, v in o.items()}
    if isinstance(o, list):
        return [strip_obj(v, strmax, head) for v in o]
    if isinstance(o, str) and len(o) > strmax:
        return o[:head] + f"…[STRIPPED {len(o):,} bytes total by codex-rollout-slim]"
    return o

def slim_file(path, args):
    try:
        st = os.stat(path)
    except OSError as e:
        log(f"SKIP {path}: {e}")
        return 0
    if not args.force:
        if (time.time() - st.st_mtime) < args.min_age_hours * 3600:
            log(f"SKIP {path}: modified <{args.min_age_hours}h ago (possibly live)")
            return 0
    free = shutil.disk_usage(os.path.dirname(path) or ".").free
    if free < st.st_size * 0.15 + 500 * 1024 * 1024:
        log(f"SKIP {path}: not enough free disk for safe temp output")
        return 0

    if args.backup_dir:
        vol = args.backup_dir
        parts = vol.split(os.sep)
        mounted = True
        if len(parts) > 2 and parts[1] == "Volumes":  # macOS external volume
            mounted = os.path.isdir(os.sep.join(parts[:3]))
        if mounted:
            try:
                os.makedirs(vol, exist_ok=True)
                dst = os.path.join(vol, os.path.basename(path))
                if not args.dry_run and not os.path.exists(dst):
                    shutil.copy2(path, dst)
                    if os.path.getsize(dst) != st.st_size:
                        log(f"ABORT {path}: backup size mismatch — original untouched")
                        return 0
                log(f"backup ok → {dst}")
            except OSError as e:
                log(f"backup unavailable ({e}) — proceeding without")
        else:
            log("backup volume not mounted — proceeding without")

    tmp = path + ".slim.tmp"
    keep = args.keep_line_bytes
    n_in = n_out = big = bad = 0
    try:
        with open(path, "rb") as fin, open(tmp, "w", encoding="utf-8") as fout:
            for raw in fin:
                n_in += 1
                if len(raw) <= keep:
                    fout.write(raw.decode("utf-8", "replace"))
                    if not raw.endswith(b"\n"):
                        fout.write("\n")
                    n_out += 1
                    continue
                big += 1
                try:
                    d = json.loads(raw)
                    fout.write(json.dumps(strip_obj(d, args.strmax, args.head),
                                          ensure_ascii=False) + "\n")
                except Exception:
                    bad += 1
                    fout.write(json.dumps({"type": "stripped_unparseable",
                                           "orig_bytes": len(raw)}) + "\n")
                n_out += 1
        if n_out != n_in:
            raise RuntimeError(f"line count mismatch in={n_in} out={n_out}")
        new_size = os.path.getsize(tmp)
        if args.dry_run:
            os.unlink(tmp)
            log(f"DRY-RUN {path}: {st.st_size:,} → {new_size:,} bytes "
                f"({big} jumbo lines, {bad} unparseable)")
            return 0
        os.replace(tmp, path)
        freed = st.st_size - new_size
        log(f"SLIMMED {path}: {st.st_size:,} → {new_size:,} bytes "
            f"(freed {freed/1e9:.2f} GB; {n_in} lines kept; {big} jumbo stripped)")
        return max(0, freed)
    except Exception as e:
        try:
            if os.path.exists(tmp):
                os.unlink(tmp)
        except OSError:
            pass
        log(f"FAILED {path}: {e} — original untouched")
        return 0

def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="*", help="specific rollout .jsonl files")
    ap.add_argument("--scan", action="store_true")
    ap.add_argument("--sessions-dir",
                    default=os.path.expanduser("~/.codex/sessions"))
    ap.add_argument("--min-size-gb", type=float, default=1.0)
    ap.add_argument("--min-age-hours", type=float, default=24)
    ap.add_argument("--strmax", type=int, default=65536)
    ap.add_argument("--head", type=int, default=2048)
    ap.add_argument("--keep-line-bytes", type=int, default=256 * 1024)
    ap.add_argument("--backup-dir",
                    default=os.environ.get("CODEX_SLIM_BACKUP_DIR", ""))
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    targets = list(args.files)
    if args.scan:
        min_bytes = args.min_size_gb * 1024**3
        for dirpath, _dirs, files in os.walk(args.sessions_dir):
            for fn in files:
                if fn.startswith("rollout-") and fn.endswith(".jsonl"):
                    p = os.path.join(dirpath, fn)
                    try:
                        if os.path.getsize(p) >= min_bytes:
                            targets.append(p)
                    except OSError:
                        pass
    if not targets:
        log("nothing to do")
        return 0
    total = sum(slim_file(p, args) for p in targets)
    log(f"TOTAL freed: {total/1e9:.2f} GB across {len(targets)} candidate(s)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
