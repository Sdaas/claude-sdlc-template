# claude-sdlc-template — Context and Handoff Document


This document is the README for the `claude-sdlc-template` repo. It is written
for someone (or Claude) working on the template itself — not for developers using
the template to build a project. That audience should read `scaffold/OVERVIEW.md`.

It contains the design decisions and why they were made (Section 3), known gaps
and TODOs (Section 4), a prioritized task list (Section 5), and the dependency
map between files (Section 8). It's a living working document, not a user guide.

It captures every design decision, known gap, and suggested improvement from the
original design conversation. Read this before touching any file in the repo.

**Author:** Soumendra Daas + Claude (claude.ai conversation, May 2026)
**Status:** Initial version complete — ready for Claude Code refinement

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
each gate, what artifacts to produce, how to conduct reviews, how to monitor
CI, and how to drive a release.

The primary developer is Claude Code. The human developer bootstraps
the project, approves decisions, and triggers gates. Everything else
Claude drives.

---

## 2. File Inventory

There are two distinct audiences for this repo:

- **Template maintainers** — developers working on `claude-sdlc-template` itself.
  They interact with the repo root files only.
- **Project developers** — developers who have bootstrapped a new project using
  this template. They never see the template repo; they see only what `bootstrap.sh`
  copied from `scaffold/`.

### 2a. Template repo (maintainer view)

These files live at the repo root and are never copied to bootstrapped projects.

```
claude-sdlc-template/
│
├── CONTEXT.md      This file — repo README and maintainer working doc
├── LICENSE         MIT license for the template repo (Soumendra Daas 2026)
├── docs/           Template-level session artifacts (retrospectives, etc.)
└── scripts/
    └── bootstrap.sh    Interview-driven project bootstrapper (15 steps)
```

`scripts/bootstrap.sh` is the only executable that lives here permanently.
It reads from `scaffold/` and writes into a new project directory.

### 2b. Scaffold (project developer view)

Everything in `scaffold/` is copied by `bootstrap.sh` into bootstrapped projects.
The paths below show how they appear in the destination project (without the
`scaffold/` prefix).

```
{project}/
│
├── CLAUDE.md                        Behavioral contract — 15 sections
├── OVERVIEW.md                      System overview + full dev cycle walkthrough
├── README.md                        Project README (badges, setup, usage)
├── LICENSE                          MIT license — {AUTHOR_NAME} {YEAR} (placeholder)
│
├── .claude/
│   ├── commands/                    Slash commands — workflow triggers
│   │   ├── feature.md               /feature — full standard workflow
│   │   ├── bugfix.md                /bugfix  — reproduce-first workflow
│   │   ├── trivial.md               /trivial — surgical change workflow
│   │   ├── standup.md               /standup — session startup summary
│   │   ├── retrospective.md         /retrospective — session analysis
│   │   ├── design-review.md         /design-review — design review dialogue
│   │   ├── plan-review.md           /plan-review — plan review dialogue
│   │   ├── code-review.md           /code-review — code + security review
│   │   ├── monitor.md               /monitor — CI watch + auto-remediation
│   │   ├── release.md               /release — release process co-pilot
│   │   └── exit.md                  /exit — graceful session end
│   │
│   ├── skills/                      Knowledge packages — auto-loaded by Claude
│   │   ├── python-cli/SKILL.md      Project structure, CLI, shell conventions
│   │   ├── uv-packaging/SKILL.md    uv + pyproject.toml opinionated defaults
│   │   ├── homebrew/SKILL.md        Formula conventions, audit rules, tap setup
│   │   ├── tdd/SKILL.md             TDD process, pytest, bats conventions
│   │   ├── design-doc/SKILL.md      Design doc template and review protocol
│   │   ├── code-review/SKILL.md     Code review checklist and dialogue protocol
│   │   ├── security/SKILL.md        Full security checklist (Python, shell)
│   │   ├── git-workflow/SKILL.md    Branching, commits, PRs, post-push monitoring
│   │   ├── github-actions/SKILL.md  CI/CD workflows, failure diagnosis, remediation
│   │   ├── release/SKILL.md         Release process specification (17 steps)
│   │   ├── standup/SKILL.md         Session startup protocol — what to read, format
│   │   ├── retrospective/SKILL.md   Session analysis — 4 dimensions, pattern detection
│   │   └── workflows/SKILL.md       Gate sequences for feature, bugfix, trivial
│   │
│   ├── settings.json                Injects VIRTUAL_ENV into every Claude shell
│   └── hooks/
│       └── pre_tool_use.py          Blocks bare python/pip — enforces uv run
│
├── .github/
│   └── workflows/
│       ├── ci.yml                   Lint + test (3 Python versions) + audit
│       ├── release.yml              Build + GitHub Release + Homebrew verify
│       └── security.yml             CVE scan + secret scan + CodeQL (weekly)
│
├── hooks/
│   ├── pre-commit-tdd-check.sh      Blocks commits: src/ changed without tests
│   └── pre-push-tests.sh            Blocks pushes: full test suite must pass
│
├── scripts/
│   └── release.sh                   Interactive release process (17 steps)
│
├── docs/
│   ├── CONTRIBUTING.md              Contribution guidelines
│   ├── DEVELOPER_GUIDE.md           Full setup, workflow, troubleshooting guide
│   ├── SDLC_PROCESS.md             Human-readable SDLC reference
│   ├── decisions/                   Decision artifacts (DESIGN, PLAN, CODE_REVIEW)
│   └── retrospectives/              Session retrospective artifacts
│
├── src/{package}/                   Placeholder package structure
├── tests/                           Placeholder test structure
├── pyproject.toml.template          Opinionated Python packaging defaults
├── pre-commit-config.yaml.template  Pre-commit hooks: ruff, mypy, shellcheck, gitleaks
└── gitignore.template               Standard ignore rules + SESSION_STATE.md
```

