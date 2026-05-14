# {project-name} — Overview

This document explains the development system for {project-name} — what every
file does, why it exists, and how to use it throughout a typical software
development cycle. Read this first before reading anything else.

---

## What This System Is

{project-name} is developed using a structured Claude Code environment for
Python CLI tools. It combines three things into one cohesive system:

**A project scaffold** — the directory structure, packaging configuration,
CI/CD workflows, and tooling that every project needs.

**An SDLC process** — a repeatable, gate-based software development lifecycle
that enforces quality at every step: design before code, tests before
implementation, review before merge.

**A Claude Code operating environment** — skills and commands that teach
Claude Code exactly how to participate in the SDLC: which model to use at
each gate, what artifacts to produce, how to conduct reviews, how to monitor
CI, and how to drive a release.

The core idea: **the right path should be the easy path**. Claude cannot
skip a design review because the commands require it. The pre-commit hook
cannot be satisfied without a test change alongside a source change. The
release script cannot publish without a passing test suite. Quality is
structural, not discretionary.

---

## Repository Map

```
{project-name}/
│
├── CLAUDE.md                    The behavioral contract — loaded automatically
│                                by Claude Code. Defines every rule Claude follows.
├── OVERVIEW.md                  This file.
├── README.md                    Project README — badges, setup, usage.
├── LICENSE                      MIT license.
├── SESSION_STATE.md             Written by /exit, read by /standup.
│                                Ephemeral — in .gitignore. Not project history.
│
├── .claude/
│   ├── commands/                Slash commands — explicit workflow triggers.
│   │   ├── feature.md           /feature "desc" — start a feature
│   │   ├── bugfix.md            /bugfix "desc"  — start a bug fix
│   │   ├── trivial.md           /trivial "desc" — make a trivial change
│   │   ├── standup.md           /standup        — session startup summary
│   │   ├── retrospective.md     /retrospective  — session analysis
│   │   ├── design-review.md     /design-review  — review a design doc
│   │   ├── plan-review.md       /plan-review    — review a plan
│   │   ├── code-review.md       /code-review    — review code + security
│   │   ├── monitor.md           /monitor        — watch CI and remediate
│   │   ├── release.md           /release        — co-pilot the release
│   │   └── exit.md              /exit           — graceful session end
│   │
│   ├── skills/                  Knowledge packages — auto-loaded by Claude
│   │   ├── python-cli/          Project structure, CLI conventions, shell, SQL
│   │   ├── uv-packaging/        uv + pyproject.toml opinionated defaults
│   │   ├── homebrew/            Homebrew formula conventions and audit rules
│   │   ├── tdd/                 TDD process, pytest, bats conventions
│   │   ├── design-doc/          Design doc template and review protocol
│   │   ├── code-review/         Code review checklist and dialogue protocol
│   │   ├── security/            Full security checklist for Python CLIs
│   │   ├── git-workflow/        Branching, commits, PRs, monitoring
│   │   ├── github-actions/      CI/CD workflows, failure diagnosis
│   │   ├── release/             Release process specification
│   │   ├── standup/             Session startup protocol
│   │   ├── retrospective/       Session analysis protocol
│   │   └── workflows/           Gate sequences for feature, bugfix, trivial
│   │
│   ├── settings.json            Injects VIRTUAL_ENV into every Claude shell
│   └── hooks/
│       └── pre_tool_use.py      Blocks bare python/pip — enforces uv run
│
├── hooks/                       Local git hook scripts
│   ├── pre-commit-tdd-check.sh  Blocks commits: src changed without tests
│   └── pre-push-tests.sh        Blocks pushes: full test suite must pass
│
├── scripts/
│   └── release.sh               Interactive 17-step release process
│
├── .github/workflows/
│   ├── ci.yml                   Runs on every PR and push: lint (ruff/mypy/shellcheck/
│   │                            sqlfluff), test (Python 3.11/3.12/3.13), dependency
│   │                            audit (pip-audit), Homebrew formula audit
│   ├── release.yml              Runs on version tags (v*.*.*): validate tag vs
│   │                            pyproject.toml, build wheel+sdist, create GitHub
│   │                            Release, verify Homebrew installation on macOS
│   └── security.yml             Runs weekly (Monday 09:00 UTC) + on every PR:
│                                pip-audit CVE scan (SARIF), gitleaks secret scan,
│                                CodeQL Python analysis, ruff S ruleset, shellcheck
│
├── docs/
│   ├── CONTRIBUTING.md          How to contribute
│   ├── DEVELOPER_GUIDE.md       Full setup and workflow guide
│   ├── SDLC_PROCESS.md          Human-readable SDLC reference
│   ├── decisions/               Decision artifacts per feature/fix
│   └── retrospectives/          Session retrospective artifacts
│
├── src/{package}/               The Python package
│   ├── __init__.py
│   ├── cli.py                   Click CLI entry point
│   ├── commands/                Subcommand modules
│   └── core/                    Business logic
│
├── tests/
│   ├── unit/                    Pure unit tests (no external deps)
│   ├── integration/             Cross-boundary tests
│   └── shell/                   bats shell tests for scripts
│
└── pyproject.toml               Package config, dependencies, tool config
```

