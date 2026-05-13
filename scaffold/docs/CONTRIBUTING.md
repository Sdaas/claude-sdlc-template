# Contributing to {project-name}

Thank you for considering a contribution. This document explains the process
for contributing to this project. Please read it before opening an issue or
submitting a pull request.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Report a Bug](#how-to-report-a-bug)
- [How to Request a Feature](#how-to-request-a-feature)
- [Development Workflow](#development-workflow)
- [Commit Message Format](#commit-message-format)
- [Pull Request Process](#pull-request-process)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)

---

## Code of Conduct

Be respectful. Be constructive. Assume good intent.

---

## Getting Started

1. Fork the repository and clone your fork:

```bash
git clone https://github.com/{your-username}/{project-name}.git
cd {project-name}
```

2. Install dependencies:

```bash
# Install uv if you don't have it
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install project dependencies
uv sync
```

3. Install pre-commit hooks:

```bash
uv run pre-commit install
uv run pre-commit install --hook-type pre-push
```

4. Verify your setup:

```bash
uv run pytest
uv run ruff check .
uv run mypy src/
```

Everything should pass before you make any changes.

---

## How to Report a Bug

Open a GitHub issue with the following information:

- **What happened** — the exact behaviour you observed
- **What you expected** — what you expected to happen instead
- **Steps to reproduce** — minimal steps that reliably reproduce the issue
- **Environment** — OS, Python version, `{project-name} --version` output
- **Relevant output** — error messages, stack traces (if any)

Use the bug report issue template if one is available.

**Security vulnerabilities:** Do not open a public issue for security bugs.
Email {author-email} directly with details.

---

## How to Request a Feature

Open a GitHub issue describing:

- **The problem you want to solve** — what are you trying to do?
- **Your proposed solution** — how would you like it to work?
- **Alternatives you considered** — other approaches you thought about
- **Who would benefit** — is this widely useful or specific to your use case?

Features are more likely to be accepted if they are well-scoped, clearly
motivated, and accompanied by a willingness to help implement them.

---

## Development Workflow

This project follows a structured SDLC. All contributions must follow the
same process used for internal development.

### For bug fixes:

1. Open an issue describing the bug (or reference an existing one)
2. Fork and create a branch: `fix/{slug}` (e.g. `fix/config-not-found`)
3. Write a failing test that reproduces the bug — before fixing anything
4. Implement the fix
5. Ensure all tests pass and coverage has not regressed
6. Open a pull request

### For features:

1. Open an issue or discuss in an existing issue before starting work
2. Wait for maintainer acknowledgement — large features without prior
   discussion are likely to be rejected even if well-implemented
3. Fork and create a branch: `feature/{slug}`
4. Follow the TDD workflow — tests before implementation
5. Open a pull request

### Branch naming:

```
feature/{slug}    new features
fix/{slug}        bug fixes
docs/{slug}       documentation only
chore/{slug}      tooling, dependencies, config
```

Slugs should be lowercase and hyphen-separated.

---

## Commit Message Format

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
{type}({scope}): {description}
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `security`

**Examples:**

```
feat(deploy): add --dry-run flag
fix(config): create default config on first run if missing
docs(readme): add installation instructions
test(auth): add parametrized token validation tests
security(input): sanitise file path before read
```

Rules:
- Lowercase, imperative mood ("add" not "added" or "adds")
- No period at the end
- Maximum 72 characters
- One concern per commit

---

## Pull Request Process

1. **Title** — use the same Conventional Commits format as commit messages
2. **Description** — fill in the PR template completely
3. **Tests** — all new code must have tests; coverage must not regress
4. **Passing CI** — all CI checks must pass before review

   The CI pipeline (`ci.yml`) runs automatically on every push:
   - Lint: ruff, mypy, shellcheck, sqlfluff
   - Tests: pytest across Python 3.11, 3.12, and 3.13
   - Coverage: must be at or above 90%
   - Dependency audit: pip-audit

   The security pipeline (`security.yml`) also runs on every PR to main:
   - Secret scan: gitleaks across full git history
   - Python security lint: ruff S ruleset
   - CodeQL static analysis

   Run these locally before pushing:
   ```bash
   uv run ruff check . && uv run ruff format --check .
   uv run mypy src/
   uv run pytest
   uv run pip-audit
   ```

5. **Artifacts** — for STANDARD changes, include relevant decision artifacts
   in `docs/decisions/{slug}/`
6. **Review** — address all review comments before requesting re-review

PRs that don't follow this process will be asked to update before review.

### PR checklist:

```
- [ ] Tests written and passing
- [ ] Coverage at or above threshold (90%)
- [ ] ruff passes: uv run ruff check .
- [ ] mypy passes: uv run mypy src/
- [ ] shellcheck passes (if shell scripts changed)
- [ ] sqlfluff passes (if SQL changed)
- [ ] Commit messages follow Conventional Commits format
- [ ] PR title follows Conventional Commits format
- [ ] CHANGELOG.md updated (for user-facing changes)
```

---

## Code Standards

### Python

- Python 3.11+ required
- All functions must have type annotations
- Use `pathlib.Path` for file paths — not `os.path`
- Use `logging` in `core/` — not `print()`
- Use `click.echo()` in `cli.py` and `commands/` for user output
- No bare `except:` — always catch specific exceptions
- No `assert` in production code — only in tests
- Use f-strings for formatting — not `%` or `.format()`
- No mutable default arguments

### Shell Scripts

- Always `#!/usr/bin/env bash`
- Always `set -euo pipefail`
- All variables quoted: `"${variable}"`
- Must pass `shellcheck` with zero warnings

### SQL

- Parameterised queries only — never string interpolation
- Migrations are append-only — never edit a committed migration
- Must pass `sqlfluff`

---

## Testing Requirements

- Write tests before implementation (TDD)
- Unit tests live in `tests/unit/` — no external dependencies
- Integration tests live in `tests/integration/`
- Shell script tests live in `tests/shell/` using `bats`
- Test names must be descriptive sentences:
  `test_login_fails_with_invalid_token` not `test_login`
- Minimum coverage: 90% — enforced by CI

Run tests:

```bash
uv run pytest              # all tests
uv run pytest -m unit      # unit tests only
uv run pytest -m integration  # integration tests only
bats tests/shell/          # shell tests
```
