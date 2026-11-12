---
name: forge-build
description: "The gated build pipeline for a feature or change: research what exists, decide the architecture, write the plan and test plan, implement test-first, review with fresh eyes, then prove it with evidence. Use when building, adding, changing or refactoring a feature in a project that has Forge gates, and when a plan already exists and the work needs executing task by task. Triggers on: forge build, build this feature, implement this, execute the plan, next task, continue the build, add this functionality."
user_invocable: true
---

# forge-build

One pipeline, six phases, each with an artifact that outlives the session. The
artifacts are not paperwork: they are what makes the next session able to
continue, and what makes a claim checkable later.

```sh
forge new "<title>"     # scaffolds the five artifacts, sets the active workstream
forge status            # where you are
```

---

## Phase 1 - Research (`research.md`)

Load `source-driven-development` and `spec-driven-development`.

The goal is to replace assumptions with facts about *this* codebase. Most of
what you are asked to build is partly built already, and building a second
implementation beside the first is the most common expensive mistake.

- Search for the existing implementation before designing a new one. Record what
  you found with file paths, and decide reuse, extend or replace.
- Read the external docs for every library and API involved, with versions.
  Quote the behaviour you rely on. Version drift is why correct-looking code
  fails.
- Write down the constraints that cannot move, each with the fact that proves it.
- List the open questions and mark which are blocking. Ask the blocking ones
  now, in one message, before designing.

Do not write product code in this phase. Reading code, running it to observe
behaviour, and writing throwaway probes are all fine and encouraged.

## Phase 2 - Architecture (`architecture.md`)

Load `api-and-interface-design` and `documentation-and-adrs`.

Decide the shape once, in writing. Name the alternatives you rejected and why
each lost; an approach with no rejected alternative was not a decision.

Write the interfaces out exactly, including their error cases. Designing the
failure paths here is what separates code that works on the happy path from code
that works. Record anything a later session might reopen:

```sh
forge adr "<the decision>"
```

## Phase 3 - Plan (`plan.md` + `test-plan.md`)

Load `planning-and-task-breakdown` and `incremental-implementation`.

The plan gate opens when `plan.md` loses its `_pending_` marker and has at least
one `- [ ]` task. Make that moment mean something:

- Each task is finishable and verifiable in a few minutes.
- Each task names its exact files, the test to write first, and the command that
  verifies it. "Looks right" is not a verification.
- The test plan derives from the invariants in the architecture, not from code
  that does not exist yet. Fill the "fails when" column: a test that no plausible
  bug could break is testing nothing.
- Write the out-of-scope list. The re-anchor hook shows it back to you, which is
  what stops a change sprawling over a long session.

## Phase 4 - Implement, task by task

Load `test-driven-development`. For UI work add `frontend-ui-engineering`.

For each task, in plan order:

1. Write the test. Run it. **Watch it fail**, and read the failure to confirm it
   fails for the reason you intended.
2. Write the smallest code that passes it.
3. Run the test again. Watch it pass.
4. Run the neighbouring tests. Quote the counts before and after; "tests pass"
   without a before number hides a regression.
5. Tick the task off in `plan.md`. The anchor hook reads that file, so a stale
   plan produces a confidently wrong anchor.

Match the conventions already in the repo, even where you would choose
differently. If the repo returns errors rather than throwing, that is the rule
here, and a session that "corrects" it is doing damage.

Stay in the plan. If the right move is outside it, stop, say so in one or two
sentences, amend the plan, then continue. A deviation that is written down is a
decision; one that is not is drift.

## Phase 5 - Review (`review.md`)

Load `code-review-and-quality` and `doubt-driven-development`.

The author is the worst reviewer of their own work, so do not review as the
author. Dispatch a subagent with fresh context, give it the diff and the
workstream folder, and withhold your reasoning so it cannot be anchored by it.

Blockers are resolved before the workstream closes. Paste the real evidence into
`review.md`, not a description of it.

## Phase 6 - Verify

Follow `forge-verify`. Nothing is done, fixed or working until a command ran and
its output was read.

```sh
forge verify
```

For anything a user can see, drive the real page in a browser and record what
you observed. Tests passing is not evidence that a button does what it should.

---

## Reporting

When the pipeline completes, report in a few lines: what landed with the
evidence for it, what is still unverified and why, what the review found, and
the next task. Never describe intended behaviour as observed behaviour.

If something failed, say it failed and quote the output. The ledger is written
from real runs by hooks, so an optimistic summary will contradict the record.