---

## 3. Key Design Decisions

These are the non-obvious choices made during design. Understand these
before changing anything — each one was deliberate.

### 3.1 Commands vs Skills — Why Both

**Commands** (`.claude/commands/`) are verbs — explicit workflow triggers.
Thin files that mostly say "load skill X and follow it."

**Skills** (`.claude/skills/`) are knowledge — domain standards, checklists,
templates, decision rules. The substance lives here.

Commands are the trigger mechanism. Skills are the substance. This separation
means skills can evolve independently of the commands that invoke them.

### 3.2 Model Routing — Two Mechanisms

There are two completely different routing mechanisms:

**Automatic (YAML frontmatter):** Works for non-interactive, automated tasks.
The `standup` and `retrospective` skills declare `model: claude-haiku-4-5`
and `model: claude-sonnet-4-6` respectively. Claude Code uses these automatically.

**Announced (interactive):** For interactive dialogue gates (design, code review,
etc.), Claude cannot switch its own model mid-session. The approach is:
Claude announces the required model, waits for the human to switch in the
Claude Code UI, then proceeds. This is documented in CLAUDE.md Section 4.

The model routing table:
```
Haiku 4.5   → CLASSIFY, PLAN, STANDUP, COMMIT messages (automatic or announced)
Sonnet 4.6  → CODE, CODE REVIEW, SECURITY REVIEW, RETROSPECTIVE, CI MONITOR
Opus 4.6    → DESIGN, DESIGN REVIEW, architectural decisions
```

### 3.3 The Three-Layer Python Environment Stack

Claude Code spawns a fresh shell per bash command — `source .venv/bin/activate`
does not persist. Three layers enforce correct Python usage:

1. **CLAUDE.md Section 15** — instructs Claude to always use `uv run`
2. **`scaffold/.claude/hooks/pre_tool_use.py`** — hard blocks bare python/pip
3. **`scaffold/.claude/settings.json`** — injects VIRTUAL_ENV as fallback

All three must be present in bootstrapped projects. `bootstrap.sh` installs
them automatically from `scaffold/.claude/`.

### 3.4 Squash Merge as Default

All PRs are squash-merged into main. Reasons:
- One commit per feature on main = clean, readable history
- PR title becomes the commit message (enforces Conventional Commits on PRs)
- `git bisect` works correctly
- Branch slug → artifact folder slug → squash commit message = full traceability

