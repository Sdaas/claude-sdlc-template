# Developer Guide — {project-name}

This guide covers everything a developer needs to set up, understand, and
work effectively on this project using Claude Code and the SDLC workflow.

Read OVERVIEW.md first for the conceptual overview. This document is the
practical setup and reference guide.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [GitHub Actions Setup](#github-actions-setup)
- [Homebrew Tap Setup](#homebrew-tap-setup)
- [Claude Code Setup](#claude-code-setup)
- [Daily Workflow](#daily-workflow)
- [Command Reference](#command-reference)
- [Model Selection Guide](#model-selection-guide)
- [Artifact Reference](#artifact-reference)
- [Pre-commit Hooks](#pre-commit-hooks)
- [Running Tests](#running-tests)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Install the following before starting:

### Required

**uv** — Python package manager and virtualenv:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**GitHub CLI** — for CI monitoring and releases:
```bash
brew install gh
gh auth login
```

**Homebrew** — for formula management (macOS only):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**bats-core** — for shell script testing:
```bash
brew install bats-core
```

**shellcheck** — for shell script linting:
```bash
brew install shellcheck
```

**Claude Code** — the AI coding environment:
```bash
npm install -g @anthropic-ai/claude-code
```

### Optional

**poet** — generates Homebrew resource blocks from Python dependencies:
```bash
brew install poet
```

**sqlfluff** — SQL linter (required if project uses SQL):
```bash
uv add --dev sqlfluff
```

---

## Initial Setup

### 1. Clone the repository

```bash
git clone https://github.com/{org}/{project-name}.git
cd {project-name}
uv sync
uv run pre-commit install
uv run pre-commit install --hook-type pre-push
```

### 2. Verify setup

```bash
uv run pytest
uv run ruff check .
uv run mypy src/
```

All three must pass before you make any changes.

### 3. Verify the Claude Code environment

The template includes two files that enforce correct Python usage in Claude Code:

**`.claude/settings.json`** — injects the project virtualenv into every shell
Claude spawns. Claude Code creates a fresh shell per bash command, so
`source .venv/bin/activate` does not persist. This file handles that.

**`.claude/hooks/pre_tool_use.py`** — blocks bare `python`, `python3`, `pip`,
and `pip3` commands before they execute and redirects to the correct `uv run`
equivalent. If you ever see Claude's command blocked by this hook, it means
the hook is working correctly.

Verify both files are in place:

```bash
cat .claude/settings.json              # should show VIRTUAL_ENV injection
cat .claude/hooks/pre_tool_use.py      # should show the hook logic
```

If either file is missing, copy it from the `scaffold/.claude/` directory in
the template repo.

### 3. Verify CLI

```bash
uv run {project-name} --help
uv run {project-name} --version
```

---

## GitHub Actions Setup

The CI/CD pipelines require the following configuration in your GitHub
repository settings.

### Workflow Files

The three workflow files live in `.github/workflows/` and are active
as soon as they are pushed to the repository:

**`ci.yml`** — runs on every push to a feature branch and every PR to main:
- `lint` job: ruff, mypy, shellcheck, sqlfluff
- `test` job: pytest across Python 3.11, 3.12, 3.13 with coverage
- `audit` job: pip-audit dependency vulnerability scan
- `formula-audit` job: `brew audit --strict` on macOS (if formula exists)

**`release.yml`** — runs when `release.sh` pushes a `v*.*.*` tag:
- `validate-tag` job: confirms tag version matches `pyproject.toml`
- `build` job: runs full test suite, builds wheel and sdist
- `release` job: creates GitHub Release with artifacts
- `verify` job: taps and installs via Homebrew on macOS, verifies version

**`security.yml`** — runs every Monday at 09:00 UTC and on every PR to main:
- `dependency-audit` job: pip-audit with SARIF output to GitHub Security tab
- `bandit` job: ruff S ruleset (bandit equivalent)
- `secret-scan` job: gitleaks across full git history
- `codeql` job: CodeQL Python static analysis (security-extended queries)
- `shellcheck` job: shellcheck on all shell scripts
- `sql-lint` job: sqlfluff on all SQL files

### Branch Protection (Settings → Branches → Add rule for `main`)

```
Branch name pattern:              main
Require a pull request:           ✓
  Required approvals:             0 (solo) or 1 (team)
  Dismiss stale reviews:          ✓
Require status checks to pass:    ✓
  Required checks:
    ✓ Lint
    ✓ Test (3.11)
    ✓ Test (3.12)
    ✓ Test (3.13)
    ✓ Dependency Audit
    ✓ Secret Scan
Require branches to be up to date: ✓
Do not allow bypassing:           ✓
Allow force pushes:               ✗
Allow deletions:                  ✗
```

### Repository Variables (Settings → Secrets and variables → Variables)

Used by the release workflow for post-release Homebrew verification:

```
HOMEBREW_TAP_NAME    Your tap name, e.g. myorg/tools
PROJECT_NAME         Your project name, e.g. my-tool
```

To skip post-release Homebrew verification:

```
NO_HOMEBREW_VERIFY   true
```

### GitHub Secrets (Settings → Secrets and variables → Actions)

No custom secrets are required for basic CI. The `GITHUB_TOKEN` is
provided automatically by GitHub Actions.

Optional — for coverage reporting:

```
CODECOV_TOKEN    Your Codecov token (get from codecov.io after connecting repo)
```

Optional — for PyPI publishing (if distributing via PyPI in addition to Homebrew):

```
PYPI_API_TOKEN    Your PyPI token for trusted publishing
```

### Updating Pinned Action SHAs

All third-party actions in the workflow files are pinned to full commit SHAs
rather than mutable version tags. This prevents supply chain attacks.

When upgrading action versions, find the SHA for the new tag:

```bash
gh api repos/actions/checkout/git/refs/tags/v4 --jq '.object.sha'
```

Update the SHA in the workflow file and add the tag as a comment:

```yaml
uses: actions/checkout@{new-sha}  # v4.2.0
```

```
Branch name pattern:              main
Require a pull request:           ✓
  Required approvals:             0 (solo) or 1 (team)
  Dismiss stale reviews:          ✓
Require status checks to pass:    ✓
  Required checks:
    ✓ Lint
    ✓ Test (3.11)
    ✓ Test (3.12)
    ✓ Test (3.13)
    ✓ Dependency Audit
    ✓ Secret Scan
Require branches to be up to date: ✓
Do not allow bypassing:           ✓
Allow force pushes:               ✗
Allow deletions:                  ✗
```

### GitHub Secrets (Settings → Secrets and variables → Actions)

No custom secrets are required for basic CI. The `GITHUB_TOKEN` is
provided automatically by GitHub Actions.

If you plan to publish to PyPI in addition to Homebrew, add:

```
PYPI_API_TOKEN    Your PyPI token for trusted publishing
```

### Codecov (optional — for coverage badges)

Sign up at [codecov.io](https://codecov.io) and connect your repository.
No additional secrets needed — the Codecov Action uses the `GITHUB_TOKEN`.

---

## Homebrew Tap Setup

The tap repository hosts the Homebrew formula for your CLI tool. It is
separate from the main project repository.

### 1. Create the tap repository

Create a new GitHub repository named `homebrew-tools` (or your preferred
tap name) under your organisation or personal account.

The repository must be public for `brew tap` to work without authentication.

```
GitHub repository name: homebrew-tools
Visibility:             Public
Description:            Homebrew tap for {org} tools
```

### 2. Initialise the tap repository

```bash
git clone https://github.com/{org}/homebrew-tools.git ~/homebrew-tools
cd ~/homebrew-tools

# Create the Formula directory
mkdir -p Formula

# Create a placeholder formula
cat > Formula/{project-name}.rb << 'EOF'
class {ProjectName} < Formula
  desc "{project-description}"
  homepage "https://github.com/{org}/{project-name}"
  url "https://github.com/{org}/{project-name}/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER — update with real sha256 on first release"
  license "MIT"

  depends_on "python@3.11"

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/{project-name} --version")
    assert_match "Usage:", shell_output("#{bin}/{project-name} --help")
  end
end
EOF

git add Formula/{project-name}.rb
git commit -m "feat({project-name}): add initial formula placeholder"
git push origin main
```

### 3. Configure local tap path

The bootstrap script sets this automatically. To set it manually, configure
the environment variable in your shell profile:

```bash
# ~/.zshrc or ~/.bashrc
export TAP_REPO_PATH="${HOME}/homebrew-tools"
```

Or set it per-invocation when running `release.sh`:

```bash
TAP_REPO_PATH=/path/to/homebrew-tools ./scripts/release.sh
```

### 4. Configure SSH access for tap repo pushes

`release.sh` pushes commits to the tap repo automatically. Ensure SSH
is configured for your GitHub account:

```bash
# Check if SSH key exists
ls ~/.ssh/id_ed25519.pub

# If not, generate one
ssh-keygen -t ed25519 -C "{author-email}"

# Add to GitHub: Settings → SSH and GPG keys → New SSH key
cat ~/.ssh/id_ed25519.pub
```

Change your tap repo remote to use SSH:

```bash
cd ~/homebrew-tools
git remote set-url origin git@github.com:{org}/homebrew-tools.git
```

Verify access:

```bash
ssh -T git@github.com
# Should output: Hi {username}! You've successfully authenticated...
```

### 5. Tap your own tap for testing

```bash
brew tap {org}/tools
brew install {project-name}
{project-name} --version
brew test {project-name}
brew uninstall {project-name}
```

---

## Claude Code Setup

### Starting Claude Code

```bash
# Navigate to the project directory
cd {project-name}

# Start Claude Code
claude
```

Claude Code automatically reads `CLAUDE.md` on startup, loading all
behavioral rules and process requirements.

### Model Configuration

Model routing is explained fully in `CLAUDE.md` Section 4. In summary:

- **Haiku 4.5** — automated tasks (standup, commit messages, classify, plan)
- **Sonnet 4.6** — implementation, code review, security review, CI monitoring
- **Opus 4.6** — design, design review, architectural decisions

Claude announces the required model at the start of each interactive gate.
Switch the model in the Claude Code model selector before confirming.

### Skills and Commands

Skills load automatically when Claude identifies a relevant task.
Commands are triggered explicitly with slash commands.

See OVERVIEW.md for the complete command and skill reference.

---

## Daily Workflow

### Starting a session

```
claude                    # open Claude Code
/standup                  # automatic — Claude presents session state
```

Claude will tell you where you left off and suggest the first action.

### Starting a feature

```
/feature "description of what you want to build"
```

Claude will confirm the workflow, create the artifact folder, and walk you
through DESIGN → DESIGN REVIEW → PLAN → TDD → CODE → CODE REVIEW →
SECURITY REVIEW → COMMIT.

### Fixing a bug

```
/bugfix "description of the bug"
```

Claude will write a failing test reproducing the bug before any fix work
begins.

### Making a trivial change

```
/trivial "fix typo in README"
```

Claude will make only the stated change and nothing else.

### Ending a session

```
/exit
```

Claude will run the retrospective, save session state, and tell you when
it is safe to close. Never close Claude Code without running `/exit` —
the next session's standup will require a retrospective if you do.

### Releasing

```
/release
```

Claude will present the pre-release checklist and co-pilot you through
`release.sh` interactively.

---

## Command Reference

| Command            | When to use                                   | Model      |
|--------------------|-----------------------------------------------|------------|
| `/standup`         | Start of every session (automatic)            | Haiku 4.5  |
| `/feature "desc"`  | Start implementing a new feature              | varies     |
| `/bugfix "desc"`   | Start fixing a bug                            | varies     |
| `/trivial "desc"`  | Make a trivial change (typo, docstring, etc.) | Haiku 4.5  |
| `/design-review`   | Review the current DESIGN.md                  | Opus 4.6   |
| `/plan-review`     | Review the current PLAN.md                    | Haiku 4.5  |
| `/code-review`     | Review code + security for current changes    | Sonnet 4.6 |
| `/monitor`         | Watch CI and auto-remediate failures          | Sonnet 4.6 |
| `/retrospective`   | Analyse the current session                   | Sonnet 4.6 |
| `/release`         | Co-pilot the release process                  | Sonnet 4.6 |
| `/exit`            | End session gracefully                        | Sonnet 4.6 |

---

## Model Selection Guide

Switch models in the Claude Code model selector (top of the interface).

| Task                                   | Model      |
|----------------------------------------|------------|
| Standup, classification, planning      | Haiku 4.5  |
| Commit message generation              | Haiku 4.5  |
| Writing and reviewing code             | Sonnet 4.6 |
| Security review, CI monitoring         | Sonnet 4.6 |
| Session retrospective                  | Sonnet 4.6 |
| Writing and reviewing design docs      | Opus 4.6   |
| Architectural decisions                | Opus 4.6   |

Claude announces the required model at each gate transition and waits for
confirmation before proceeding. You may override the model at any time —
using a more capable model than specified is always acceptable.

---

## Artifact Reference

Every STANDARD change produces these artifacts in `docs/decisions/{slug}/`:

| File                 | Written when         | Contains                                    |
|----------------------|----------------------|---------------------------------------------|
| `DESIGN.md`          | DESIGN gate          | What, why, alternatives, interface changes  |
| `DESIGN_REVIEW.md`   | DESIGN REVIEW gate   | Full review dialogue and resolutions        |
| `PLAN.md`            | PLAN gate            | Claude's understanding, change list, tests  |
| `CODE_REVIEW.md`     | CODE REVIEW gate     | Code + security review dialogue             |

Session retrospectives are stored in `docs/retrospectives/`:

```
docs/retrospectives/{YYYY-MM-DD}-{slug}.md
```

Session state (ephemeral, not committed):

```
SESSION_STATE.md    # written by /exit, read by /standup
```

---

## Pre-commit Hooks

Hooks run automatically on `git commit` and `git push`.

### Commit hooks

| Hook                  | What it checks                           | Blocks on         |
|-----------------------|------------------------------------------|-------------------|
| ruff                  | Lint and auto-fix                        | unfixable errors  |
| ruff-format           | Format auto-fix                          | format violations |
| mypy                  | Static type checking                     | type errors       |
| shellcheck            | Shell script linting                     | any warning       |
| sqlfluff              | SQL linting and auto-fix                 | lint errors       |
| gitleaks              | Secret detection                         | any secret found  |
| TDD check             | src/ changed without tests               | missing tests     |
| pre-commit-hooks      | Trailing whitespace, merge conflicts,    | various           |
|                       | large files, line endings, YAML/TOML     |                   |
| no-commit-to-branch   | Direct commits to main                   | always            |

### Push hooks

| Hook                  | What it checks                           | Blocks on         |
|-----------------------|------------------------------------------|-------------------|
| Full test suite       | All pytest tests + coverage threshold    | any failure       |

### Bypassing hooks

Do not bypass hooks without explicit approval from the session's Claude
Code co-pilot, logged in the session.

If bypass is absolutely necessary:

```bash
git commit --no-verify -m "chore: bypass hooks — reason: ..."
```

Bypasses are flagged as findings in code review.

### Updating hooks

```bash
uv run pre-commit autoupdate
git add .pre-commit-config.yaml
git commit -m "chore(pre-commit): update hook versions"
```

---

## Running Tests

### Python tests

```bash
uv run pytest                          # all tests
uv run pytest -m unit                  # unit tests only
uv run pytest -m integration           # integration tests only
uv run pytest -m "not slow"            # skip slow tests
uv run pytest tests/unit/core/         # specific directory
uv run pytest -k "test_login"          # tests matching pattern
uv run pytest -v                       # verbose output
uv run pytest --no-cov                 # skip coverage (faster)
```

### Shell tests

```bash
bats tests/shell/                      # all shell tests
bats tests/shell/test_release.bats     # specific file
bats --verbose-run tests/shell/        # verbose output
```

### Coverage

```bash
uv run pytest --cov --cov-report=html  # generate HTML report
open htmlcov/index.html                 # view in browser
```

Coverage must be at or above 90%. The CI and pre-push hook enforce this.

### SQL lint

```bash
uv run sqlfluff lint sql/              # lint all SQL
uv run sqlfluff fix sql/               # auto-fix where possible
```

---

## Troubleshooting

### `uv sync` fails

```bash
# Clear the virtualenv and retry
rm -rf .venv
uv sync
```

### Pre-commit hooks not running

```bash
# Reinstall hooks
uv run pre-commit install
uv run pre-commit install --hook-type pre-push

# Run all hooks manually
uv run pre-commit run --all-files
```

### mypy strict mode errors on existing code

```bash
# Check which files have errors
uv run mypy src/ --error-summary

# Common fixes:
# - Add return type annotations: def func() -> None:
# - Use X | None instead of Optional[X]
# - Use list[str] instead of List[str]
```

### `gh` command not found or not authenticated

```bash
brew install gh
gh auth login    # follow the prompts
gh auth status   # verify
```

### `brew audit` fails on formula

Common fixes:

```bash
# desc starts with article or has period
desc "A tool..."    # wrong — remove "A"
desc "My tool."     # wrong — remove period

# sha256 is wrong
curl -sL {tarball-url} | shasum -a 256

# test block is too weak
# must exercise the actual binary, not just check it exists
```

### `release.sh` interrupted mid-run

The script saves state to `/tmp/.release-state-{project-name}`.
Re-run the script — it will detect the interrupted state and offer to resume.

```bash
./scripts/release.sh
# Script asks: "Resume from step N?"
```

To start fresh:

```bash
rm /tmp/.release-state-{project-name}
./scripts/release.sh
```

### Claude's command was blocked by the pre_tool_use hook

This is the hook working correctly. It means Claude tried to use bare `python`
or `pip` instead of `uv run`. The hook blocks it and shows the correct command.

If you see this repeatedly, check that `CLAUDE.md` Section 15 is present — it
instructs Claude on the correct commands. The hook is the enforcement layer;
`CLAUDE.md` is the instructional layer. Both need to be in place.

To test the hook manually:

```bash
# Simulate what Claude Code does — should be blocked
echo '{"tool_name": "Bash", "tool_input": {"command": "python --version"}}' \
  | python3 .claude/hooks/pre_tool_use.py
# Expected output: {"decision": "block", "reason": "..."}

# Correct command — should be approved
echo '{"tool_name": "Bash", "tool_input": {"command": "uv run python --version"}}' \
  | python3 .claude/hooks/pre_tool_use.py
# Expected output: {"decision": "approve"}
```

### Claude Code using wrong model

Claude announces the required model at each gate transition. If the wrong
model is active, switch it in the model selector before confirming to proceed.

You can override at any time — just state it explicitly:
"Use Sonnet for this even though Opus is recommended."
Claude will log the override.

### SESSION_STATE.md missing after session close

`SESSION_STATE.md` is only written by `/exit`. If you closed Claude Code
without running `/exit`, the file will not exist. The next standup will
detect this and require `/retrospective` before accepting any task.

This is expected behaviour — run `/retrospective` and then proceed normally.
