# ORION OS 🛰️ — the autonomous AI operating system that researches before it answers

### ORION — **O**pen **R**easoning & **I**ntelligent **O**rchestration **N**etwork

**A hardened, model-agnostic AI operating pattern you paste into any LLM.**

<!-- SEO: autonomous AI agent · model-agnostic AI operating system · multimodal reasoning · agent orchestration · self-researching LLM prompt · anti-hallucination system prompt. Suggested GitHub topics: ai-agent, llm, autonomous-agents, prompt-engineering, ai-operating-system, multimodal, rag, agent-orchestration. -->
> Drop-in discipline layer that forces **any** LLM to research across the web before answering, refuse to give up, and never fabricate — Fable-5-grade behavior on any model.

ORION turns any blank chat model (ChatGPT, Claude, Gemini, a local GGUF, a phone chatbox) into a
disciplined operating companion: it adopts a persona, binds a set of anti-laziness / anti-give-up
**discipline gates**, and is *forced* to research across GitHub, Reddit, X, YouTube, Google, and
StackOverflow before it answers — instead of guessing probabilistically. It learns your style over
the conversation and adapts to you.

> Portable. Persistent. Personified. Hardened.

## Why

Most prompts make a model *sound* helpful. ORION makes it *behave*: the gates are forcing functions,
not suggestions. The model must produce evidence of real research before it's allowed to conclude
"I can't" or "that's not possible." The only valid stops are genuine human gates (password, 2FA,
CAPTCHA, payment, account creation, destructive actions).

## Quickstart (Tier 1 & 2 automatic)

1. Paste [`boot/ORION_BOOT.md`](boot/ORION_BOOT.md) into your platform's **persistent instructions**
   slot — Custom GPT / Claude Project / Gemini Gem / API `system`. That makes **Tiers 1 & 2 apply to
   every message automatically**, and prompt caching keeps it nearly free. (Full steps: [SETUP.md](SETUP.md).)
2. Send `/start`. ORION boots, greets you, and is ready.
3. Fill in **§4 (System Map)** and **§5 (Memory/RAG)** for your own deployment.
4. **Tier 3** (deployment fills, skills, teaching module) loads only when a task needs it — see SETUP.md.

Token-constrained? Use [`boot/ORION_CORE.md`](boot/ORION_CORE.md) (Tier 1 only, ~650 tok) instead.

## Auto-wire your local coding agents

If you use Claude Code / Codex / other AGENTS.md-aware agents, wire ORION in once and it loads every
session automatically (Tier 1 core + auto Tier 2), token-efficiently:

```bash
git clone https://github.com/FutronPrime/orion-os && cd orion-os
./install/orion-wire.sh            # wire everything present   (--status to check, --unwire to remove)
```

It's idempotent (marker-based, safe to re-run), self-refreshing, and only touches agents you actually
have installed.

## Transcription cascade — never fail to assimilate a video

No single transcriber wins every case: hosted LLM URL-ingest is fast but rejects long (>~2h) videos,
yt-dlp captions hit HTTP 429 and don't exist for many live VODs, and cloud quotas run out.
[`tools/orion-transcribe.sh`](tools/orion-transcribe.sh) is a system-agnostic orchestrator that
**tries engines in order until one succeeds**, so you never hit a "can't transcribe" wall.

**Engine order** (skip/reorder with `--engines`):