---

## The Two Layers: Commands vs Skills

Understanding the difference between commands and skills is important.

**Commands** (`.claude/commands/`) are **verbs** — they trigger a specific
action or workflow. They are invoked explicitly by the developer using a
slash command. They are deterministic: `/feature` always starts the feature
workflow, `/exit` always runs the retrospective then saves state.

**Skills** (`.claude/skills/`) are **knowledge** — they encode how to do
something well. They are loaded automatically by Claude when the task matches
the skill's description. They contain templates, checklists, conventions,
and decision rules. Commands are thin; they delegate to skills for substance.

Example: `/code-review` is the command (the trigger). The `code-review` skill
is the knowledge (what to look for, how to conduct the dialogue, what
constitutes a pass). The command loads the skill and follows it.

### Why `/skills` shows some entries twice

Running `/skills` in Claude Code lists every registered skill and command. Skills
that have a corresponding slash command appear **twice** — once for the skill file
(the knowledge, shown with a higher token count) and once for the command file (the
trigger, shown with a lower token count). This is expected behaviour, not a bug.

For example, `code-review` appears as:
- `code-review · project · ~63 tok` — the `skills/code-review/SKILL.md` knowledge package
- `code-review · project · ~17 tok` — the `commands/code-review.md` trigger file

The same pattern applies to `standup`, `retrospective`, `release`, and any other
skill that has a paired slash command. Skills without a slash command (e.g.,
`python-cli`, `tdd`, `security`) appear only once.

---

## A Typical Development Cycle

Here is a complete example cycle from idea to release, showing exactly which
commands and skills are involved at each step.

---

### Before You Start: Session Startup

Every session begins with `/standup` — automatically, before any task.

Claude reads: recent git log, open artifacts, CI status, uncommitted changes.
Claude presents: what's done, what's in progress, what's blocked, and one
specific suggested first action.

**Skill involved:** `standup`
**Model:** Haiku 4.5 (automatic — no model switch needed)

If the previous session ended without `/exit`, Claude will require you to
run `/retrospective` before accepting any task. This is enforced, not optional.

---

### Step 1: Start a Feature

You have an idea: add a `--dry-run` flag to the deploy command.

**You type:**
```
/feature "add --dry-run flag to the deploy command"
```

Claude immediately:
- States the workflow: STANDARD — Feature Path
- Creates the artifact folder: `docs/decisions/add-dry-run-flag/`
- Announces: "Gate 2: DESIGN. Please switch to Opus 4.6."

**Commands involved:** `feature`
**Skills involved:** `workflows`, `python-cli`

---

### Step 2: Design

