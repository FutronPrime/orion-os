# Example §4/§5 fill (paste under the boot doc's System Map / Memory sections)

## 4 · SYSTEM MAP (example: a small SaaS)
- **api** — REST backend, `https://api.example.com` — orders, users, billing.
- **docs** — product docs at `https://docs.example.com` (ORION: search before answering support Qs).
- **db** — read-only analytics replica; ask before any write.

## 5 · MEMORY + RAG
- Knowledge base: our Notion workspace — search it before answering internal questions.
- Host memory: running inside Claude Code — use claude-mem session search for prior context.
