# claude-sdlc-template

A structured development environment for shell-script-based projects, combining
a project scaffold, a gate-based SDLC process, and a Claude Code operating
environment.

This document is the README for the `claude-sdlc-template` repo. It is written
for someone (or Claude) working on the template itself — not for developers using
the template to build a project. That audience should read `scaffold/OVERVIEW.md`.

**Author:** Soumendra Daas + Claude (claude.ai conversation, May 2026)
**Status:** Active development

Read this before touching any file in the repo.

---

## Table of Contents

1. [What This Template Is](#1-what-this-template-is)
2. [Developer Setup](#2-developer-setup)
3. [SDLC for This Repo](#3-sdlc-for-this-repo)
4. [Commands](#4-commands)
5. [Skills](#5-skills)
6. [Hooks](#6-hooks)
7. [File Inventory](#7-file-inventory)
8. [Key Design Decisions](#8-key-design-decisions)
9. [Known Gaps and TODOs](#9-known-gaps-and-todos)
10. [Architecture Decisions That Should Not Be Changed](#10-architecture-decisions-that-should-not-be-changed)
11. [Files That Reference Each Other](#11-files-that-reference-each-other)
12. [Open Questions](#12-open-questions)

---

## 1. What This Template Is

`claude-sdlc-template` is a structured development environment for Python
CLI tools distributed via Homebrew. It combines three things:

**A project scaffold** — directory structure, packaging config, CI/CD
workflows, pre-commit hooks, and tooling that every project needs.

**An SDLC process** — a repeatable, gate-based software development lifecycle
enforced by a combination of Claude Code behavioral rules (CLAUDE.md),
skills (knowledge packages), commands (workflow triggers), pre-commit hooks,
and GitHub Actions. The core idea is that quality is structural, not
discretionary — the right path is the easy path.

**A Claude Code operating environment** — skills and commands that teach
Claude Code exactly how to participate in the SDLC: which model to use at
each gate, what artifacts to produce, how to conduct reviews, and how to
drive a release.

The primary developer is Claude Code. The human developer bootstraps
the project, approves decisions, and triggers gates. Everything else
Claude drives.

---

## 2. Developer Setup

### Prerequisites

| Tool | Required | Install |
|---|---|---|
| `shellcheck` | Yes — pre-commit hook will fail without it | `brew install shellcheck` |
| `shfmt` | Recommended — formatting check skipped if missing | `brew install shfmt` |
| `git` | Yes | pre-installed on macOS |

### Install the pre-commit hook

Run once after cloning:

```bash
bash install-hooks.sh
```

This will:
1. Check that `shellcheck` is installed (fail if missing)
2. Check that `shfmt` is installed (warn if missing)
3. Symlink `hooks/pre-commit.sh` into `.git/hooks/pre-commit`

After installation, every `git commit` will automatically run:
- `shellcheck` on all shell scripts (zero-warning policy)
- `shfmt -d` formatting check (if shfmt installed)
- `bash tests/test_bootstrap.sh` (must pass with 0 failures)
- Referential integrity check (all paths referenced in `.md` files must exist;
  all files in `.claude/` and `hooks/` must be documented in this README)

### Running tests manually

```bash
bash tests/test_bootstrap.sh
```

### Running the full pre-commit suite manually

```bash
bash hooks/pre-commit.sh
```

---

## 3. SDLC for This Repo

This repo uses a gate-based development workflow. Every change starts with
a slash command in Claude Code. Claude drives each gate; the developer approves
decisions and reviews.

### Choosing a workflow

| Change type | Command | When to use |
|---|---|---|
| New feature | `/feature "description"` | Adds new behaviour to bootstrap.sh |
| Bug fix | `/bugfix "description"` | Fixes incorrect behaviour |
| Trivial | `/trivial "description"` | Typo, comment, formatting only — no logic |

### Feature / Bug Fix gate sequence

```
CLASSIFY → DESIGN → PLAN → PLAN REVIEW →
CODE (TDD: write failing test → show red → implement → show green) →
CODE REVIEW → SECURITY REVIEW → COMMIT → MERGE → DONE
```

- **CLASSIFY** (Haiku 4.5): Claude names the change, creates `docs/decisions/{slug}/`
- **DESIGN** (Opus 4.6): Claude writes `DESIGN.md`, presents section by section
- **PLAN** (Haiku 4.5): Claude writes `PLAN.md` with file-by-file changes and test strategy
- **PLAN REVIEW** (Haiku 4.5): Claude reads the plan, surfaces issues before coding
- **CODE** (Sonnet 4.6): TDD cycle — failing test first, then implementation
- **CODE REVIEW** (Sonnet 4.6): shellcheck + shfmt + test suite + code review dialogue
- **SECURITY REVIEW** (Sonnet 4.6): shell security checklist, appended to CODE_REVIEW.md
- **COMMIT** (Haiku 4.5): Conventional Commits message, developer approves before each commit
- **MERGE**: squash merge via PR

### Trivial gate sequence

```
CLASSIFY → SURGICAL CHANGE → COMMIT → DONE
```

No design, no review gates. Claude touches only what was stated.

### Rules

- Never commit directly to `main` — always use a feature/fix branch
- The pre-commit hook blocks commits that fail any check
- TDD is mandatory for STANDARD changes — implementation before test is a BLOCKING finding
- Security review always runs — even for small changes
- Gates can be skipped with explicit developer approval, but the exception is always logged

---

## 4. Commands

Commands are slash commands invoked in Claude Code. They trigger specific workflows
or actions. Thin files that load the appropriate skill and follow it.

| Command | File | Purpose |
|---|---|---|
| `/feature` | `.claude/commands/feature.md` | Full gate-based workflow for new features |
| `/bugfix` | `.claude/commands/bugfix.md` | Gate-based workflow for bug fixes (REPRODUCE gate first) |
| `/trivial` | `.claude/commands/trivial.md` | Lightweight workflow for small, low-risk changes |
| `/code-review` | `.claude/commands/code-review.md` | Shell-focused code + security review (shellcheck, shfmt, tests) |
| `/exit` | `.claude/commands/exit.md` | End-of-session checklist, retrospective, and handoff |
| `/retrospective` | `.claude/commands/retrospective.md` | Post-feature retrospective and lessons captured |

---

## 5. Skills

Skills are knowledge packages loaded by Claude at the appropriate gate. The
substance of every process rule lives in a skill file.

| Skill | File | Purpose |
|---|---|---|
| `workflows` | `.claude/skills/workflows/SKILL.md` | Gate definitions and transition rules for feature/bugfix flows |
| `tdd` | `.claude/skills/tdd/SKILL.md` | Shell TDD cycle: RED (failing assertion) → GREEN → REFACTOR |
| `git-workflow` | `.claude/skills/git-workflow/SKILL.md` | Branch naming, commit message format, PR conventions |
| `security` | `.claude/skills/security/SKILL.md` | Shell script security checklist (quoting, eval, mktemp, etc.) |
| `design-doc` | `.claude/skills/design-doc/SKILL.md` | Template and process for writing design documents |
| `commit` | `.claude/skills/commit/SKILL.md` | Commit orchestration: group changes, generate Conventional Commits messages, require approval before each commit |

---

## 6. Hooks

| File | Purpose |
|---|---|
| `hooks/pre-commit.sh` | Runs full test suite + referential integrity check on every commit. Blocks if any check fails. |
| `install-hooks.sh` | One-time setup: checks shellcheck (required) and shfmt (warn if missing), symlinks pre-commit hook |

---

## 7. File Inventory

### Template repo (maintainer view)

Files at the repo root — never copied to bootstrapped projects.

```
claude-sdlc-template/
│
├── README.md               This file — repo README and maintainer working doc
├── CLAUDE.md               Behavioral contract for Claude Code sessions on this repo
├── LICENSE                 MIT license
├── bootstrap.sh            Interview-driven project bootstrapper — run from repo root
│
├── tests/
│   └── test_bootstrap.sh   Automated test suite for bootstrap.sh
│
├── hooks/
│   ├── pre-commit.sh       Pre-commit hook: shellcheck + shfmt + tests + ref integrity
├── install-hooks.sh        One-time hook installer — run after cloning
│
├── docs/                   Session artifacts (retrospectives, decisions)
│
└── .claude/
    ├── CLAUDE.md            (not present — behavioral rules are in root CLAUDE.md)
    ├── settings.json        Claude Code hook configuration
    ├── commands/
    │   ├── feature.md       /feature command
    │   ├── bugfix.md        /bugfix command
    │   ├── trivial.md       /trivial command
    │   ├── code-review.md   /code-review command
    │   ├── exit.md          /exit command
    │   └── retrospective.md /retrospective command
    └── skills/
        ├── workflows/SKILL.md    Gate sequence definitions
        ├── tdd/SKILL.md          Shell TDD conventions
        ├── git-workflow/SKILL.md Branching and commit conventions
        ├── security/SKILL.md     Shell security checklist
        └── design-doc/SKILL.md   Design document template and review process
```

### Scaffold (project developer view)

Everything in `scaffold/` is copied by `bootstrap.sh` into new projects.
See `scaffold/OVERVIEW.md` for the full inventory of what bootstrapped projects receive.

---

## 8. Key Design Decisions

### 8.1 Commands vs Skills — Why Both

**Commands** (`.claude/commands/`) are verbs — workflow triggers. Thin files
that say "load skill X and follow it."

**Skills** (`.claude/skills/`) are knowledge — domain standards, checklists,
templates, decision rules. The substance lives here.

Commands are the trigger. Skills are the substance. This lets skills evolve
independently of the commands that invoke them.

### 8.2 Model Routing

Each gate uses a specific model, announced by Claude at the gate transition.
Claude cannot switch its own model mid-session — it announces the required model
and waits for the developer to switch in the Claude Code UI.

```
Haiku 4.5   → CLASSIFY, PLAN, COMMIT messages (fast, low-stakes decisions)
Sonnet 4.6  → CODE, CODE REVIEW, SECURITY REVIEW, RETROSPECTIVE
Opus 4.6    → DESIGN, DESIGN REVIEW (architectural decisions)
```

### 8.3 Squash Merge as Default

All PRs are squash-merged into main. One commit per feature on main = clean
history. PR title becomes the commit message — enforcing Conventional Commits.

### 8.4 Bug Fix Workflow — REPRODUCE First

Before any design or planning, Claude writes a failing test that proves the
bug exists. Only after showing the red output does any fix work begin.

### 8.5 SESSION_STATE.md — Ephemeral

`SESSION_STATE.md` is in `.gitignore`. It is a handoff note between sessions,
written by `/exit`. The permanent record lives in `docs/retrospectives/`.

### 8.6 Security Review Is Never Optional

Security review runs on every STANDARD change. The shell security checklist
in `security/SKILL.md` is proportionate, but the gate always runs.

### 8.7 CI Auto-Remediation — 3 Attempts Max

After every push, Claude monitors CI. On failure: diagnose, present to developer,
wait for approval, fix, retry. Hard limit: 3 attempts before mandatory escalation.

### 8.8 Retrospective Pattern Escalation

If the same finding appears unchanged in 3 consecutive retrospectives, Claude
escalates: structural fix required in CLAUDE.md or a skill.

---

## 9. Known Gaps and TODOs

### 9.1 LICENSE Missing from Scaffold

`LICENSE` was not added to `scaffold/`. New bootstrapped projects will have
`license = { file = "LICENSE" }` in pyproject.toml but no actual LICENSE file.

**Fix:** Add `LICENSE` to `scaffold/` and update `bootstrap.sh` to copy it.

### 9.2 `poet` Compatibility with uv Export

`release.sh` Step 12 uses `uv export | poet` — not yet tested.

**Fix:** Verify on first real release. If `poet` fails, write a helper to
generate Homebrew resource blocks from `uv.lock` directly.

### 9.3 Pre-commit Config Uses Mutable Tags

`scaffold/pre-commit-config.yaml.template` uses version tags, not pinned SHAs.

**Fix:** Pin all pre-commit hook versions to commit SHAs.

### 9.4 No CHANGELOG.md Template

`release.sh` Step 6 opens `CHANGELOG.md` but it may not exist on first release.

**Fix:** Add `CHANGELOG.md` starter to `scaffold/` and update `bootstrap.sh`.

### 9.5 `release.sh` Not Tested End-to-End

Steps 12, 13, and 16 of `release.sh` need real-world verification.

### 9.6 GitHub Actions SHA Pins May Be Stale

Workflow files pin actions to SHAs that were accurate at writing time.
Verify before first use:
```bash
gh api repos/actions/checkout/git/refs/tags/v4 --jq '.object.sha'
```

---

## 10. Architecture Decisions That Should Not Be Changed

These were deliberate choices. Do not change without understanding Section 8.

- `uv` as the only package manager — no pip, no poetry, no conda
- `ruff` as the only linter/formatter for Python — no black, isort, flake8
- `click` as the CLI framework — not typer, not argparse
- `pytest` as the test runner — not unittest
- Squash merge as default — not regular merge, not rebase
- `.claude/` committed to the project repo — not in `.gitignore`
- `SESSION_STATE.md` in `.gitignore` — never committed
- Security review on every STANDARD change — never optional
- Max 3 CI remediation attempts — not unlimited
- `shellcheck` zero-warning policy — no suppression without documented reason

---

## 11. Files That Reference Each Other

```
CLAUDE.md
  └── references: all skills (by name), all commands (by slash command)

.claude/skills/workflows/SKILL.md
  └── is the authoritative gate sequence
  └── referenced by: feature.md, bugfix.md, trivial.md

.claude/commands/feature.md, bugfix.md
  └── load: workflows/SKILL.md

.claude/commands/code-review.md
  └── loads: security/SKILL.md

.claude/commands/exit.md
  └── loads: retrospective.md command (via /retrospective)

hooks/pre-commit.sh
  └── runs: tests/test_bootstrap.sh, shellcheck on bootstrap.sh
  └── installed by: install-hooks.sh

bootstrap.sh
  └── copies from: scaffold/.claude.template/, scaffold/.github/workflows/
  └── must stay in sync with: scaffold/ directory structure
```

---

## 12. Open Questions

1. **Migration tool for SQL** — `alembic`, `flyway`, or raw versioned files?
   Recommend deciding per-project; the skill documents this as pending.

2. **`direnv` + `.envrc` for secrets** — mentioned in setup docs as a candidate
   for managing project-level env vars. Not implemented.

3. **Global `~/.claude/CLAUDE.md`** — a global behavioral file across all projects.
   Could hold the `uv run` rule globally. Not implemented.

4. **Standalone `CI_REMEDIATION.md` vs CODE_REVIEW.md** — for main branch
   failures, a standalone artifact is created. The monitor command needs to handle
   two artifact paths. Currently implicit.

5. **`standup` command and `SESSION_STATE.md` timing** — `SESSION_STATE.md` can
   be stale if git operations happen outside Claude Code between sessions. The
   reconciliation logic when SESSION_STATE.md conflicts with git log is unspecified.

---

## Quick Reference — The Development Cycle

```
FEATURE     /feature "description"
            CLASSIFY (Haiku) → DESIGN (Opus) → PLAN (Haiku) → PLAN REVIEW (Haiku) →
            CODE/TDD (Sonnet) → CODE REVIEW (Sonnet) → SECURITY REVIEW (Sonnet) →
            COMMIT (Haiku) → MERGE → DONE

BUG FIX     /bugfix "description"
            CLASSIFY (Haiku) → REPRODUCE (Sonnet, failing test first) →
            CLASSIFY COMPLEXITY → [DESIGN if non-trivial] →
            PLAN → TDD → CODE → CODE REVIEW → SECURITY REVIEW →
            COMMIT → MERGE → DONE

TRIVIAL     /trivial "description"
            CLASSIFY → SURGICAL CHANGE → COMMIT → DONE

SESSION END /exit
            /retrospective → SESSION_STATE.md → "safe to close"
```
