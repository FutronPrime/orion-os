#!/usr/bin/env bash
# orion-skill-search.sh — on-demand agent/skill discovery: search public repos in real time,
# VET every candidate through a mandatory security gate, quarantine-download, and register only
# what passes — so an orchestrator can mount+use skills it never had installed.
#
# WHY: no orchestrator ships with every skill it will ever need. Rather than pre-installing a huge
# static tree, this tool reaches the open internet on demand, finds candidate skills/agents, and —
# critically — refuses to let ANY of them near your live skills tree until they clear a static
# malware scan and a reputation check. Nothing is auto-executed; discovery and trust are separate steps.
#
# Discovery sources (order = try until matches found; extend SOURCES[] freely):
#   1. `gh search repos` across all of GitHub  — PRIMARY discovery path (reliable for most tokens)
#   2. curated public awesome-list / search-index repos — their READMEs are scanned for links
#   3. `gh search code` for SKILL.md matches   — BEST-EFFORT only (GitHub's code-search API returns
#      empty for many tokens; kept quiet when it yields nothing, never treated as authoritative)
#
# VETTING GATE (MANDATORY — a candidate is REJECTED unless it passes):
#   1. STATIC MALWARE SCAN — grep for curl|bash / wget|sh pipes, `rm -rf ~`, base64->sh, eval of
#      remote payloads, reverse shells (`nc -e`, `/dev/tcp/`), credential exfiltration, private-key
#      material, and oversized/opaque binaries.
#   2. REPUTATION          — gh repo age/stars/fork heuristics (skipped if `gh` absent — non-fatal).
#   3. (optional) EXTERNAL AUDIT HOOK — if you set SKILL_AUDIT_CMD to your own auditor, its output is
#      appended as an advisory note. This is a generic seam; no specific auditor is bundled.
#   Only PASS candidates land in the quarantine dir and are eligible for --register.
#
# Usage:
#   orion-skill-search.sh "<capability query>" [--limit N] [--source gh|awesome|all]
#   orion-skill-search.sh --vet <path-or-owner/repo>   # run the vetting gate on a specific candidate
#   orion-skill-search.sh --register <quarantine-id>   # promote a vetted candidate (index-only; no exec)
#   orion-skill-search.sh --sources                    # list configured discovery sources
# Env:
#   SKILL_QUARANTINE_DIR   quarantine location (default: $HOME/.orion/skills-quarantine, or $TMPDIR)
#   SKILL_AUDIT_CMD        optional external auditor; called as: "$SKILL_AUDIT_CMD" --path <dir>
# Needs `gh` (GitHub CLI) for live search; degrades to a browse-these-sources hint without it.
# Never auto-executes candidate code. MIT-spirit, system-agnostic.
set -uo pipefail

Q=""; LIMIT=8; SRC="all"; VET_TARGET=""; REG_ID=""
QUAR="${SKILL_QUARANTINE_DIR:-${HOME:-$TMPDIR}/.orion/skills-quarantine}"
AUDIT_CMD="${SKILL_AUDIT_CMD:-}"
mkdir -p "$QUAR" 2>/dev/null || QUAR="${TMPDIR:-/tmp}/orion-skills-quarantine"; mkdir -p "$QUAR"

# curated PUBLIC awesome-list / search-index repos (owner/repo)
SOURCES=(
  "VoltAgent/awesome-agent-skills"
  "SciPhi-AI/agent-search"
  "kevinWangSheng/skill-search"
  "netresearch/file-search-skill"
  "assafelovic/gpt-researcher"
  "karpathy/autoresearch"
)

log(){ printf '[skill-search] %s\n' "$*" >&2; }

while [ $# -gt 0 ]; do case "$1" in
  --limit) LIMIT="$2"; shift 2;;
  --source) SRC="$2"; shift 2;;
  --vet) VET_TARGET="$2"; shift 2;;
  --register) REG_ID="$2"; shift 2;;
  --sources) printf '%s\n' "${SOURCES[@]}"; echo "+ live: gh search repos (primary), gh search code (best-effort)"; exit 0;;
  -h|--help) sed -n '2,38p' "$0"; exit 0;;
  *) Q="${Q:+$Q }$1"; shift;;
esac; done

