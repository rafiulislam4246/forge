# Remediation plan

_pending_

Findings become work here, in the order they should be fixed. This file is the
bridge from audit to workstream: each group below becomes `forge new "<title>"`.

## Order of work

| Order | Findings | Fix | Risk of fixing | Workstream |
|---|---|---|---|---|
| 1 | #3, #7 | what changes |  | `forge new "..."` |

Order by damage prevented per unit of work, not by how easy each one is. State
the risk of each fix: a change that could break working behaviour needs its own
plan and tests, not a quick patch.

## Fix now versus accept

| Finding | Decision | Reason |
|---|---|---|
|  | fix now / schedule / accept |  |

Accepting a finding is a legitimate engineering decision when it is recorded
with a reason. Quietly not fixing it is not the same thing.

## Regression guard

Before any of these fixes land, record the current passing baseline here, so a
fix that breaks something else is visible immediately.

- Test suite now:
- Build now:
- Known-good user flows:
