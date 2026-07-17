# deep-research
**When to use:** a hard, open-ended, or high-stakes question where a single-shot answer would be a guess.
**Steps:**
1. Decompose the question into 2–4 sub-questions.
2. For each, run all six lanes (GitHub · Reddit · X · YouTube · Google/docs · HN/StackOverflow). Spawn
   one sub-agent per lane if the platform supports parallel agents.
3. Compile a single condensed evidence digest (title · source · one-line finding · URL) — not raw dumps.
4. Cross-check: where sources disagree, say so and weigh them; drop anything you can't source.
5. Synthesize a cited answer; label each claim VERIFIED or GUESS.
**Done when:** every sub-question has ≥2 independent sources, disagreements are noted, and nothing is
asserted without a citation or a GUESS label.
