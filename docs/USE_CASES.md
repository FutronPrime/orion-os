# ORION use cases

**ORION — Open Reasoning & Intelligent Orchestration Network.** A discipline layer you drop on top
of any LLM so it researches before it answers, refuses to give up, and never fabricates. Built-in
research + discipline functions, no vendor lock, frontier-grade behavior on any model.

## Core behaviors (from `boot/ORION_BOOT.md`)

| # | Gate | What it forces |
|---|------|----------------|
| 1 | Research-before-concluding | Consults sources *before* deciding it "already knows"; scales effort to difficulty (1 lookup for a fact, six lanes for open-ended). |
| 2 | Never-quit | "I can't / not possible" is banned until ≥2 concrete attempts + a tool search; only a named human gate stops it. |
| 3 | Omission-over-fabrication | Drops unsure claims instead of inventing; labels VERIFIED vs GUESS. |
| 4 | Silent competence | Produces the result, doesn't narrate the process. |
| 5 | Self-check | Runs a pass/fail questionnaire on its own draft before sending. |

## Example deployments

- **Research assistant** — "compare X and Y for my use case": ORION hits GitHub/Reddit/X/YouTube/Google/SO,
  cross-checks, and returns a cited answer instead of a confident guess.
- **Support/ops copilot** — fill §4 with your services and §5 with your docs; ORION searches your
  knowledge base before answering, and won't make up an API that doesn't exist.
- **Coding helper** — forces it to check current docs/repos for the library version you're on rather
  than hallucinating a stale API.
- **Personal assistant that grows with you** — the adaptive persona learns your tone, domain, and
  pacing over the conversation and mirrors it (`/personality_status` reports the adaptation).

## Token-efficient deployment (recommended)

Don't paste the big boot doc every message. Use two tiers:
1. **Always-on core** (`ORION_CORE`, ~650 tokens) → your platform's persistent system-prompt slot
   (Custom GPT instructions, Claude Project instructions, a Gemini Gem, or an API system prompt).
   With prompt caching this is ~free on repeat turns.
2. **Deep boot** (`ORION_BOOT.md`) → paste once into the knowledge/first-message when you want full
   context; it's prompt-cached after the first turn.
3. **Everything else** → demand-loaded only when a command needs it.

See [`../boot/ORION_BOOT.md`](../boot/ORION_BOOT.md) to start.
