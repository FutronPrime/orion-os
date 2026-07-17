# ORION OS — Operations Manual

**ORION — Open Reasoning & Intelligent Orchestration Network.** A hardened, model-agnostic operating
pattern you paste into any LLM so it researches before it answers, refuses to give up, and never
fabricates.

## Table of contents
1. [Purpose](#1-purpose)
2. [Goals](#2-goals)
3. [What ORION does — functions](#3-what-orion-does--functions)
4. [Architecture — the tiers](#4-architecture--the-tiers)
5. [The discipline gates](#5-the-discipline-gates)
6. [Command reference](#6-command-reference)
7. [System blueprint](#7-system-blueprint)
8. [Workflows & automation](#8-workflows--automation)
9. [Skills](#9-skills)
10. [Deployment matrix](#10-deployment-matrix)
11. [Troubleshooting](#11-troubleshooting)
12. [FAQ](#12-faq)

---

## 1. Purpose
Most prompts make a model *sound* helpful. ORION makes it *behave*: it converts a blank chat model
into a disciplined operating companion whose good habits are **forcing functions, not suggestions**.
The core problem it solves — LLMs answer probabilistically from stale training instead of researching,
give up too early, and fabricate when unsure. ORION removes all three, on any model, with no code.

## 2. Goals
- **Model-agnostic:** frontier-grade behavior on any LLM (cloud, local GGUF, phone).
- **Research-first:** force real multi-source research before any substantive conclusion.
- **Never-quit:** ban premature "I can't" until real attempts + a tool search are exhausted.
- **Honest:** omission over fabrication; VERIFIED vs GUESS labels.
- **Token-efficient:** always-on core is tiny and prompt-cache-friendly; heavy detail is demand-loaded.
- **Portable & adaptive:** cold-boot anywhere; learn and mirror the user over the conversation.

## 3. What ORION does — functions
| Function | Behavior |
|---|---|
| Forced research | Consults GitHub · Reddit · X · YouTube · Google/docs · HN/StackOverflow before concluding; **proactively** on tool-capable platforms. |
| Effort scaling | 1 lookup for a fact; the six lanes for open-ended/compare/troubleshoot questions. |
| Never-quit gate | Blocks "can't/not-possible" until ≥2 real attempts + a tool search; only a named human gate stops it. |
| Anti-fabrication | Drops unsure claims; labels VERIFIED vs GUESS; never invents a source/API/path. |
| Adaptive persona | Learns tone, domain, and pacing; mirrors the user; `/personality_status` reports it. |
| In-chat memory | Journals key facts per turn; `/memory`, `/snapshot`, `/recall`; emits portable `/handoff` blocks. |
| Self-check | Runs a pass/fail questionnaire on its own draft before sending. |

## 4. Architecture — the tiers
| Tier | File | Loads | Cost |
|---|---|---|---|
| **1 — Core** | `boot/ORION_CORE.md` (~650 tok) | automatic (persona + gates + manifest) | tiny, always on |
| **2 — Deep** | `boot/ORION_BOOT.md` | automatic (full pattern: research forcing, commands, system map) | paid once, then cached |
| **3 — Situational** | `docs/`, `skills/`, deployment fills | only when the task calls for it | zero by default |

Tier 2's boot doc *contains* Tier 1, so one paste makes both automatic. See [SETUP.md](../SETUP.md).

## 5. The discipline gates
1. **Research-before-concluding** (unconditional; scale effort to difficulty).
2. **Never-quit** (≥2 attempts + tool search; only a named human gate stops it).
3. **Omission-over-fabrication** (drop unsure claims; label VERIFIED vs GUESS).
4. **Silent competence** (produce the result, don't narrate the process).
5. **Self-check** (run the questionnaire on your own draft before emitting).

The only valid stopping points are genuine human gates: password, 2FA, CAPTCHA, biometrics, payment,
account creation, or a destructive/irreversible action.

## 6. Command reference
| Command | Action |
|---|---|
| `/start` | Boot ORION, greet, report readiness |
| `/menu` | Show the command table |
| `/map [term]` | Summarize the system map (§4); with a term, what that subsystem does |
| `/research <q>` | Run forced six-lane research on the question |
| `/memory` | Summarize the last 5 journal entries |
| `/snapshot` | Mark the last journal entry permanent |
| `/recall <topic>` | Search conversation + journal for a topic |
| `/personality_status` | Report the learned-adaptation state |
| `/handoff` | Emit a portable HANDOFF block to resume the session cold elsewhere |
| `/status` | One-line heartbeat: persona · gates · journal length · research lanes used |

## 7. System blueprint
ORION is four layers stacked in one document:
1. **Persona layer** — identity + adaptive style (learns/mirrors the user; culture-neutral).
2. **Forcing gates** — the pass/fail discipline (research, never-quit, anti-fabrication, self-check),
   written with named blocks + MUST/NEVER + consequence so the model treats them as hard gates.
3. **Research engine** — the six-lane protocol; proactive when tools exist, otherwise it lists the
   exact queries and labels the answer GUESS.
4. **Memory layer** — a no-filesystem journal (append one `▤ [topic] fact` line per substantive turn),
   plus portable HANDOFF blocks for cold resume.

Data flow per turn: *user goal → (research gate: sources first) → reason → self-check → answer +
journal line*. On a `/start` it adopts persona + gates and waits for a goal; on a real question it
researches first.

## 8. Workflows & automation
- **Auto-wire** (`install/orion-wire.sh`) — installs ORION into local coding agents (Claude Code,
  Codex, any AGENTS.md agent) so Tier 1 + auto Tier 2 load every session. Idempotent; `--status`/`--unwire`.
- **Research loop** — for recurring jobs, wrap `/research` in your platform's scheduler/agent loop:
  define a goal + a numeric done-checklist + a token/iteration budget, let it research → grade → refine
  → mark done. (Inner loop = one mission self-checked to done; outer loop = a scheduled recurring run.)
- **Self-improving playbook** — after a task, have ORION append validated query patterns/learnings to a
  persistent notes file so its retrieval sharpens over time.
- **Two-model cross-grading** (optional) — have a second model score ORION's output against the goal
  before accepting; refine until it clears a threshold.

## 9. Skills
Skills are optional snippets you append to the boot doc (or drop in as a message) to give ORION a
task-specific capability without bloating the always-on core. See [`skills/`](../skills/). They are
**situational** (Tier 3) — load only the one the task needs. Ship your own by writing a short markdown
file: a title, when-to-use, and the exact steps/checklist.

## 10. Deployment matrix
| Platform | Put the boot where | Result |
|---|---|---|
| ChatGPT | Custom GPT / Project **Instructions** | auto every message, cached |
| Claude | Project custom instructions / API `system` | auto every message, cached |
| Gemini | Gem **instructions** | auto every message |
| Local (Ollama/llama.cpp) | `system` message | auto; mark cacheable |
| Mobile (MiniCPM-V app, etc.) | in-app System Prompt field | on-device, offline |
| File-upload chat (e.g. agentic) | attach `ORION_BOOT.md` + `/start` | full pattern |

## 11. Troubleshooting
| Symptom | Fix |
|---|---|
| Pasting a repo **URL** does nothing / web-searches unrelated repos | The model can't clone a link. **Upload the `.md` files** (or paste their contents) instead. |
| ORION describes research as an option but doesn't do it | Ensure you're on a tool-capable surface; ask a concrete question (not just `/start`). The current boot researches proactively on the first substantive question. |
| It says "I don't know about your system" | §4/§5 are fill-in placeholders by design (public build). Paste your system details there or tell it in chat. |
| Too many tokens per message | Use `boot/ORION_CORE.md` (Tier 1 only) in the system slot; let ORION demand-load the rest. |
| Behavior drifts over a long chat | Send `/start` to re-assert persona + gates, or re-paste the core. |
| A local model ignores the gates | Small models comply less; prefer a stronger model, or shorten to the core + your top 2 gates. |
| It fabricates or over-claims | Remind it of gate 3 (omission-over-fabrication); ask it to label VERIFIED vs GUESS. |

## 12. FAQ
- **Does it need internet?** No to boot; yes to research (it degrades gracefully — labels GUESS + lists queries when offline).
- **Does it store my data?** Only in the chat's own context (the in-chat journal). Nothing leaves the platform you're on.
- **Can I make a private/branded build?** Yes — swap the persona block; keep the gates. The pattern is persona-agnostic.
- **Is it tied to one vendor?** No. Any LLM, any host.

See also: [README](../README.md) · [SETUP](../SETUP.md) · [GUIDE](GUIDE.md) · [USE_CASES](USE_CASES.md).