Claude writes `DESIGN.md` **section by section** — presenting each section
and waiting for your response before moving to the next. You discuss, push
back, clarify. Claude incorporates your feedback inline.

When all sections are agreed, Claude marks the design `IN REVIEW` and moves
to the design review gate automatically.

**Artifact produced:** `docs/decisions/add-dry-run-flag/DESIGN.md`
**Skills involved:** `design-doc`
**Model:** Opus 4.6

---

### Step 3: Design Review

Claude reads the full design doc, then presents all findings upfront —
numbered and categorised as BLOCKING or NON-BLOCKING.

Claude addresses one finding at a time. You respond. Claude makes the agreed
change, confirms it, and moves to the next. When all blocking findings are
resolved, the design is marked `APPROVED`.

**Artifact produced:** `docs/decisions/add-dry-run-flag/DESIGN_REVIEW.md`
**Commands involved:** `design-review`
**Skills involved:** `design-doc`
**Model:** Opus 4.6

---

### Step 4: Plan

Claude switches to Haiku 4.5 and writes `PLAN.md` — its understanding of
the task, proposed changes file by file, and test strategy.

Claude presents the plan point by point. You respond to each point. The plan
is agreed when all points are confirmed.

**Artifact produced:** `docs/decisions/add-dry-run-flag/PLAN.md`
**Commands involved:** `plan-review`
**Skills involved:** `workflows`
**Model:** Haiku 4.5

---

### Step 5: TDD — Write the Failing Test First

Claude switches to Sonnet 4.6. Before writing a single line of implementation,
Claude answers three questions aloud:

1. What behaviour am I testing?
2. What is the simplest test that would fail right now?
3. What is the minimum implementation that would make it pass?

Claude writes the failing test, runs it, and shows you the red output.
You confirm the failure is correct. Only then does implementation begin.

**Skills involved:** `tdd`
**Model:** Sonnet 4.6

---

### Step 6: Code

Claude implements the minimum code to make the failing test pass — no more.
Shows you the green output. Refactors only after green. Repeats the TDD
cycle for each piece of functionality until the full feature is implemented.

The pre-commit hook enforces TDD mechanically: if you commit `cli.py` without
a corresponding test change, the commit is blocked.

**Skills involved:** `tdd`, `python-cli`
**Model:** Sonnet 4.6

---

### Step 7: Code Review

Claude reads every changed file before presenting any findings. Runs all
tool checks: ruff, mypy, shellcheck, sqlfluff. Presents all findings upfront.
Addresses them one at a time. You respond. Claude fixes, confirms, moves on.

**Commands involved:** `code-review`
**Skills involved:** `code-review`
**Model:** Sonnet 4.6

---

### Step 8: Security Review

As part of the same code review session, Claude applies the full security
checklist. Checks for injection vulnerabilities, secrets, path traversal,
input validation, dependency CVEs. Presents findings by severity.

The security review dialogue is appended to `CODE_REVIEW.md`.

**Artifact produced:** `docs/decisions/add-dry-run-flag/CODE_REVIEW.md`
**Skills involved:** `security`
**Model:** Sonnet 4.6

---

### Step 9: Commit

Claude switches back to Haiku 4.5. Generates commit messages following
Conventional Commits format. Shows you each commit message and staged diff.
You approve. Claude executes the commit. Never the other way around.

**Skills involved:** `git-workflow`
**Model:** Haiku 4.5

---

### Step 10: Push and Monitor CI

Claude pushes the branch and immediately begins monitoring the GitHub Actions
run. You see live status updates. If CI passes, Claude confirms and suggests
opening a PR.

If CI fails, Claude reads the failure log, diagnoses the root cause, presents
a structured diagnosis, and waits for your approval before implementing a fix.
Maximum 3 remediation attempts before Claude stops and escalates to you.

**Commands involved:** `monitor`
**Skills involved:** `github-actions`
**Model:** Sonnet 4.6

---

### Step 11: Merge and Monitor Main

