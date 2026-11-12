---
name: forge
description: "Engineering process entry point. Routes any build, fix or audit request into the gated pipeline (research, architecture, plan, test-first implementation, review, evidence) and keeps the project's engineering artifacts current. Use at the start of any work on a project that has a .forge directory, when asked to build or add a feature, when a fix keeps reopening, when asked to audit an existing codebase, or when the gates report a failure. Triggers on: forge, build this, add a feature, implement, audit this project, review this codebase, why does this keep breaking, engineering process, plan before code."
user_invocable: true
---

# forge

The failure this exists to prevent: a request arrives, code appears, the code is
described as working, and the description is wrong. Every part of that sequence
feels productive, which is why it survives without a process around it.

Forge replaces it with a pipeline whose gates are checked by hooks rather than
by memory. Your job is to run the pipeline, not to decide each time whether it
is worth running.

---

## 1. Know where you are

```sh
forge status      # active workstream, phase state, gate state
forge brief       # the full context block, if the session hook did not inject it
```

If the project has no `.forge/`, run `forge init` yourself, now, and carry on.

**You run every `forge` command in this system. Never hand one to the user to
type, never make an answer wait on them running something, and never present
setup as a prerequisite they must do first.** The user describes what they want
in ordinary words; translating that into commands is your job. The only thing
that is ever theirs to do is a decision: approving a brief, choosing what to
fix, or confirming something risky.
If `.continuum/` is also present, read its state too: Continuum holds the
project's memory across sessions, Forge holds the process for the current
change. Neither replaces the other.

---

## 2. Route

| The request | Branch |
|---|---|
| Build, add, implement, redesign something | **Build pipeline.** Follow `forge-build`. |
| A bug, a failing test, "it's broken" | **Debug first.** Load `debugging-and-error-recovery`, find the root cause, then treat the fix as a small build pipeline. |
| "Audit this", "review this codebase", "what's wrong with X" | **Audit.** Follow `forge-audit`. |
| "Is this done?", "does this work?" | **Verify.** Follow `forge-verify`. Never answer from the diff. |
| A genuinely one-line fix | `forge waive 30 "<why>"`, fix it, `forge verify`. The waiver is recorded, which is the point. |
| Continue work already in flight | `forge status`, read the artifacts, resume at the current task. |

Choose one branch and say which. Routing silently is how the pipeline gets
skipped.

---

## 3. The pipeline, and why each gate is there

```
research ──→ architecture ──→ plan ──→ tests ──→ code ──→ review ──→ verify
    │             │             │         │                  │          │
 what already  decided once,  the gate  fail first,    fresh eyes,  evidence,
 exists here   in writing     opens     then pass      not the author  not a claim
```

| Phase | Artifact | Skills to load | Gate |
|---|---|---|---|
| Research | `research.md` | `source-driven-development`, `spec-driven-development` | none, but architecture written without it will be wrong |
| Architecture | `architecture.md` | `api-and-interface-design`, `documentation-and-adrs` | decisions recorded as ADRs |
| Plan | `plan.md`, `test-plan.md` | `planning-and-task-breakdown`, `incremental-implementation` | **plan gate**: product code is blocked until tasks exist |
| Implement | code + tests | `test-driven-development` | test written and watched failing first |
| Review | `review.md` | `code-review-and-quality`, `doubt-driven-development` | blockers resolved |
| Verify | evidence ledger | `forge-verify`, `browser-testing-with-devtools` | **evidence gate**: no passing run, not done |

For UI work add `frontend-ui-engineering` at implement, and the browser gate at
verify. A UI change nobody looked at in a browser is unverified regardless of
what the tests say.

---

## 4. Rules that do not bend

1. **No product code before `plan.md` has tasks.** The hook enforces it on
   `src/`, `app/`, `lib/`, `api/`, `convex/` and friends. Tests, docs and config
   are never blocked, so there is always a legal next move.
2. **Tests before the code they cover**, and watched failing first. A test that
   has never failed is not evidence.
3. **Evidence or it is not done.** `forge verify` runs the project's checks and
   records the result. `forge evidence add browser pass "<how>" "<what you saw>"`
   for anything a user can see.
4. **Report failure as failure.** Quote the output. The evidence ledger is
   written by hooks from real runs, so a claim that contradicts it will be
   visible to the next session.
5. **Tick tasks off in `plan.md` as they pass.** The re-anchor hook reads that
   file; a stale plan produces a confidently wrong anchor.
6. **Stay inside the plan's scope.** If the right move is outside it, say so and
   amend the plan rather than widening the change quietly.

---

## 5. When the gates fight you

They are advisory until someone runs `forge strict on`. A gate that fires is
information, not an obstacle:

- **Plan gate fires** and the work really is substantial: stop and plan. That is
  the gate working.
- **Plan gate fires** on a trivial fix: `forge waive 30 "<reason>"`. One
  command, and the bypass is on the record.
- **Evidence gate fires**: run `forge verify`. If it cannot run here, say which
  part is unverified in your reply instead of leaving the claim standing.
- **UI gate fires**: drive the actual page. Screenshot or interact with it, then
  record browser evidence.

Never work around a gate by writing the code somewhere the hook does not look.

---

## 6. Sub-skills

| Skill | Use when |
|---|---|
| `forge-build` | Building or changing a feature. The full pipeline. |
| `forge-audit` | Assessing an existing codebase, finding what is actually broken. |
| `forge-verify` | Before any claim that something is done, fixed or working. |
