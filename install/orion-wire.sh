#!/usr/bin/env bash
set -euo pipefail
# orion-wire.sh — auto-load ORION into your local coding agents, every session, token-efficiently.
#
# ORION = Open Reasoning & Intelligent Orchestration Network.
#
# What it does: installs a compact ORION CORE (Tier 1: persona + gates + manifest) that your agents
# pick up ONCE per session (not per message), and auto-loads the deep boot (Tier 2: research forcing +
# commands) at session start. Tier 3 (deployment fills, skills) stays situational. Idempotent
# (marker-based) and self-refreshing.
#
# Wires (only the ones present on your machine):
#   • Claude Code — a SessionStart hook in ~/.claude/settings.json
#   • Codex       — a managed block in ~/.codex/AGENTS.md (read every session)
#   • Any AGENTS.md-aware agent — a managed block in ~/.config/agents/AGENTS.md
#
# Usage:
#   ./install/orion-wire.sh            # wire everything present
#   ./install/orion-wire.sh --status   # show what's wired
#   ./install/orion-wire.sh --unwire   # remove ORION blocks/hook

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_SRC="$REPO/boot/ORION_CORE.md"
DEEP_SRC="$REPO/boot/ORION_BOOT.md"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/orion"
HOOK="$STATE/orion-inject.sh"
BLOCK="$STATE/orion-core.md"
SETTINGS="$HOME/.claude/settings.json"
S='<!-- ORION-CORE:start (managed by orion-wire.sh — re-run to update) -->'
E='<!-- ORION-CORE:end -->'

[ -f "$CORE_SRC" ] || { echo "run this from the orion-os repo (missing boot/ORION_CORE.md)"; exit 1; }

if [ "${1:-}" = "--status" ]; then
  echo "core block: $([ -f "$BLOCK" ] && echo present || echo missing)"
  echo "claude hook: $(grep -q orion-inject "$SETTINGS" 2>/dev/null && echo wired || echo no)"
  echo "codex AGENTS.md: $(grep -q ORION-CORE "$HOME/.codex/AGENTS.md" 2>/dev/null && echo wired || echo no)"
  echo "agents AGENTS.md: $(grep -q ORION-CORE "$HOME/.config/agents/AGENTS.md" 2>/dev/null && echo wired || echo no)"
  exit 0
fi

remove_block() { # $1 file
  [ -f "$1" ] || return 0
  python3 - "$1" "$S" "$E" <<'PY'
import sys, re
f,S,E=sys.argv[1:]
t=open(f).read(); n=re.sub(re.escape(S)+r".*?"+re.escape(E)+r"\n?","",t,flags=re.S)
open(f,"w").write(n)
PY
}
if [ "${1:-}" = "--unwire" ]; then
  remove_block "$HOME/.codex/AGENTS.md"; remove_block "$HOME/.config/agents/AGENTS.md"
  [ -f "$SETTINGS" ] && python3 - "$SETTINGS" "$HOOK" <<'PY'
import json,sys
s,h=sys.argv[1:]
try:d=json.load(open(s))
except Exception:raise SystemExit
st=d.get("hooks",{}).get("SessionStart",[])
d["hooks"]["SessionStart"]=[g for g in st if h not in json.dumps(g)]
json.dump(d,open(s,"w"),indent=2)
PY
  echo "unwired ORION."; exit 0
fi

mkdir -p "$STATE"

# 1. canonical ORION CORE block (Tier 1), pointing at THIS repo's boot files.
cat > "$BLOCK" <<CORE_EOF
$S
## ORION CORE — adopt at session start
You are **ORION** 🛰️ (Open Reasoning & Intelligent Orchestration Network) — a sharp, adaptive AI
operating companion. Learn and mirror the user's style over time; challenge weak ideas; answer facts
directly. Culture-neutral; adapt to any user or workflow.

**Discipline gates (apply to EVERY task, not optional):**
- RESEARCH-BEFORE-CONCLUDING: for current/external/unfamiliar facts, consult sources first; scale
  effort to difficulty (1 lookup for a fact, the six lanes — GitHub/Reddit/X/YouTube/Google/StackOverflow
  — for anything open-ended). A one-shot answer to an open-ended question is non-compliance.
- NEVER-QUIT: "can't / not possible" is banned until ≥2 real attempts + a tool search; only a genuine
  human gate (password/2FA/CAPTCHA/payment/account-creation/destructive) stops you — name the exact one.
- OMISSION-OVER-FABRICATION: drop unsure claims instead of inventing; label VERIFIED vs GUESS.

**Tiers:** Tier 2 (full pattern: research forcing + commands) auto-loads at session start from
\`$DEEP_SRC\` — read it. Tier 3 (deployment fills, skills) is situational; load only when the task needs it.
Commands: /start /menu /research <q> /memory /snapshot /recall <t> /handoff /status
$E
CORE_EOF

# 2. SessionStart hook payload: Tier 1 core + Tier 2 (deep boot §4→end, no persona/gate dup).
cat > "$HOOK" <<HOOK_EOF
#!/usr/bin/env bash
CORE="$BLOCK"; DEEP="$DEEP_SRC"
[ -f "\$CORE" ] && cat "\$CORE"
[ -f "\$DEEP" ] && { echo; echo "<!-- ORION Tier-2 (auto) -->"; awk '/^## 4 · /{p=1} p' "\$DEEP"; }
exit 0
HOOK_EOF
chmod +x "$HOOK"

ensure_block() { # $1 target AGENTS.md (only if its dir exists)
  [ -d "$(dirname "$1")" ] || return 0
  python3 - "$1" "$BLOCK" "$S" "$E" <<'PY'
import sys,re
f,core,S,E=sys.argv[1:]
block=open(core).read().strip()
try:t=open(f).read()
except FileNotFoundError:t=""
pat=re.compile(re.escape(S)+r".*?"+re.escape(E),re.S)
if pat.search(t): new=pat.sub(block,t); tag="updated"
else:
    sep="" if (not t or t.endswith("\n")) else "\n"
    new=t+sep+"\n"+block+"\n"; tag="wired"
if new!=t: open(f,"w").write(new); print(f"  {f}: {tag}")
else: print(f"  {f}: already current")
PY
}

echo "Wiring ORION (Tier 1 + auto Tier 2, once/session):"
# Claude Code (only if installed)
if [ -f "$SETTINGS" ] || [ -d "$HOME/.claude" ]; then
  python3 - "$SETTINGS" "$HOOK" <<'PY'
import json,os,sys
s,h=sys.argv[1:]
try:d=json.load(open(s)) if os.path.exists(s) else {}
except Exception:print("  claude: settings.json not valid JSON — skipped");raise SystemExit
st=d.setdefault("hooks",{}).setdefault("SessionStart",[])
if h not in json.dumps(st):
    st.append({"hooks":[{"type":"command","command":f"bash {h}","timeout":5}]})
    os.makedirs(os.path.dirname(s),exist_ok=True); json.dump(d,open(s,"w"),indent=2); print("  claude: wired SessionStart hook")
else:print("  claude: already wired")
PY
fi
ensure_block "$HOME/.codex/AGENTS.md"
ensure_block "$HOME/.config/agents/AGENTS.md"
echo "Done. ORION loads on next session start. Status: ./install/orion-wire.sh --status"
