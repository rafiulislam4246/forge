# Forge

Engineering gates for AI coding sessions. Turns "it wrote some code and said it
works" into a process with artifacts and proof, enforced by hooks rather than by
the model remembering to behave.

The failure this exists to prevent is specific: a request arrives, code appears,
the code is described as working, and the description is wrong. Every step of
that feels productive, which is why it survives wherever nothing checks it.

```
request ──→ research ──→ architecture ──→ plan ──→ tests ──→ code ──→ review ──→ evidence
                │              │            │        │                  │          │
           what already   decided once,  the gate  fail first,    fresh eyes,  a command ran
           exists here    in writing     opens     then pass      not the author  and was read
```

---

## What it installs

```
~/.claude/
├── forge/bin/forge              the CLI: POSIX sh, no dependencies
├── forge/hooks/                 7 hooks, the enforcement layer
├── skills/forge*/               5 skills: intake, build, audit, verify, router
├── skills/<discipline>/         16 engineering skills shipped in skills-library/
└── settings.json                hook wiring, merged into whatever is there

your-project/
├── .forge/
│   ├── config.json              strict mode, code globs, verify commands
│   └── evidence.log             every test, build and browser run, with its result
└── docs/engineering/
    ├── NNN-<slug>/              research, architecture, plan, test-plan, review
    ├── audit-YYYY-MM-DD/        scope, findings, remediation
    └── adr/NNNN-<slug>.md       decisions, with the alternatives they rejected
```

## Install

```sh
git clone https://github.com/rafiulislam4246/forge.git
cd forge
./install.sh --global --skills
```

`--global` wires the hooks for every project on the machine. `--skills` also
installs the 16 engineering discipline skills from this repo's `skills-library/`
into `~/.claude/skills` so they auto-trigger (test-driven-development,
planning-and-task-breakdown, spec-driven and source-driven development,
api-and-interface-design, documentation-and-adrs, code-review-and-quality,
doubt-driven-development, debugging-and-error-recovery,
browser-testing-with-devtools, frontend-ui-engineering, shipping-and-launch,
incremental-implementation, code-simplification, context-engineering,
interview-me), and makes the `/stack` router model-invocable if it was set to
user-only. A fresh clone is therefore complete: no other machine's files are
needed. Settings are backed up and merged, never replaced.

Then, in any project:

```sh
forge init                       # turn on the artifacts here
forge new "<what you build>"     # scaffold the five artifacts
forge verify                     # run the checks, record the evidence
forge strict on                  # gates block instead of advise
```

Gates are **advisory** until you turn strict on, per project.

## The seven hooks

| Hook | Event | Does |
|---|---|---|
| session-start | `SessionStart` | injects the contract, the active plan, the current task, gate state and recent evidence. Also fires on `compact`, so it survives a context compaction |
| prompt | `UserPromptSubmit` | a build request with no plan open gets the research-first rule next to it |
| pre-edit | `PreToolUse` Edit/Write | the plan gate. Product code is advised against, or denied in strict mode, until `plan.md` has real tasks. Tests, docs and config are never gated |
| post-bash | `PostToolUse` Bash | classifies every test, build, lint and browser command and writes the result to the ledger. A failing run is reported back as the project's current state |
| reanchor | `PostToolUse` Edit/Write | every 8th edit, re-injects the current task and the out-of-scope list. This is the mid-session drift fix |
| stop | `Stop` | end of turn: warns when code changed with no passing run, or UI changed with nobody having looked at it |
| task-complete | `TaskCompleted` | exit 2 in strict mode: a task cannot complete while the evidence gate fails |

## The three gates

```sh
forge gate code   # is there a plan with real tasks
forge gate done   # is there passing evidence newer than the last edit
forge gate ui     # did UI change without browser verification
```

The plan gate ignores template placeholders: a task line still containing
`<angle brackets>` does not count. Otherwise the gate would open on the
untouched scaffold, which would make it theatre.

The done gate compares timestamps, not claims. Evidence recorded before the
last edit does not prove anything about the code as it stands now.

## Commands

```sh
forge init                            scaffold .forge/ and docs/engineering/
forge kickoff "<project>"             open an intake: brief + checklist only
forge new "<title>"                   scaffold a workstream's five artifacts
forge list                            workstreams with real-task progress
forge use <slug>                      set the active workstream
forge status                          phases, tasks, gates
forge brief                           the full context block
forge anchor                          short re-anchor: the current task
forge adr "<decision>"                new numbered ADR
forge audit                           scaffold an audit of an existing codebase
forge verify [test|build]             run the checks, record the evidence
forge evidence add <kind> <pass|fail> "<cmd>" "<summary>"
forge evidence list
forge gate {code|done|ui}
forge waive <minutes> "<why>"         recorded bypass of the plan gate
forge strict [on|off]
forge doctor
```

Evidence kinds: `test`, `build`, `lint`, `browser`, `api`, `manual`, `verify`.

Env: `FORGE_PROJECT` pins the project root, `FORGE_CLI` the binary,
`FORGE_ANCHOR_EVERY` the re-anchor interval (default 8),
`FORGE_COOLDOWN_MIN` the Stop hook cooldown (default 10).

## The skills

| Skill | Use when |
|---|---|
| `forge` | Entry point. Routes a request into the right pipeline. |
| `forge-intake` | A new project or brief. Interviews, shows a completeness checklist, and **generates nothing until the user approves**. |
| `forge-build` | Building or changing a feature. The full six-phase pipeline. |
| `forge-audit` | Assessing an existing codebase. Scope first, reproduce everything, then an ordered remediation plan. |
| `forge-verify` | Before any claim that something is done, fixed or working. |

They defer to the discipline skills for the thinking: `source-driven-development`
and `spec-driven-development` for research, `api-and-interface-design` for
interfaces, `planning-and-task-breakdown` for the plan,
`test-driven-development` for implementation, `code-review-and-quality` and
`doubt-driven-development` for review, `browser-testing-with-devtools` for UI.

## Tests

```sh
sh test/e2e.sh
```

56 assertions over the whole gate matrix: advisory and strict behaviour, the
exemption list, the waiver path, evidence recording from real command output,
the done gate's timestamp comparison, the UI gate, hook cooldowns, re-anchoring,
and the scaffold-stays-shut property. Hooks are driven with real event JSON on
stdin rather than mocked.

## Forge and Continuum

They solve different halves of the same problem and are designed to sit together.

| | Holds | Answers |
|---|---|---|
| [Continuum](https://github.com/rafiulislam4246/continuum) | project memory across sessions | what is this project, where did we stop, what is next |
| Forge | the process for the current change | what is the plan, what is proven, what is still unverified |

With both installed, a new session receives the project's memory and its
engineering state before anyone types anything.

## Does this replace CLAUDE.md?

No. `CLAUDE.md` holds standing instructions. Forge holds the process and its
evidence, and the artifacts hold the knowledge that would otherwise bloat
`CLAUDE.md` into something nobody maintains.

## Uninstall

```sh
./uninstall.sh --global            # hooks and skills, artifacts kept
./uninstall.sh --global --purge    # artifacts too
```

## Sources

- [Claude Code hooks reference](https://code.claude.com/docs/en/hooks) - which events inject context, matchers, `permissionDecision`, `additionalContext`, exit codes
- [How Claude Code works](https://code.claude.com/docs/en/how-claude-code-works) - fresh context per session

MIT licensed.
