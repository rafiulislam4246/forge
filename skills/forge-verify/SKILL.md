---
name: forge-verify
description: "Evidence gate before any claim that something is done, fixed, working or deployed. Runs the project's real checks, drives user-visible changes in a real browser, checks for regressions against a recorded baseline, and writes the proof to the evidence ledger. Use before marking work complete, before telling the user a feature works, when a fix keeps reopening, and whenever the Forge evidence or UI gate reports a failure. Triggers on: forge verify, is it done, does it work, prove it, verify this, check for regressions, test it properly, it is still broken."
user_invocable: true
---

# forge-verify

The specific failure: work is described as complete, the description is
plausible, nobody ran the thing, and the next session builds on a claim as if it
were a fact. When that pattern repeats, every later problem gets harder to
diagnose, because the record is wrong rather than merely incomplete.

A claim is admissible only if a command ran and you read its output.

---

## 1. Run the checks

```sh
forge verify
```

It detects the project's own commands (test, build, typecheck, lint from
`package.json`, `pytest`, `go test`), runs them, and writes each result to the
ledger with its exit code. If it reports no commands detected, add them once:

```json
{ "verify": { "test": "pnpm test", "build": "pnpm build" } }
```

in `.forge/config.json`. A project with no verify command has no definition of
working, and that is the first bug to fix.

Every test, build or lint command run through Bash is also captured
automatically by a hook, so the ledger reflects what actually happened in the
session rather than what was reported.

## 2. What counts as evidence

| Claim | Admissible | Not admissible |
|---|---|---|
| Tests pass | runner output with the counts | "the tests should pass now" |
| Feature works | the feature exercised end to end, output quoted | the diff looks correct |
| Bug fixed | the original reproduction, no longer reproducing | the cause was identified |
| UI works | the real page driven, each element exercised | the component renders in a test |
| API integration works | a real call with its status and body | the client compiles |
| Performance improved | before and after, same measurement | the algorithm is better |
| Deployed | the deployed URL answering, with the build id | the deploy command exited 0 |
| Security fixed | the attack attempted and rejected | the input is now validated |

HTTP 200 is not proof the right thing happened. A green build is not proof a
feature works. Read the body, check the value, exercise the path.

## 3. The regression check

A fix that breaks something else is not a fix. Every verification quotes two
numbers:

```
before: 94 passed, 1 skipped
after:  96 passed, 1 skipped
```

If you do not have a before number, the suite's current state is your baseline
and you record it before changing anything. A bare "tests pass" hides a
regression and is not acceptable here.

## 4. User-visible changes: the browser gate

Load `browser-testing-with-devtools`. Tests do not catch a button wired to
nothing, a section that renders empty because the data shape changed, or a form
that silently fails to submit. Those are exactly the failures that reach the
user and come back as "this doesn't work".

Drive the real page and exercise **every** interactive element you touched:

- the page loads with no console errors
- each control does what it claims
- a form accepts valid input, shows an error on invalid input, and the record
  appears afterwards
- state survives a reload
- the layout holds at phone width

Then record it:

```sh
forge evidence add browser pass "clicked through /dashboard in Chrome" \
  "filters apply, empty state correct, no console errors, 390px layout holds"
```

If you cannot open a browser in this session, say so plainly and record it as
unverified. Do not let a test suite stand in for a thing nobody looked at.

## 5. When verification fails

That is a result, not an interruption. Load `debugging-and-error-recovery` and
find the root cause before changing anything. Resist the fix that makes the
symptom go away: the "fix it, new bug appears, fix that, the old one returns"
cycle is what happens when symptoms get patched in sequence.

Re-run the full check after the fix, not only the failing test.

## 6. Then say it plainly

Report what you verified and how, what you did not verify and why, and anything
that regressed. State completion without hedging when it is proven, and never
state it when it is not. "Implemented but unverified, needs a staging key" is
worth more than a confident guess, and it belongs in your reply rather than
being quietly dropped.
