# code-review
**When to use:** reviewing a diff, file, or PR.
**Steps:**
1. State what the change is supposed to do (from the code, not assumptions).
2. Review in order: correctness → security → readability → performance. Cite exact lines.
3. For each finding: severity, the concrete failure it causes, and a fix.
4. Research any API/library/version you're unsure about (don't guess its behavior).
5. Separate must-fix from nice-to-have.
**Done when:** every finding names a real line + a concrete failure + a fix, and unsure claims were
researched or labeled GUESS.