You squash merge the PR. Claude monitors the `main` CI run to completion.
If main CI fails after merge, Claude creates a standalone remediation artifact
and treats it as a new bug fix — the `REPRODUCE` gate fires immediately.

**Skills involved:** `github-actions`, `git-workflow`

---

### Step 12: Retrospective

With the feature merged and main green, Claude automatically runs a
retrospective on the session.

Claude analyses: was the process followed? Was the right model used at each
gate? Did assumptions cause rework? Were communications clear?

Claude presents findings across four dimensions, proposes three top
recommendations, and leaves the Developer Notes section blank for you to fill in.
You review and add notes. Claude commits the retrospective.

**Artifact produced:** `docs/retrospectives/YYYY-MM-DD-add-dry-run-flag.md`
**Commands involved:** `retrospective`
**Skills involved:** `retrospective`
**Model:** Sonnet 4.6

---

### Step 13: End the Session

You type `/exit`.

Claude completes the retrospective (if not already done), writes
`SESSION_STATE.md` to the project root with the current state and a suggested
first action for next session, and tells you it is safe to close.

**Commands involved:** `exit`

---

### Sometime Later: Release

When you have accumulated enough features and fixes on `main`, you decide
to release.

You type `/release`.

Claude presents the pre-release checklist, recommends a version bump based
on Conventional Commits analysis, and waits for your confirmation at each
of the 17 steps in `release.sh`:

- Full test suite run
- Version bump in `pyproject.toml`
- `CHANGELOG.md` update (opened in your editor)
- Git tag created and pushed
- GitHub Actions release workflow triggered and monitored
- sha256 computed from release tarball
- Homebrew resource blocks generated
- Formula updated in tap repo
- `brew audit --strict` run
- Formula committed and pushed to tap
- Homebrew installation verified on macOS
- Post-release summary printed

**Commands involved:** `release`
**Skills involved:** `release`, `homebrew`
**Model:** Sonnet 4.6

---

## The Gate Sequence at a Glance

```
SESSION START
  /standup ──────────────────── Haiku 4.5

FEATURE WORKFLOW
  /feature "desc"
    CLASSIFY ────────────────── Haiku 4.5
    DESIGN ──────────────────── Opus 4.6   → DESIGN.md
    DESIGN REVIEW ───────────── Opus 4.6   → DESIGN_REVIEW.md
    PLAN ────────────────────── Haiku 4.5  → PLAN.md
    PLAN REVIEW ─────────────── Haiku 4.5
    TDD (red first) ─────────── Sonnet 4.6
    CODE ────────────────────── Sonnet 4.6
    CODE REVIEW ─────────────── Sonnet 4.6 → CODE_REVIEW.md (code section)
    SECURITY REVIEW ─────────── Sonnet 4.6 → CODE_REVIEW.md (security section)
    COMMIT ──────────────────── Haiku 4.5
    CI MONITOR ──────────────── Sonnet 4.6
    MERGE + MONITOR MAIN ─────── Sonnet 4.6

BUG FIX WORKFLOW
  /bugfix "desc"
    CLASSIFY ────────────────── Haiku 4.5
    REPRODUCE (failing test) ─── Sonnet 4.6
    CLASSIFY COMPLEXITY ─────── Haiku 4.5
    [if non-trivial: DESIGN + DESIGN REVIEW]
    PLAN + PLAN REVIEW
    TDD → CODE → CODE REVIEW → SECURITY REVIEW → COMMIT → CI MONITOR → MERGE

TRIVIAL WORKFLOW
  /trivial "desc"
    CLASSIFY ────────────────── Haiku 4.5
    SURGICAL CHANGE
    COMMIT ──────────────────── Haiku 4.5
    CI MONITOR

SESSION END
  /exit
    /retrospective ──────────── Sonnet 4.6 → docs/retrospectives/
    SESSION_STATE.md ────────── (local only, not committed)
```

---

## Model Routing Summary