Exception: release commits use regular merge to preserve the release boundary.

### 3.5 Bug Fix Workflow — REPRODUCE First

The bug fix workflow has a unique gate that features don't have: REPRODUCE.
Before any design, planning, or fixing, Claude writes a failing test that
proves the bug exists. Only after showing the red output does work begin.

This serves two purposes: it proves the bug is real, and it becomes the
green condition that proves the fix works.

### 3.6 SESSION_STATE.md — Ephemeral, Not History

`SESSION_STATE.md` is in `.gitignore`. It's a handoff note between sessions,
written by `/exit` and read by `/standup`. It is never committed.

The permanent record lives in `docs/retrospectives/` — these ARE committed.

### 3.7 Artifact Naming — Slug OR Issue Number

Decision artifacts in `docs/decisions/` can be named by feature slug
(`add-dry-run-flag`) or by GitHub issue number (`GH-42`). Both are valid.
The convention is chosen at task start and stated in PLAN.md. This allows
flexibility for issue-tracked vs ad-hoc work.

### 3.8 Security Review Is Never Optional

Security review runs on every STANDARD change — not just changes that "look
security-relevant." This was an explicit decision. The checklist in
`security/SKILL.md` is proportionate to the change, but the gate always runs.

### 3.9 Trivial CI Failure = Possible Misclassification

If a "trivial" change breaks CI, Claude is instructed to flag it as a possible
misclassification rather than silently remediating. The reasoning: a change
that breaks CI is probably not trivial.

### 3.10 CI Auto-Remediation — 3 Attempts Max

After every push, Claude monitors CI and attempts auto-remediation on failure.
Hard limits:
- Never push a retry without explicit developer approval
- Never repeat the same fix — must produce a different diagnosis
- Max 3 attempts before mandatory human escalation
- Log every attempt in CODE_REVIEW.md (feature branch) or CI_REMEDIATION.md (main)

### 3.11 Retrospective Pattern Escalation

If the same finding appears UNCHANGED in 3 consecutive retrospectives, Claude
escalates: "this pattern requires a structural fix in CLAUDE.md or a skill,
not another recommendation." This closes the loop between retrospectives and
actual system improvement.

### 3.12 Gate Exception Protocol

Gates can be skipped, but never silently. The protocol:
1. Claude states which gate and why
2. Developer gives explicit approval with reason
3. Claude logs in PLAN.md under "Gate Exceptions"
4. Claude flags it in the retrospective

### 3.13 Homebrew Distribution Model

The template uses a custom tap (`homebrew-tools` repo) rather than Homebrew
Core. This is the right starting point for new tools — Homebrew Core has a
high bar for acceptance (notable, widely useful). The tap approach works for
any tool and can be promoted to Core later.

`release.sh` handles the full tap update: formula sha256 update, resource
block generation, `brew audit --strict`, commit, push, and post-release
verification by actually installing via Homebrew on macOS.

### 3.14 SQL Migration Tool — Pending Decision

The `python-cli` skill documents SQL conventions but intentionally leaves
the migration tool choice open. Candidates: `alembic` (Python-native),
`flyway` (JVM-based), raw versioned files. This must be decided per-project
and recorded in that project's `CLAUDE.md`.

---

## 4. Known Gaps and TODOs

These are things that are incomplete, missing, or known to need work.

### 4.1 LICENSE Missing from Scaffold

`LICENSE` (MIT) was generated for the template repo root but was not added
to `scaffold/`. New projects bootstrapped from this template will have
`license = { file = "LICENSE" }` in their `pyproject.toml.template` but
no actual `LICENSE` file.

**Fix needed:** Add `LICENSE` to `scaffold/` and have `bootstrap.sh` copy
it during Step 7. Developer should be able to edit the copyright year and
name after bootstrap.

### 4.2 `poet` Compatibility with uv Export

`release.sh` Step 12 uses:
```bash
uv export --no-dev --format requirements-txt > /tmp/requirements.txt
poet -r /tmp/requirements.txt
```

This has not been tested. `poet` was designed for pip-based projects.
It may or may not handle the uv export format correctly. This needs
verification on the first real release.

**Fix needed:** Test on first release. If `poet` fails, write a small
helper script that generates Homebrew resource blocks directly from
`uv.lock` or the requirements export.

### 4.3 Pre-commit Config Uses Mutable Tags

`scaffold/pre-commit-config.yaml.template` uses version tags (e.g. `rev: v0.4.4`)
rather than pinned commit SHAs. This is inconsistent with the GitHub Actions
workflows which use pinned SHAs.

**Fix needed:** Pin all pre-commit hook versions to commit SHAs, or add a
note in DEVELOPER_GUIDE.md to run `uv run pre-commit autoupdate` after
bootstrap and review the changes.

### 4.4 No CHANGELOG.md Template

`release.sh` Step 6 opens `CHANGELOG.md` in `$EDITOR` with a pre-populated
template, but the file may not exist on first release. The script should
create it with the correct initial structure if missing.

**Fix needed:** Add `CHANGELOG.md` to `scaffold/` with the initial structure
(Unreleased section + comparison links pattern), and have `bootstrap.sh`
copy it.

### 4.5 No `src/{package}/cli.py` Starter Content

`bootstrap.sh` creates `src/{package}/cli.py` as an empty file. A new
developer opening the project in Claude Code will need to build the CLI
from scratch with no starting point.

**Fix needed:** Add a minimal but functional `cli.py` starter to the scaffold
with a working `--version` flag (using `importlib.metadata`) and `--help`.
This gives the first `/feature` something real to build on top of.

### 4.6 No Starter Test File

Similarly, `tests/conftest.py` is empty and `tests/unit/` has no files.
The first TDD cycle requires Claude to create the entire test structure.

**Fix needed:** Add `tests/unit/test_cli.py` with a minimal test for
`--version` and `--help` flags. This validates the scaffold works and
gives Claude a pattern to follow for the first real feature.

### 4.7 `bootstrap.sh` Not Tested End-to-End

The bootstrap script was written but not actually run. There are likely
small issues: path assumptions, sed syntax on macOS vs Linux, the
`SCRIPT_DIR`/`TEMPLATE_ROOT` detection for copying `.claude/` files.

**Fix needed:** Run `bootstrap.sh` on a real machine and fix any issues.
Pay particular attention to:
- The `sed -i ''` syntax (macOS requires the empty string argument)
- The scaffold `.claude/` copy logic (SCRIPT_DIR detection)
- Pre-commit running on initial files (Step 15)

### 4.8 `release.sh` Not Tested End-to-End

Similarly, `release.sh` was written but not run. The 17-step sequence
has several areas that need real-world verification:
- Step 12: `uv export | poet` pipeline
- Step 13: `sed` replacement of sha256 in the formula
- Step 16: Homebrew installation verification timing (30s wait may not be enough)

**Fix needed:** Run on first real release and iterate.

### 4.9 GitHub Actions SHA Pins May Be Stale

The workflow files pin actions to specific commit SHAs. These were accurate
at time of writing but may have newer versions available.

```yaml
# Verify these are current before first use:
actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4
astral-sh/setup-uv@f0ec1fc3b38f5e7cd731bb6ce540c88dd8fabb67  # v3
codecov/codecov-action@e28ff129e5465c2c0dcc6f003fc735cb6ae0c673  # v4
```

**Fix needed:** Before setting up a real project's CI, verify these SHAs
are current using:
```bash
gh api repos/actions/checkout/git/refs/tags/v4 --jq '.object.sha'
```

### 4.10 No `CODEOWNERS` File

For multi-developer projects, a `CODEOWNERS` file would enforce review
requirements. Not critical for solo development but worth adding to scaffold.

### 4.11 Standup Skill References `uv run pre-commit` Not `bats`

The standup skill mentions reading CI status but does not reference bats
test results. If a project uses bats extensively, the standup should surface
shell test failures.

### 4.12 `monitor.md` Command Missing `--branch main` Logic

The `/monitor` command detects the current branch automatically, but the
main branch monitoring after a merge is triggered from the workflows skill,
not the monitor command. The handoff between these two is implicit. Should
be made explicit.