1. **gemini** — optional `gemini` CLI transcription (fast; skipped if the CLI isn't installed)
2. **ytdlp-subs** — yt-dlp auto/uploaded captions (cheap when they exist)
3. **local-whisper** — **the sovereign floor**: yt-dlp pulls bestaudio → ffmpeg chops it into
   `--chunk-secs` segments → `whisper` (or `mlx_whisper`) transcribes each chunk → the pieces are
   stitched back together. It handles **any length**, needs **no captions**, and has **no rate
   limits**. As long as you have `ffmpeg` + a whisper CLI + disk for the audio, it will finish.
4. **transcribe-anything** — optional pip engine (insanely-fast-whisper), auto-installed on demand
5. **aws-transcribe** — optional cloud last resort (needs `AWS_TRANSCRIBE_BUCKET` + AWS creds)

Exit `0` if any engine produced a transcript; `3` if every engine failed (with a diagnosis pointing
at the per-engine error logs).

```bash
# Transcribe a video, forcing straight to the sovereign local floor:
tools/orion-transcribe.sh "https://youtu.be/VIDEO_ID" --engines local-whisper --model base --out out.txt

# Full cascade with 5-minute chunks, ingesting into your own SQLite knowledge DB:
tools/orion-transcribe.sh "https://youtu.be/VIDEO_ID" --chunk-secs 300 --ingest-db ./transcripts.db

# A local file, and a batch from a URL list:
tools/orion-transcribe.sh --local ./lecture.mp4 --out lecture.txt
tools/orion-transcribe.sh --file urls.txt
```

**Requires** `yt-dlp`, `ffmpeg`/`ffprobe`, and one of `whisper` (`pip install openai-whisper`) or
`mlx_whisper` (`pip install mlx-whisper`, Apple Silicon). The local-whisper technique and the
engine-variety approach draw on the open-source projects
[transcribe-anything](https://github.com/zackees/transcribe-anything),
[buzz](https://github.com/chidiwilliams/buzz),
[vibe](https://github.com/thewh1teagle/vibe),
[AI-Video-Transcriber](https://github.com/wendy7756/AI-Video-Transcriber),
long-video-transcripts, and
[aws-video-transcriber](https://github.com/awslabs/aws-video-transcriber).

## Documentation

| Doc | Read it for |
|---|---|
| [SETUP.md](SETUP.md) | Tier-by-tier setup (Tier 1 & 2 automatic, Tier 3 situational) |
| [docs/GUIDE.md](docs/GUIDE.md) | How-to: 5-minute quickstart, first research session, tips |
| [docs/MANUAL.md](docs/MANUAL.md) | Full manual — purpose, goals, functions, commands, blueprint, workflows, troubleshooting, FAQ |
| [docs/USE_CASES.md](docs/USE_CASES.md) | What ORION does + example deployments |
| [skills/](skills/) | Situational skill snippets (deep-research, handoff, code-review) + how to write your own |
| [docs/microgpt/](docs/microgpt/) | Educational "build-your-own-LLM" module |

## What's inside

| Path | What |
|---|---|
| `boot/ORION_CORE.md` | **Tier-1** lean core (~650 tokens) — put this in your persistent system-prompt slot |
| `boot/ORION_BOOT.md` | **Tier-2** full boot (persona + gates + research forcing + commands) — paste once |
| `boot/ORION_COMPLETE.md` | **Everything in one file** (boot + manual + guide + use-cases + skills) — drag this into any file-upload chat |
| `install/orion-wire.sh` | One-command auto-wire into Claude Code / Codex / AGENTS.md agents |
| `install/build-bundle.sh` | Rebuild `ORION_COMPLETE.md` after editing any doc |
| `docs/` | Guide, manual, use-cases, microGPT module |
| `skills/` | Optional add-on skill snippets you can append to the boot doc |
| `examples/` | Sample sessions and deployment fills |

## Token efficiency (infuse it every message without burning tokens)

Two tiers + prompt caching:
1. **Core** (`boot/ORION_CORE.md`, ~650 tok) in your platform's persistent instructions slot (Custom
   GPT / Claude Project / Gemini Gem / API system prompt). A static system prefix is **prompt-cached**,
   so after the first turn it costs ~10% — effectively free to carry every message.
2. **Deep boot** (`boot/ORION_BOOT.md`) pasted once when you want full context; cached thereafter.
3. Heavy detail is **demand-loaded** only when a command needs it — nothing big rides every turn.

## Command surface

`/start` · `/menu` · `/map [term]` · `/research <q>` · `/memory` · `/snapshot` · `/recall <t>` ·
`/personality_status` · `/handoff` · `/status`

## Educational component — microGPT

`docs/microgpt/` folds in the *understand-the-machine* layer: a pointer to Andrej Karpathy's
[microGPT](https://karpathy.github.io/2026/02/12/microgpt/) — a ~200-line, zero-dependency,
from-scratch GPT (its own scalar autograd, a one-block Transformer, Adam, sampling). It's the
clearest way to teach a user (or ORION itself, when asked to explain) what tokens, embeddings,
backprop, and attention actually are before touching a real finetune. ORION's `/map llm` and
teaching flows reference it. It is educational scaffolding — not a training substrate.

## Personas

- **ORION** (this repo) — public / commercial, culture-neutral, personality-adaptive.
- The same pattern supports private, culture-tuned builds by swapping the persona block.

## License

MIT — see [LICENSE](LICENSE).
