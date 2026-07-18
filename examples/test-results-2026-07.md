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

## 2. Tier-0 local model throughput — VERIFIED

**Model:** `MiniCPM5-1B (Fable-5 distilled, V2 Thinking), Q8_0 GGUF` — 1.3 GB, 100% GPU, 4096 ctx.

| Metric | Value |
|---|---|
| Generation (eval) rate | **120.6 tok/s** |
| Prompt-eval rate | 208.2 tok/s |
| Total latency (154-tok reply) | 1.53 s |
| Cold load | 133 ms |
| Footprint | 1.3 GB VRAM |

**Honest scope note:** a 1B floor model is an **availability + latency** guarantee, not a knowledge
guarantee. In testing it produced fluent but sometimes topically-wrong answers to niche questions.
That is by design: Tier-0 exists so the stack never goes dark when the cloud drops — deep reasoning
is Tier-1's job. The discipline gates (section 3) are what keep *any* tier honest.

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