---

## 5. Suggested First Tasks for Claude Code

Work through these in order. Each one improves the template's readiness
for real use.

**Priority 1 — Must fix before first real project:**

1. Add `LICENSE` to `scaffold/` and update `bootstrap.sh` to copy it
2. Add `CHANGELOG.md` starter to `scaffold/` and update `bootstrap.sh`
3. Add minimal `cli.py` starter content to `scaffold/src/{package}/cli.py`
4. Add `tests/unit/test_cli.py` starter with `--version` and `--help` tests
5. Run `bootstrap.sh` end-to-end and fix any issues found
6. Verify GitHub Actions SHA pins are current

**Priority 2 — Important but not blocking:**

7. Test `uv export | poet` pipeline on a real project with dependencies
8. Pin pre-commit hook versions to commit SHAs in `pre-commit-config.yaml.template`
9. Add `CODEOWNERS` file to scaffold
10. Add a `Makefile` to the template repo itself with common development tasks
    (e.g. `make zip` to rebuild the distribution zip)

**Priority 3 — Polish:**

11. Add a `--dry-run` flag test to the bootstrap script itself
12. Add validation that `TAP_REPO_PATH` has push access before release starts
13. Consider adding a `docs/adr/` (Architecture Decision Records) directory
    to the scaffold as an alternative to `docs/decisions/` for teams that
    prefer ADR format
14. Add a GitHub issue template to the scaffold for bug reports and feature requests
15. Add a PR template to the scaffold (`.github/pull_request_template.md`)

---

## 6. How to Work With Claude Code on This Repo

### Opening a session

```bash
cd claude-sdlc-template
claude
```

### Giving Claude context

Start the session with:

```
Read CONTEXT.md first. Then read CLAUDE.md, OVERVIEW.md, and the skill
files in .claude/skills/ to understand the system. Then we will work on
[specific task from the TODO list above].
```

### Important: this repo does not use its own SDLC process

The `claude-sdlc-template` repo contains the SDLC process but does not
use it for its own development — there is no DESIGN.md or CODE_REVIEW.md
for the template itself. The template's development is more informal: read
this context doc, make the change, test it, commit.

When the template is mature enough to be bootstrapped from itself, that
would be a fun milestone. But not yet.

### Conventions for Claude Code sessions on this repo

- **Do not run `bootstrap.sh`** in the template repo itself — it's designed
  to run from a clone that will become a new project
- **Test bootstrap.sh** by cloning the template to a temp directory and
  running it there: `cp -r . /tmp/test-bootstrap && cd /tmp/test-bootstrap && ./scripts/bootstrap.sh`
- **Edit files directly** — no need for the full SDLC gate sequence for
  template improvements; a focused review before committing is sufficient
- **Commit messages** should still follow Conventional Commits format

---

## 7. Architecture Decisions That Should Not Be Changed

These were hard-won decisions. Do not change them without fully understanding
the reasoning documented in Section 3.

- `uv` as the only package manager — no pip, no poetry, no conda
- `ruff` as the only linter/formatter — no black, isort, flake8
- `click` as the CLI framework — not typer, not argparse
- `pytest` as the test runner — not unittest
- `bats` for shell tests — not Python subprocess tests
- Squash merge as default — not regular merge, not rebase
- `.claude/` committed to the project repo — not in `.gitignore`
- `SESSION_STATE.md` in `.gitignore` — not committed
- Security review on every STANDARD change — not optional
- Max 3 CI remediation attempts — not unlimited
- Retrospective pattern escalation at 3 occurrences — structural fix required

---

## 8. Files That Reference Each Other (Dependency Map)

Understanding which files depend on which helps avoid breaking things
when editing:

```
CLAUDE.md
  └── references: all skills (by name), all commands (by slash command)

workflows/SKILL.md
  └── is the authoritative gate sequence definition
  └── referenced by: feature.md, bugfix.md, trivial.md commands
  └── must stay in sync with: CLAUDE.md Sections 2-3

uv-packaging/SKILL.md
  └── references: scaffold/.claude/settings.json, scaffold/.claude/hooks/pre_tool_use.py
  └── must stay in sync with: CLAUDE.md Section 15

github-actions/SKILL.md
  └── references: scaffold/.github/workflows/ci.yml, release.yml, security.yml
  └── must stay in sync with: the actual workflow files

release/SKILL.md
  └── references: scripts/release.sh (17-step sequence)
  └── must stay in sync with: release.sh step numbers and logic

standup/SKILL.md
  └── references: SESSION_STATE.md format (written by exit.md command)
  └── must stay in sync with: exit.md command

retrospective/SKILL.md
  └── read by: retrospective.md command, exit.md command (via retrospective.md)

bootstrap.sh
  └── copies from: scaffold/.claude/, scaffold/.github/workflows/
  └── modifies: pyproject.toml (version, dialect), scripts/release.sh (tap path)
  └── must stay in sync with: scaffold/ directory structure
```

---

## 9. Open Questions Deferred From Design

These were raised during design but not resolved. They need decisions.

1. **Migration tool for SQL** — `alembic`, `flyway`, or raw versioned files?
   Recommend deciding per-project; the skill already documents this as pending.

2. **`direnv` + `.envrc` for secrets** — mentioned in the original setup docs
   as a candidate for managing project-level env vars (API keys, etc.) alongside uv.
   Not implemented. Worth adding as an optional section to DEVELOPER_GUIDE.md.

3. **Global `~/.claude/CLAUDE.md`** — a global behavioral file that applies
   across all projects. Not implemented. Could hold the `uv run` rule globally
   so it doesn't need to be in every project's CLAUDE.md.

4. **Standalone `CI_REMEDIATION.md` vs CODE_REVIEW.md** — for main branch
   failures, we create a standalone artifact in `docs/decisions/ci-remediation-{date}-{sha}/`.
   This means the `monitor.md` command needs to handle two different artifact
   paths. Currently implicit — could be made more explicit.

5. **The `standup` command and `SESSION_STATE.md` timing** — `SESSION_STATE.md`
   is written at `/exit` time but could be stale if the developer does git
   operations outside Claude Code between sessions. Standup reads it but
   also reads git log directly. The reconciliation logic when these conflict
   is not specified.

---

## 10. Quick Reference — The Development Cycle

```
SESSION START    /standup (Haiku 4.5, automatic)
                 └── reads: git log, open artifacts, CI status, SESSION_STATE.md
                 └── requires retrospective if last session had no /exit

FEATURE          /feature "description"
                 CLASSIFY (Haiku) → DESIGN (Opus) → DESIGN REVIEW (Opus) →
                 PLAN (Haiku) → PLAN REVIEW (Haiku) → TDD (Sonnet) →
                 CODE (Sonnet) → CODE REVIEW (Sonnet) → SECURITY REVIEW (Sonnet) →
                 COMMIT (Haiku) → CI MONITOR (Sonnet) → MERGE → MONITOR MAIN

BUG FIX          /bugfix "description"
                 CLASSIFY (Haiku) → REPRODUCE (Sonnet, failing test first) →
                 CLASSIFY COMPLEXITY → [design if non-trivial] →
                 PLAN → TDD → CODE → CODE REVIEW → SECURITY REVIEW →
                 COMMIT → CI MONITOR → MERGE → MONITOR MAIN

TRIVIAL          /trivial "description"
                 CLASSIFY → SURGICAL CHANGE → COMMIT → CI MONITOR

RELEASE          /release (Sonnet)
                 pre-release checklist → version selection →
                 ./scripts/release.sh (17 interactive steps)

SESSION END      /exit (Sonnet)
                 /retrospective → SESSION_STATE.md → "safe to close"
```

---

## 11. Contact and Repository

**Author:** Soumendra Daas
**Template repo:** github.com/Sdaas/claude-sdlc-template (or similar)
**Design conversation:** claude.ai, May 2026 (this document summarises it)

This document should be kept up to date as the template evolves.
When a TODO is resolved, move it to a "Resolved" section at the bottom.
When a new design decision is made, add it to Section 3.
