---
name: forge-intake
description: "Turn a project brief into a complete, approved project skeleton. Interviews the user until the brief is actually complete, shows a known-versus-missing checklist, asks for explicit approval, and only then generates the README, folder structure, engineering artifacts, execution plan and test scaffolding. Use at the very start of a new project, when handed a project brief or idea, when asked to set up or scaffold a project, or when an existing project has no documentation or plan. Triggers on: new project, project brief, set up this project, scaffold, kickoff, start a project, here is what I want to build, generate the structure, readme and folder structure."
user_invocable: true
---

# forge-intake

Two failures live at the start of a project, and they are opposite. One is
building before the brief is understood. The other is interrogating someone for
twenty minutes about things that do not matter yet.

This skill separates the session into two halves with an explicit approval
between them. Before the approval you write nothing but the brief and the
question list. After it you generate everything at once.

**The hard rule: no files are created until the user says the brief is
complete.** Not the README, not the folders, not the plan. The only exceptions
are the two intake files below, which exist to hold the conversation.

---

## Part 1 - Understand, do not build

### 1. Open the intake

```sh
forge kickoff "<project name>"
```

That creates `docs/engineering/000-intake/brief.md` and `intake.md` and nothing
else. Write what the user gave you into `brief.md` verbatim first, their words
not your paraphrase, then your reading of it underneath.

### 2. Extract before asking

Read whatever exists: a pasted brief, an attached document, an existing repo, a
URL. Answer everything you can from it. Every question you ask that the material
already answered costs the user's patience and buys nothing.

If there is existing code, treat the code as the source of truth about what is
and then ask about what should be.

### 3. Fill the checklist

`intake.md` holds the completeness checklist. Mark each line **known**,
**assumed** or **missing**, and for anything known or assumed, write the answer
next to it. The checklist covers:

| Area | What must be settled |
|---|---|
| Outcome | what exists at the end, and how the user will know it works |
| Users | who uses it, and what they are doing when they do |
| Scope | the first version's boundary, and what is explicitly later |
| Data | what is stored, where, and who may read it |
| Integrations | every external service, and whether credentials exist yet |
| Stack | language, framework, database, hosting, and any constraint that forces them |
| Auth | whether there are accounts, and what roles exist |
| Non-functional | expected volume, latency that matters, compliance, budget |
| Deployment | where it runs, who deploys, what must never deploy automatically |
| Done | the definition of done for version one |

### 4. Ask, in one batch

Ask only the **missing** lines that would change what gets built, and ask them
in a single message, numbered, at most seven. For each one, offer your
recommended default so the user can answer "all defaults except 3".

Anything missing that does not change the build becomes an **assumption**, not a
question. Write assumptions down and show them: an assumption the user can see
is cheap to correct, and one you kept to yourself is not.

### 5. Present the completeness report and stop

One block, then stop and wait:

```
BRIEF COMPLETENESS
  known      12 / 18
  assumed     4   (listed below, correct any of them)
  missing     2   (questions 1 and 2 above)

ASSUMPTIONS I WILL BUILD ON
  - <assumption> ... because <reason>

WHAT I WILL GENERATE ON YOUR OK
  README.md, <n> folders, docs/engineering/001-<slug>/ (research, architecture,
  plan, test-plan, review), <n> ADRs, test scaffolding, CLAUDE.md, .gitignore

Say OK to generate, or correct anything first.
```

Then **wait**. Do not generate. Do not start one file "to show the shape". If
the user answers some questions and not others, update the report and ask again.
The approval is a real gate, and it is the user's, not yours.

---

## Part 2 - Generate, on approval only

When the user approves, generate everything in one pass. Announce the phase, do
the work, then report.

### 1. Decisions first, as ADRs

Before scaffolding, record the choices the brief forced:

```sh
forge adr "Stack: <choice>"
forge adr "Data store: <choice>"
```

Each one names the rejected alternatives and why they lost. These are the
decisions a later session would otherwise reopen and quietly change.

### 2. The skeleton

- **`README.md`** written for a competent engineer arriving cold: what this is,
  who it is for, how to run it from a clean clone, how to run the tests, how it
  deploys, and where the engineering artifacts live. No marketing, no features
  that do not exist yet.
- **Folder structure** that the chosen stack's own conventions dictate, not a
  generic one. Create the directories with the files that make them real, and
  explain the layout in the README rather than leaving a `.gitkeep` to be
  guessed at.
- **`CLAUDE.md`** for the project: the commands, the conventions, the traps, and
  the rule that this project runs Forge gates. Short enough to stay read.
- **`.gitignore`**, dependency manifest, and the config files the stack needs.
- **Test scaffolding**: the runner configured, one real test that passes, and
  the command in the README. A project whose test command has never run is a
  project with no test command.
- **`.env.example`** with every variable named and no value filled in.

### 3. The first workstream

```sh
forge new "<first slice of real work>"
```

Fill its `research.md`, `architecture.md`, `plan.md` and `test-plan.md` from the
brief you now understand. This is the execution plan: ordered tasks, each with
its file paths, its test and its verification command. The plan gate opens here,
which is exactly when the real building is allowed to start.

### 4. Prove the skeleton

```sh
forge verify
```

Install, build and test must actually run. If the scaffolding does not pass its
own test, say so and fix it before reporting; a skeleton that does not build is
worse than none, because it looks finished.

### 5. Report

Short: what was created, the ADRs and what they decided, the assumptions still
standing, the first three tasks from the plan, and the verify output. Then ask
whether to start task one.

---

## If the project already exists

Same two halves, different first move. Run `forge audit` and read the code
before asking anything, because most of the checklist is answerable from the
repo. Then present the completeness report with what you found, flag where the
code and the user's description disagree, and wait for approval before writing
any artifact. The disagreements are the most valuable thing you will produce
that day.