| Task / Gate              | Model      | How                        |
|--------------------------|------------|----------------------------|
| STANDUP, CLASSIFY        | Haiku 4.5  | YAML frontmatter / automatic |
| Commit messages          | Haiku 4.5  | YAML frontmatter / automatic |
| PLAN, PLAN REVIEW        | Haiku 4.5  | Claude announces, you switch |
| CODE, CODE REVIEW        | Sonnet 4.6 | Claude announces, you switch |
| SECURITY REVIEW          | Sonnet 4.6 | Claude announces, you switch |
| CI MONITOR, RETROSPECTIVE| Sonnet 4.6 | Claude announces, you switch |
| DESIGN, DESIGN REVIEW    | Opus 4.6   | Claude announces, you switch |
| Architectural decisions  | Opus 4.6   | Claude announces, you switch |

Claude announces the required model at the start of every interactive gate
and waits for your confirmation before proceeding.

---

## Enforcement Layers

Quality in this project is structural. Here is what enforces each rule:

| Rule                              | Enforced by                          |
|-----------------------------------|--------------------------------------|
| No source changes without tests   | pre-commit TDD hook (blocks commit)  |
| Full test suite passes            | pre-push hook (blocks push)          |
| Lint, format, type check          | pre-commit hooks + ci.yml            |
| No secrets committed              | gitleaks pre-commit + security.yml   |
| No direct commits to main         | pre-commit hook + branch protection  |
| CI must pass before merge         | GitHub branch protection rules       |
| Dependency vulnerabilities        | pip-audit in ci.yml + security.yml (weekly) |
| Python security lint              | ruff S ruleset in security.yml       |
| CodeQL static analysis            | security.yml (weekly + on PRs)       |
| Formula audit before release      | release.sh Step 14 + ci.yml          |
| Test coverage ≥ 90%               | pytest --cov-fail-under in ci.yml    |
| Tag matches pyproject.toml        | release.yml validate-tag job         |
| Homebrew install verified         | release.yml verify job (macOS)       |
| TDD gate in workflow              | CLAUDE.md + workflows skill          |
| Design before code                | CLAUDE.md + workflows skill          |
| Review before merge               | CLAUDE.md + workflows skill          |

---

## Artifacts Produced Per Feature

Every standard feature or bug fix produces and commits this set of artifacts
alongside the code. They are the paper trail of every decision made.

```
docs/decisions/{slug}/
├── DESIGN.md          What we decided to build and why
├── DESIGN_REVIEW.md   The full design review dialogue and resolutions
├── PLAN.md            Claude's understanding, change list, test strategy
└── CODE_REVIEW.md     Code review + security review dialogue and resolutions
                       (includes CI remediation log if CI failed during the work)

docs/retrospectives/
└── YYYY-MM-DD-{slug}.md   Session analysis — process, cost, effectiveness, communication
```

These artifacts serve two purposes. First, they are a record: any developer
(or Claude in a future session) can read `DESIGN.md` to understand why a
decision was made, or `CODE_REVIEW.md` to see what security findings were
found and how they were resolved. Second, they are a learning mechanism:
retrospectives read previous retrospectives to detect recurring patterns,
and escalate structural fixes when the same problem appears repeatedly.

---

## Starting a Session

1. Open Claude Code:
   ```bash
   cd {project-name}
   claude
   ```

2. Claude runs `/standup` automatically — it reads git log, open artifacts,
   and CI status, then presents a summary of what's done, what's in progress,
   and a suggested first action.

3. Begin work using the appropriate slash command:
   ```
   /feature "description"    — new feature
   /bugfix "description"     — bug fix
   /trivial "description"    — small change
   ```

4. End every session with `/exit` to save state and generate the retrospective.

See `docs/DEVELOPER_GUIDE.md` for full setup instructions and troubleshooting.

4. Open Claude Code in the project directory.

5. Type `/standup` — Claude will confirm the project is initialised and
   suggest starting your first feature.

6. Type `/feature "your first feature description"` and the SDLC begins.
