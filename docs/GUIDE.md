# ORION OS — How-to guide

A practical walkthrough: get ORION running in 5 minutes, then use it well.

## 1. Five-minute quickstart
1. Open [`boot/ORION_BOOT.md`](../boot/ORION_BOOT.md) and copy the whole file.
2. Paste it into your platform's **persistent instructions** slot (not the chat box):
   - **ChatGPT** → create a Custom GPT → paste into *Instructions*. (Or a Project's instructions.)
   - **Claude** → a Project → *Custom instructions*. (Or the API `system` field.)
   - **Gemini** → create a Gem → *Instructions*.
   - **Local (Ollama/llama.cpp)** → send it as the `system` message.
   - **A chat that only takes files** (e.g. an agentic chat) → attach `ORION_BOOT.md` as a file.
3. Send `/start`. ORION boots, greets you in persona, and is ready.

That's it — Tiers 1 & 2 are now applied to every message automatically, and prompt caching keeps it
nearly free. Token-constrained? Use `boot/ORION_CORE.md` instead (Tier 1 only, ~650 tokens).

## 2. Your first research session
Ask a real, open-ended question — not a `/start`:

> *"What's the best open-source vector database for a small RAG app right now, and why?"*

On a tool-capable platform ORION will **automatically** run the six lanes (GitHub · Reddit · X ·
YouTube · Google/docs · HN/StackOverflow), then answer with cited findings and VERIFIED/GUESS labels —
instead of guessing from stale memory. If it has no tools, it says so, labels the answer GUESS, and
lists the exact queries you should run.

Try `/research <topic>` to force it explicitly, and `/status` to see how many lanes it used.

## 3. Teach ORION about your system (optional)
The public build ships with **§4 (System Map)** and **§5 (Memory/RAG)** as fill-in placeholders — it
knows nothing about your setup until you tell it. Two ways:
- **Persistent:** paste your services/ports/tools into §4 and your data sources into §5 of your copy of
  `ORION_BOOT.md`, then re-load it.
- **Ad-hoc:** just describe your system in chat; ORION will use it for that session and can `/handoff`
  a summary so the next session picks up cold.

## 4. Using the commands
- `/menu` — see everything ORION can do.
- `/map [term]` — recap the system map, or explain one subsystem.
- `/memory`, `/snapshot`, `/recall <topic>` — the in-chat memory: summarize recent facts, pin one,
  or search the conversation.
- `/handoff` — get a portable block you can paste into a fresh session (or a different LLM) to resume
  exactly where you left off.
- `/personality_status` — see how ORION has adapted to your style.

## 5. Automate it
- **Wire your coding agents once:** `./install/orion-wire.sh` (see [SETUP.md](../SETUP.md)) — ORION then
  loads every session in Claude Code / Codex / AGENTS.md agents.
- **Recurring research:** wrap `/research` in your platform's scheduler or agent loop with a clear
  done-checklist and a token budget; let it research → grade → refine → mark done.

## 6. Tips
- Put the boot in the **system slot**, never re-paste it into each user turn — that's what caching is for.
- For a branded/private variant, swap only the persona block and keep the gates.
- If a small local model ignores the gates, use a stronger model or trim to the core + your top two gates.
- Long chat drifting? Send `/start` to re-assert persona + gates.

Next: the full [Operations Manual](MANUAL.md) · [Use cases](USE_CASES.md).
