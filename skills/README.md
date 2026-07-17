# ORION skills

Skills are small, **situational** (Tier 3) capability snippets. Load only the one a task needs — append
it to the boot doc or drop it in as a message. They don't ride the always-on core, so they cost nothing
until used.

## Included
| Skill | Use it when |
|---|---|
| [`deep-research.md`](deep-research.md) | You want an exhaustive, cited, cross-checked answer on a hard question. |
| [`handoff.md`](handoff.md) | You're ending a session and want to resume cold elsewhere. |
| [`code-review.md`](code-review.md) | You want a disciplined review of a diff or file. |

## Write your own
A skill is just markdown with three parts:
```markdown
# <skill name>
**When to use:** <one line>
**Steps:**
1. ...
2. ...
**Done when:** <explicit, checkable condition>
```
Keep it short and imperative. Name the done-condition explicitly so ORION can't stop early.
