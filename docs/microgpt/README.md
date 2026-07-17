# microGPT — the understand-the-machine module

ORION can *explain the machine*, not just use it. This module points at the smallest honest
implementation of a GPT so a user (or ORION, when teaching) can see every moving part.

## What it is

Andrej Karpathy's **microGPT** — a single ~200-line, dependency-free Python file that contains the
whole algorithmic essence of training and running a GPT:

- its own **scalar autograd** engine (a `Value` class — no PyTorch, no NumPy),
- a **one-block Transformer** forward pass (token+position embeddings → RMSNorm → 4-head causal
  self-attention with a KV cache → ReLU MLP → logits),
- a hand-written **Adam** loop with linear LR decay,
- character-level tokenizer (27-token vocab, BOS), and temperature sampling.

It trains on ~32k baby names and, in about a minute on a CPU, drops loss from ~3.30 to ~2.37 and
prints new plausible names. Total model size: ~4,192 parameters.

## Sources

- Blog: https://karpathy.github.io/2026/02/12/microgpt/
- Code (gist): https://gist.github.com/karpathy/8627fe009c40f57531cb18360106ce95
- Lineage: micrograd → makemore → nanoGPT → microGPT

## Why ORION includes it

- **Teaching:** `/map llm` and any "explain how an LLM works" request can walk this file top to
  bottom — tokens, embeddings, backprop, attention, cross-entropy — with nothing hidden behind a
  framework. Modern-correct choices (RMSNorm, no-bias, KV cache) mean the mental model transfers to
  real stacks.
- **Honesty:** it is educational scaffolding. Its scalar loops make it transparent but too slow to
  scale — it is **not** a finetuning base. For real small models use nanoGPT / HF Transformers /
  Unsloth. ORION states this rather than overselling it.

## Run it

```bash
python microgpt.py     # no install; the dataset auto-downloads on first run
```
