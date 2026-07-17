#!/usr/bin/env bash
set -euo pipefail
# build-bundle.sh — assemble the whole ORION suite into ONE upload-ready file:
#   boot/ORION_COMPLETE.md  =  boot + manual + guide + use-cases + all skills
# Drag that single file into any file-upload chat (Venice, agentic chats, etc.) to load everything.
# Regenerable — re-run after editing any source doc so the bundle never goes stale.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO/boot/ORION_COMPLETE.md"

section() { printf '\n\n---\n\n# ══ %s ══\n\n' "$1"; }

{
  cat <<'HDR'
# ORION OS — COMPLETE (single-file bundle)
> **Open Reasoning & Intelligent Orchestration Network.** One file = the entire system: boot pattern +
> manual + how-to guide + use cases + skills. Paste/upload this whole file into any LLM and send `/start`.
> (For the token-lean always-on slot, use `ORION_CORE.md` instead; this bundle is the full reference.)
HDR
  section "BOOT (persona · gates · research forcing · commands)"; cat "$REPO/boot/ORION_BOOT.md"
  section "OPERATIONS MANUAL";                                     cat "$REPO/docs/MANUAL.md"
  section "HOW-TO GUIDE";                                          cat "$REPO/docs/GUIDE.md"
  section "USE CASES";                                             cat "$REPO/docs/USE_CASES.md"
  section "SKILLS"
  for s in "$REPO"/skills/*.md; do printf '\n## skill: %s\n\n' "$(basename "$s" .md)"; cat "$s"; done
} > "$OUT"

echo "[build-bundle] wrote $OUT ($(wc -l < "$OUT" | tr -d ' ') lines, ~$(( $(wc -c < "$OUT") / 4 )) tok)"
