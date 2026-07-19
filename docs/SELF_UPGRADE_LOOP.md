# ORION Self-Upgrade Loop

ORION’s research reflex applies to its own capability gaps, not only to questions from the user.

## The closed loop

```text
OBSERVE A GAP
→ search current primary sources and maintained implementations
→ deduplicate against installed capabilities and prior decisions
→ score maintenance, license, cost, privacy, and fit
→ quarantine and inspect
→ run a bounded proof against the original gap
→ integrate, reject, defer with a named gate, or supersede
→ verify with an independent check
→ persist the decision and re-test the gap later
```

## Terminal states

- `INTEGRATED`: a reproducible test proves the system gained the intended capability.
- `REJECTED`: evidence shows the candidate is unsafe, stale, incompatible, or inferior.
- `DEFERRED-WITH-GATE`: a specific human or environmental gate is recorded.
- `SUPERSEDED`: a stronger maintained option already provides the capability.

“Found,” “bookmarked,” “downloaded,” and “installed” are not terminal states.

## Minimal capability ledger

```yaml
gap: what the system could not yet do
source: canonical URL or package identifier
status: INTEGRATED|REJECTED|DEFERRED-WITH-GATE|SUPERSEDED
proof: command, test, or artifact
verified_at: ISO-8601 timestamp
next_recheck: ISO-8601 date
notes: constraints, license, privacy, cost
```

The loop is model-agnostic. A scheduler can run discovery, but only a verified terminal state counts
as improvement.
