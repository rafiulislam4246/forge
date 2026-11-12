---
name: forge-audit
description: "Audit an existing codebase as an engineering team would: declare scope and severity first, run systematic passes over correctness, tests, error paths, auth, secrets, data, UI and performance, reproduce every finding, then turn findings into an ordered remediation plan. Use when asked to audit, review or assess an existing project, to find what is broken or missing, to check if something is production ready, or before taking over unfamiliar code. Triggers on: forge audit, audit this project, review this codebase, what is wrong with this, is this production ready, find the bugs, assess this code, health check."
user_invocable: true
---

# forge-audit

An audit that wanders through whatever looks interesting produces a document
nobody can act on, and leaves the dangerous parts unchecked. The discipline is
to declare the scope first, make systematic passes, and reproduce everything you
claim.

```sh
forge audit      # scaffolds scope.md, findings.md, remediation.md
```

You run that, and every other command in this skill. The user asked for an
audit; they should not have to set one up to get one.

**Report, do not fix.** An audit that silently repairs things destroys its own
evidence and widens its blast radius. Collect findings, then propose the
remediation order and let the user choose. The exception is a live data-loss or
credential-exposure risk: name it immediately, before finishing the audit.

---

## 1. Scope first (`scope.md`)

Write it before reading code. What is in, what is out, why the audit is
happening, and what the severity words mean for this project. Severity is
relative to consequence: the same bug is a blocker in a payment path and a minor
in an internal tool.

Then read the project's own documentation, and note where the docs and the code
disagree. Those disagreements are findings.

## 2. The passes

Work through these in order, ticking the checklist in `scope.md`. Each pass ends
with either a finding, or a line in the "verified as working" table. The second
is as valuable as the first, because it stops the next session re-auditing it.

| Pass | Looking for | Skill to load |
|---|---|---|
| Cold start | does it run from a clean clone, following only its own docs | |
| Tests | present, passing, asserting something real, not tautologies | `test-driven-development` |
| Correctness | main paths read against the stated requirements | `code-review-and-quality` |
| Error paths | bad input, timeouts, empty state, partial failure, retries | `debugging-and-error-recovery` |
| Auth | enforced where claimed, not only in the UI; roles honoured server side | |
| Secrets | nothing committed, nothing logged, nothing in client bundles | |
| Data | schema integrity, reversible migrations, no silent loss, no unbounded growth | |
| UI | every interactive element driven in a real browser | `browser-testing-with-devtools` |
| Performance | the paths that carry real volume, N+1 queries, unbounded loops | |
| Observability | would a failure be noticed without a user reporting it | |
| Dependencies | versions, advisories, abandoned packages, duplicate libraries | |

Run the code. An audit done by reading alone finds the bugs that are visible and
misses the ones that matter. Start the app, hit the endpoints, run the tests,
click the UI.

## 3. Findings (`findings.md`)

Every finding needs a reproduction, not an opinion. One row each, worst first:
severity, what it is, `file:line`, the exact command or steps that demonstrate
it, and what the user or the business loses.

If it cannot be demonstrated, it is a note, not a finding. Mixing the two is how
audits lose credibility: one unreproducible claim makes a reader doubt the
reproducible ones.

Paste real evidence underneath: failing output, error logs, screenshots, response
bodies. Record each verified-working area with the command that proved it:

```sh
forge evidence add test pass "pnpm test" "94 passed, 1 skipped"
forge evidence add browser fail "clicked Save on /settings" "no request fired, console: handler undefined"
```

## 4. Remediation (`remediation.md`)

Findings become ordered work. Order by damage prevented per unit of effort, not
by what is easiest. For each group, state the risk of the fix itself: a change
that could break working behaviour needs its own workstream with its own plan
and tests, not a quick patch.

Record the current passing baseline before any fix lands, so a fix that breaks
something else is immediately visible.

Then each group becomes real work:

```sh
forge new "Fix #3 and #7: <title>"
```

which runs the full build pipeline, including tests for the bug that was found.
A bug fixed without a test asserting the bug is a bug waiting to return, and
that is the mechanism behind "we fixed this already".

## 5. Report

Lead with the three things that matter most, not the full list. Then: how many
findings at each severity, what is verified as working, what was not checked and
why, and the first remediation step. Offer the ordered plan and stop; the user
decides what gets fixed.
