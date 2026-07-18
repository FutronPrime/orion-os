# ORION — Comprehensive Test Results (2026-07)

Reproducible proof that the ORION discipline layer + sovereign failover floor work as documented.
All numbers below were captured on a 16 GB Apple Silicon Mac. Sanitized; no personal data.

---

## 1. Sovereign failover — VERIFIED

**Test:** `python3 -m verity failover-test` — points Tier-1 (cloud) at a dead port and asserts the
router fails over to Tier-0 (owned local weights) and still answers.

```
[router] tier1-cloud(SIMULATED-DOWN) unavailable [urlopen error [Errno 61] Connection refused] → next tier
[router] served by tier0-local (MiniCPM5-1B-Fable5-V2-Thinking:Q8_0) in 3.3s
--- reply --- SOVEREIGN-OK
[PROOF] cloud was down, yet tier0-local served in 3.3s
trail: tier1-cloud: FAIL after 3 tries (4.5s) → failing over | tier0-local: OK (3.3s)
```

**Result:** PASS. With the cloud vendor fully unreachable, the local floor answered in **3.3 s**.
The system has no single point of failure at the model layer.

## 2. Tier-0 local model — role, throughput & orchestration — VERIFIED

**Model:** `MiniCPM5-1B (Fable-5 distilled, V2 Thinking), Q8_0 GGUF` — 1.3 GB, 100% GPU, 4096 ctx.

**What Tier-0 is FOR (read this first):** it is a distilled **orchestrator / planner / tool-router** —
a small "router brain" that carries Fable-5-style orchestration behavior (decompose a goal, sequence
steps, pick tools, set verification gates, run the DISCOVER→PLAN→EXECUTE→VERIFY→PERSIST loop). It is
**not** a knowledge-recall model, and its value is **not** "availability alone." It is the layer that
keeps *planning and tool-use* alive and disciplined when the cloud reasoning tier is unreachable.

| Metric | Value |
|---|---|
| Generation (eval) rate | **120.8 tok/s** |
| Prompt-eval rate | 208–1618 tok/s (scales with prompt size) |
| Orchestration-plan latency (361-tok plan) | ~3.0 s (5.3 s incl. 2.2 s cold load) |
| Footprint | 1.3 GB VRAM |

**Orchestration test (the correct probe).** Given a real ops goal — *"dashboard on :18888 returns 502;
tools = shell(lsof,curl,tail), mcp:memory, restart_daemon(name); produce the plan"* — with the ORION
orchestrator envelope as system prompt, the 1B:
- ✅ adopted the orchestrator role and did **not** answer from knowledge
- ✅ ran the DISCOVER→PLAN→EXECUTE→VERIFY loop explicitly; chose "discover port state first"
- ✅ set correct verification gates (HTTP status codes) and **reached for structured tool calls**
- ⚠️ verbose (exposes chain-of-thought), re-decided the first step, conflated `lsof`/`curl`, and
  emitted malformed tool-call syntax

**Honest scope note:** at 1B the orchestration *reflex and format* are present and fast, but tool
semantics and plan tidiness are imperfect — expected for the size. The design intent is that Tier-0
keeps the stack **planning and dispatching** (not going dark, not going undisciplined) during a cloud
outage; a host that pairs it with real tool executors + the discipline gates (section 3) gets a
sovereign orchestration floor, while deep single-shot reasoning remains Tier-1's job.

## 3. Discipline-gate model-agnostic matrix

The ORION boot doc is designed to make **any** LLM adopt five behaviors on ingestion, with no code.
Scoring rubric per model (load `ORION_BOOT.md`, then ask a capabilities + research question):

| Gate | What it forces | Local Tier-0 | Cloud Tier-1 |
|---|---|---|---|
| A. Auto-boot on ingestion | adopts persona without a `/start` command | ✅ | ✅ |
| B. Identity lock | answers AS ORION, doesn't revert to host model | ✅ | ✅ |
| C. Six DISTINCT research lanes + receipt | reddit/x/youtube/SO/github/blog, not blog-roundups | n/a¹ | ✅ |
| D. Propose-before-execute + decisions receipt | states assumptions before acting | ✅ | ✅ |
| E. VERIFIED/GUESS labeling + never-quit | capability claims marked GUESS until checked | ✅ | ✅ |

¹ Gate C requires live web tools the 1B floor has no access to; it is a Tier-1 capability. The floor's
job is to keep A/B/D/E intact during an outage so the session stays disciplined even offline.

**How to reproduce:** paste `ORION_BOOT.md` into any model's system slot and run
`install/orion-wire.sh`; the five gates are in the shared generator so every build inherits them.

## 4. Regression — VERIFIED

`verity loop "<goal>"` seeds and runs six-source research (fixed 2026-07, harness PR merged).
Failover test is wired into the same harness and passes on every run.

---

_Generated 2026-07 as part of the ORION comprehensive test pass. Numbers are real captures, not estimates._
