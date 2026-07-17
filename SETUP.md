# ORION setup — Tier 1 & 2 automatic, Tier 3 situational

ORION is tiered so it's **always on without burning tokens**. Set it up once and Tiers 1 & 2 load
automatically every message (via your platform's persistent instructions + prompt caching); Tier 3 is
pulled only when a task needs it.

## The tiers

| Tier | File | Loads | Cost |
|---|---|---|---|
| **1 — Core** | `boot/ORION_CORE.md` (~650 tok) | **automatic** — persona + gates + manifest | tiny, always on |
| **2 — Deep** | `boot/ORION_BOOT.md` | **automatic** — full pattern (research forcing, commands, your system map) | paid once, then cached |
| **3 — Situational** | `docs/`, deployment fills, skills, rebuild/export docs | **only when the task calls for it** | zero by default |

Because Tier 2's boot doc already *contains* Tier 1, one paste makes both automatic.

## Make Tier 1 & 2 automatic (pick your platform)

- **ChatGPT (Custom GPT / Project):** paste `boot/ORION_BOOT.md` into **Instructions**. It's now applied
  to every message automatically, and OpenAI caches the static prefix.
- **Claude (Project / Console):** paste `boot/ORION_BOOT.md` into the Project's **custom instructions**
  (or the API `system` field). Anthropic prompt-caches it — ~10% cost on repeat turns.
- **Gemini (Gem):** paste `boot/ORION_BOOT.md` into the Gem's **instructions**.
- **Local (Ollama / llama.cpp / any OpenAI API):** send `boot/ORION_BOOT.md` as the `system` message and
  mark it cacheable.
- **Token-constrained context?** Use `boot/ORION_CORE.md` (Tier 1 only, ~650 tok) instead, and let ORION
  pull the rest on demand.

> **Why this is cheap:** a *static system prefix* is prompt-cached by every major provider — you pay full
> price once, then a fraction per turn. So "infuse it every message" costs almost nothing. What's
> expensive is re-pasting a big doc into each **user** turn — don't do that; put it in the system slot.

## Tier 3 — situational (don't carry it by default)

Load these only when the moment calls for it, then drop them:
- **Deployment fill** (`examples/deployment-fill-example.md`) — when you point ORION at a specific system.
- **Skills** (`skills/`) — append a skill snippet only for the task that needs it.
- **microGPT teaching module** (`docs/microgpt/`) — only when explaining how LLMs work.
- Any large export/rebuild doc for your own system — situational, never in the always-on slot.

ORION emits `/status` showing which tiers are active and how many research lanes it has used.
