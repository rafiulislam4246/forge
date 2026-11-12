# Plan - {{TITLE}}

_pending_

This file is the gate. The plan gate stays shut until the `_pending_` marker is
gone and at least one **real** task exists, because that is the moment the work
stops being improvised.

A task line that still contains `<angle brackets>` is a placeholder and does not
count toward the gate. Replace the brackets with the actual file paths, the
actual test and the actual command.

Every task is small enough to finish and verify in a few minutes, names the
exact files, and carries its own verification. A task whose verification is
"looks right" is not a task yet.

## Tasks

- [ ] **T1** - <what changes>
  - Files: `path/to/file.ts`
  - Test first: `path/to/file.test.ts`, asserting <the specific behaviour>
  - Verify: `<command>` shows <the specific observable result>
- [ ] **T2** - <what changes>
  - Files:
  - Test first:
  - Verify:
- [ ] **T3** - <what changes>

## Order and why

Why the tasks are in this order: what each one unblocks. If any two can be done
independently, say so.

## Definition of done

The checks that must all pass before this workstream is closed. Name the
commands, so `forge verify` can run them and the claim becomes checkable.

- [ ] `<test command>` passes, with no new skips
- [ ] `<build or typecheck command>` passes
- [ ] For user-visible changes: the real page driven in a browser, result recorded
- [ ] review.md filled in by a reviewer that did not write the code

## Out of scope

The adjacent work this plan deliberately does not do. This is what stops the
implementation sprawling past what was agreed.
