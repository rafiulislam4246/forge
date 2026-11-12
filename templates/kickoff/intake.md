# Intake checklist - {{TITLE}}

_pending_

Mark every line `known`, `assumed` or `missing`, and write the answer next to
anything known or assumed. Ask only the missing lines that would change what
gets built; everything else becomes a written assumption.

**No README, folder, plan or code is created until the user approves this
checklist.**

| # | Area | What must be settled | Status | Answer |
|---|---|---|---|---|
| 1 | Outcome | what exists at the end, and how we know it works |  |  |
| 2 | Users | who uses it and what they are doing when they do |  |  |
| 3 | Scope | version one's boundary, and what is explicitly later |  |  |
| 4 | Data | what is stored, where, who may read it |  |  |
| 5 | Integrations | every external service, and whether credentials exist |  |  |
| 6 | Stack | language, framework, database, hosting, and what forces them |  |  |
| 7 | Auth | accounts yes or no, and which roles exist |  |  |
| 8 | Volume | expected load, and the latency that actually matters |  |  |
| 9 | Compliance | any regulation, data residency or audit requirement |  |  |
| 10 | Budget | spend limits on paid services |  |  |
| 11 | Deployment | where it runs, who deploys, what must never auto-deploy |  |  |
| 12 | Timeline | the deadline that exists, if one does |  |  |
| 13 | Existing work | code, designs or docs that already exist |  |  |
| 14 | Done | the definition of done for version one |  |  |

## Questions for the user

Numbered, at most seven, each with your recommended default so the user can
answer "defaults except 3".

1.

## Assumptions I will build on

Written down so they are cheap to correct. An assumption the user cannot see is
a decision taken on their behalf without telling them.

-

## On approval I will generate

- `README.md` - cold-start instructions, run, test, deploy, where artifacts live
- folder structure per the chosen stack's conventions
- `CLAUDE.md` - project commands, conventions, traps, Forge gates
- `.gitignore`, dependency manifest, stack config
- test runner configured, with one real passing test
- `.env.example` - every variable named, no values
- ADRs for the stack and data decisions
- `docs/engineering/001-<slug>/` - research, architecture, plan, test-plan, review

## Approval

- [ ] The user has confirmed the brief is complete. Date and their words:
