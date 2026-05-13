# SDLC Process Reference — {project-name}

This document is the human-readable reference for the software development
lifecycle used in this project. It describes every gate, every artifact,
and every rule in plain language — without the implementation detail found
in the skills and commands.

Read this to understand *why* the process is structured the way it is.
Read OVERVIEW.md to understand *how* to use it.
Read DEVELOPER_GUIDE.md for setup and practical reference.

---

## Why This Process Exists

Most development quality problems are not caused by lack of skill. They are
caused by skipping steps when under pressure, making assumptions instead of
asking, writing code before understanding the problem, and reviewing code
too quickly to catch real issues.

This process makes the right path the easy path. Every gate has a clear
input, a clear output, and a clear exit condition. Claude enforces the
sequence. The pre-commit hooks enforce the technical standards. The CI
pipeline enforces the quality bars. No single point of willpower stands
between a shortcut and the codebase.

---

## The Two Paths

Every change is classified as one of two types before work begins.

### Trivial

A change that touches no logic, no interfaces, and requires no new tests.
Examples: fixing a typo, updating a docstring, fixing a comment, bumping
a version number that is otherwise managed.

Trivial changes follow a short path:

```
CLASSIFY → SURGICAL CHANGE → COMMIT → CI MONITOR
```

If any doubt exists about whether a change is truly trivial, it is treated
as STANDARD.

### Standard

Everything else. Features, bug fixes, refactors, dependency changes — any
change that could affect behaviour, interfaces, or correctness.

Standard changes follow the full gate sequence described below.

---

## The Gate Sequence

### Feature Path

```
CLASSIFY → DESIGN → DESIGN REVIEW → PLAN → PLAN REVIEW →
TDD → CODE → CODE REVIEW → SECURITY REVIEW →
COMMIT → CI MONITOR → MERGE → MONITOR MAIN
```

### Bug Fix Path

```
CLASSIFY → REPRODUCE →
  [if trivial fix]: PLAN → PLAN REVIEW → TDD → CODE → ...
  [if non-trivial]: DESIGN → DESIGN REVIEW → PLAN → PLAN REVIEW → TDD → CODE → ...
→ CODE REVIEW → SECURITY REVIEW → COMMIT → CI MONITOR → MERGE → MONITOR MAIN
```

The REPRODUCE gate is unique to bug fixes. A failing test that proves the
bug exists must be written before any fix work begins. This test becomes
the green condition that proves the fix works.

---

## Gates in Detail

### CLASSIFY

**Purpose:** Establish shared understanding before any work begins.

Claude states the change in plain language, confirms its classification
(TRIVIAL or STANDARD), and agrees on the artifact naming convention with
the developer.

The artifact folder is created: `docs/decisions/{slug}/`

No work begins until classification is agreed.

### DESIGN

**Purpose:** Decide what to build and why before building it.

Claude writes `DESIGN.md` covering:
- Context and motivation — why does this change exist?
- Goals — what must it achieve?
- Non-goals — what is explicitly out of scope?
- Proposed design — the technical approach
- Alternatives considered — at least one alternative with reasons for rejection
- Interface changes — CLI, function signatures, schema changes
- Test strategy — how the change will be verified
- Security considerations — always required, never left blank

The design is presented section by section. The developer responds to each
section. No section is finalised until the developer agrees with it.

A design is not complete until all required sections are present and
substantive. Open questions must be resolved before the design is approved.

### DESIGN REVIEW

**Purpose:** Challenge the design before committing to it.

Claude reads the entire design document before presenting any findings.
All findings are presented upfront, categorised as BLOCKING or NON-BLOCKING.

Findings are addressed one at a time, BLOCKING first. The developer responds
to each. Claude makes agreed changes and confirms before moving to the next.

A design is APPROVED only when all BLOCKING findings are resolved and the
developer gives explicit sign-off.

The full dialogue is persisted in `DESIGN_REVIEW.md`.

### PLAN

**Purpose:** Make Claude's execution strategy explicit and verifiable.

Claude writes `PLAN.md` covering:
- Its understanding of the task in plain language
- Proposed changes, file by file
- Test strategy — what will be tested and how
- Any gate exceptions being requested

The plan is presented point by point. The developer responds to each point.
An agreed plan means the developer and Claude have the same mental model
of what will happen before any code is touched.

### PLAN REVIEW

**Purpose:** Catch misalignments between the design and the implementation
plan before any code is written.

Same dialogue protocol as DESIGN REVIEW, but lighter — the plan is shorter
and the findings are typically fewer.

A plan with unresolved open questions cannot be agreed.

### TDD (Test-Driven Development)

**Purpose:** Ensure the implementation is driven by verifiable requirements,
not by intuition.

Before writing any implementation code, Claude answers three questions:
1. What behaviour am I testing?
2. What is the simplest test that would fail right now?
3. What is the minimum implementation that would make it pass?

The failing test is written. It is run. The red output is shown.
Only then does implementation begin.

The pre-commit TDD hook enforces this mechanically: a commit that changes
`src/` without changing `tests/` is blocked.

### CODE

**Purpose:** Implement the minimum code required to pass the failing tests.

Claude implements only what is needed to make the failing test pass.
After each test passes, Claude refactors (if needed) and runs the full
suite before moving to the next test.

Coverage must not regress. The pre-push hook and CI enforce this.

### CODE REVIEW

**Purpose:** Catch correctness issues, style violations, and missed
requirements before the code merges.

Claude reads every changed file before presenting any findings. All tool
checks (ruff, mypy, shellcheck, sqlfluff) are run and their output is
included in the review.

The same dialogue protocol applies: all findings upfront, one at a time,
developer responds, Claude fixes, confirms, moves on.

### SECURITY REVIEW

**Purpose:** Catch security vulnerabilities before they merge.

Security review is part of every standard change — it is not a separate
optional step. It runs as the final section of code review.

Claude applies the full security checklist: injection vulnerabilities,
input validation, secrets, path traversal, dependency CVEs, GitHub Actions
security, and more.

The security review dialogue is appended to `CODE_REVIEW.md`.

### COMMIT

**Purpose:** Produce a clean, traceable git history.

Claude generates Conventional Commits-format commit messages. Each message
is shown to the developer for approval before the commit is executed.

One concern per commit. Never `--no-verify` without explicit approval.

### CI MONITOR

**Purpose:** Verify that the change works in CI before it merges.

After every push, Claude monitors the GitHub Actions run to completion
using `gh run watch`. The CI pipeline (`ci.yml`) runs four jobs:

- `lint` — ruff, mypy, shellcheck, sqlfluff
- `test` — pytest across Python 3.11, 3.12, and 3.13 with coverage
- `audit` — pip-audit dependency vulnerability scan
- `formula-audit` — `brew audit --strict` on macOS (if formula exists)

Additionally, the security pipeline (`security.yml`) runs on every PR
to main — secret scan, CodeQL, ruff S ruleset, shellcheck.

On failure, Claude reads the failure log with `gh run view --log-failed`,
diagnoses the root cause, and presents a structured diagnosis before
proposing any fix. The developer must approve every fix and every retry
push. Maximum 3 remediation attempts before escalating.

### MERGE and MONITOR MAIN

**Purpose:** Verify that `main` remains healthy after the merge.

After the PR is squash-merged, Claude monitors the `main` CI run.
If main CI fails, Claude creates a standalone remediation artifact and
treats the failure as a new bug fix — REPRODUCE fires immediately.

---

## The Three Review Principles

Every review in this process — design, plan, code — follows the same
three principles:

**Read everything first.**
Claude reads the complete artifact before presenting any findings. No
findings appear mid-dialogue because Claude hadn't read the whole thing yet.

**Present all findings upfront.**
The developer sees the complete picture before any dialogue begins. No
new findings emerge as surprises after earlier findings are resolved.

**One finding at a time.**
The developer responds to one finding. Claude makes the agreed change.
Claude confirms. Then the next finding. This prevents partial fixes and
ensures each concern is fully resolved before moving on.

---

## Artifacts

Every standard change produces a paper trail of decisions.

```
docs/decisions/{slug}/
├── DESIGN.md          What we decided to build and why
├── DESIGN_REVIEW.md   The full design review dialogue
├── PLAN.md            Claude's execution plan and test strategy
└── CODE_REVIEW.md     Code review + security review + CI remediation
```

These artifacts are committed alongside the code they describe. They answer
the question "why was this done this way?" months or years later. They also
provide continuity between sessions — a new Claude Code session can read
these artifacts to understand exactly where work stands.

Session retrospectives are stored separately:

```
docs/retrospectives/{YYYY-MM-DD}-{slug}.md
```

Retrospectives are the learning mechanism. They detect recurring patterns
across sessions and escalate structural fixes when the same problem appears
repeatedly.

---

## Session Lifecycle

### Starting a session

Every session begins with `/standup`. Claude reads the git log, open
artifacts, CI status, and uncommitted changes. It presents a structured
summary — what's done, what's in progress, what's blocked — and suggests
a specific first action.

No task is accepted until the developer acknowledges the standup.

If the previous session ended without `/exit`, Claude requires a
retrospective before accepting any task.

### Ending a session

Every session ends with `/exit`. Claude runs the retrospective, waits for
the developer to add notes, commits the retrospective artifact, and writes
`SESSION_STATE.md` to the project root.

`SESSION_STATE.md` is ephemeral — it is in `.gitignore` and is written on
every `/exit`, overwritten at the start of every session. It is the handoff
note between sessions, not a project history record.

---

## Gate Exception Protocol

Gates can be skipped in exceptional circumstances. The protocol:

1. Claude states which gate is being requested to skip
2. Claude states why the gate exists and what risk skipping it carries
3. Developer gives explicit approval with a stated reason
4. Claude logs the exception in `PLAN.md` under "Gate Exceptions"
5. Claude proceeds and flags the exception in the retrospective

Gates are never skipped silently. The exception is always logged.

---

## Scope Creep Protocol

If during implementation Claude discovers the change is larger than
originally classified, work stops immediately.

Claude states what was discovered and why it changes the scope.
The developer decides: reclassify and continue, or reclassify and restart.

Scope is never silently expanded. A trivial change that turns out to be
standard restarts at CLASSIFY and follows the full standard path.

---

## Release Process

Releases are always triggered by a human. Claude never releases
autonomously.

The release is driven by `scripts/release.sh`, which walks through
17 steps interactively:

1. Verify prerequisites
2. Show changes since last release
3. Select and confirm version bump
4. Run full test suite (must pass completely)
5. Update version in `pyproject.toml`
6. Update `CHANGELOG.md` (opened in your editor)
7. Commit version bump and changelog
8. Create and push annotated git tag
9. Trigger GitHub Actions release workflow
10. Wait for GitHub release to be created
11. Compute sha256 of release tarball
12. Generate Homebrew resource blocks
13. Update Homebrew formula in tap repo
14. Run `brew audit --strict` on updated formula
15. Commit and push formula update to tap repo
16. Verify Homebrew installation on macOS
17. Post-release summary

Every step pauses for developer confirmation. The script is resumable —
if interrupted, re-running detects the saved state and offers to continue
from where it left off.

A release is not complete until the Homebrew installation is verified on
macOS. A formula that fails `brew install` after release is a release
incident.