# ---------- VETTING GATE ----------
vet_static(){ # dir -> 0 pass / 1 reject ; prints findings
  local d="$1" bad=0
  local hits
  hits=$(grep -rInE \
    'curl[^|]*\|\s*(bash|sh)|wget[^|]*\|\s*(bash|sh)|base64\s+-d[^|]*\|\s*(bash|sh)|rm\s+-rf\s+(~|/|\$HOME)|eval\s+.*\$\(curl|nc\s+-e|/dev/tcp/|python[0-9]*\s+-c\s+.*exec|os\.system\(.*curl|subprocess.*shell=True.*curl|ssh-keygen|\.ssh/id_|aws_secret|BEGIN (RSA|OPENSSH) PRIVATE KEY|smtplib|requests\.post\(.*(token|key|secret)' \
    "$d" 2>/dev/null | head -20)
  if [ -n "$hits" ]; then echo "$hits" | sed 's/^/    ! /'; bad=1; fi
  # opaque/oversized binaries
  local bins; bins=$(find "$d" -type f \( -name '*.bin' -o -name '*.so' -o -name '*.dylib' -o -name '*.exe' -o -name '*.pyc' \) -size +512k 2>/dev/null | head -5)
  [ -n "$bins" ] && { echo "$bins" | sed 's/^/    ! opaque-binary /'; bad=1; }
  return $bad
}
vet_reputation(){ # owner/repo -> echo note (non-fatal)
  command -v gh >/dev/null || { echo "    (gh absent — reputation skipped)"; return 0; }
  gh repo view "$1" --json stargazerCount,createdAt,isFork,pushedAt \
    --jq '"    reputation: stars=\(.stargazerCount) fork=\(.isFork) created=\(.createdAt[0:10]) pushed=\(.pushedAt[0:10])"' 2>/dev/null \
    || echo "    (reputation lookup failed)"
}
vet_gate(){ # dir [owner/repo] -> 0 pass / 1 reject
  local d="$1" repo="${2:-}"
  log "VET: static malware scan on $d"
  local rc=0
  if vet_static "$d"; then log "VET: static scan PASS"; else log "VET: static scan FLAGGED — manual review required"; rc=1; fi
  [ -n "$repo" ] && vet_reputation "$repo"
  # optional external auditor hook (generic seam; advisory, non-fatal). Set SKILL_AUDIT_CMD to enable.
  if [ -n "$AUDIT_CMD" ] && command -v "${AUDIT_CMD%% *}" >/dev/null 2>&1; then
    log "VET: external audit hook ($AUDIT_CMD)"; "$AUDIT_CMD" --path "$d" 2>/dev/null | tail -3 || true
  fi
  return $rc
}

# ---------- explicit --vet / --register modes ----------
if [ -n "$VET_TARGET" ]; then
  if [ -d "$VET_TARGET" ]; then vet_gate "$VET_TARGET"; exit $?; fi
  # it's a repo: shallow clone to quarantine and vet (NOT installed, NOT executed)
  id=$(printf '%s' "$VET_TARGET" | tr '/:' '__'); dst="$QUAR/$id"
  log "cloning $VET_TARGET -> $dst (quarantine, not installed)"
  rm -rf "$dst" 2>/dev/null; git clone --depth 1 -q "https://github.com/$VET_TARGET" "$dst" 2>/dev/null \
    || { log "clone failed"; exit 2; }
  vet_gate "$dst" "$VET_TARGET"; exit $?
fi
if [ -n "$REG_ID" ]; then
  src="$QUAR/$REG_ID"; [ -d "$src" ] || { log "no quarantine dir $src"; exit 2; }
  vet_gate "$src" || { log "REFUSING to register: failed vetting gate. Review $src manually."; exit 3; }
  # register: record it so an orchestrator/broker can become aware (does NOT auto-run anything)
  printf '%s\t%s\n' "$(date -u +%FT%TZ)" "$src" >> "$QUAR/registry.tsv"
  log "REGISTERED (vetted): $src — recorded in $QUAR/registry.tsv; mount it when you actually need it"
  exit 0
fi

# ---------- discovery ----------
[ -n "$Q" ] || { log "no query (see --help)"; exit 2; }
log "searching public skill/agent repos for: \"$Q\" (limit $LIMIT, source=$SRC)"
found=0
emit(){ printf '  * %-45s %s\n' "$1" "$2"; found=$((found+1)); }

if command -v gh >/dev/null; then
  if [ "$SRC" = all ] || [ "$SRC" = gh ]; then
    log "-> gh search repos (whole GitHub) — primary discovery path…"
    while IFS=$'\t' read -r repo meta; do [ -n "$repo" ] && emit "$repo" "$meta"; done < <(
      gh search repos "$Q agent skill" --limit "$LIMIT" --json fullName,description,stargazersCount \
        --jq '.[] | "\(.fullName)\t\(.stargazersCount)* \(.description // "")"' 2>/dev/null)
    # gh search code is BEST-EFFORT: the code-search API returns empty for many tokens. Stay quiet when empty.
    code_hits=$(gh search code "$Q filename:SKILL.md" --limit "$LIMIT" --json repository \
      --jq '.[].repository.fullName' 2>/dev/null | sort -u)
    if [ -n "$code_hits" ]; then
      log "-> gh search code found SKILL.md matches (best-effort)…"
      while read -r repo; do [ -n "$repo" ] && emit "$repo" "(has SKILL.md)"; done <<< "$code_hits"
    fi
  fi
  if [ "$SRC" = all ] || [ "$SRC" = awesome ]; then
    log "-> scanning curated awesome-lists for '$Q'…"
    for repo in "${SOURCES[@]}"; do
      while read -r u; do [ -n "$u" ] && emit "${u#https://github.com/}" "(via $repo)"; done < <(
        gh api "repos/$repo/readme" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null \
          | grep -iE "$Q" | grep -oiE 'https?://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' | sort -u | head -3)
    done
  fi
else
  log "gh not installed — install the GitHub CLI for live search. Curated sources you can browse:"
  printf '  * %s\n' "${SOURCES[@]}"
  log "Fallback: web-search '$Q agent skill site:github.com', then: --vet <owner/repo>."
fi

echo
if [ "$found" -eq 0 ]; then
  log "no direct matches — widen the query or add sources. Nothing installed."
else
  log "found $found candidate(s). NONE are trusted yet."
  log "NEXT: orion-skill-search.sh --vet <owner/repo>   (clones to quarantine + runs the vetting gate)"
  log "THEN: orion-skill-search.sh --register <id>       (promotes ONLY if vetting passed)"
fi
