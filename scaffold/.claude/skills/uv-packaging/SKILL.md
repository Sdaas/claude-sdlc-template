---
name: uv-packaging
description: >
  Load this skill for any task involving Python packaging, dependency management,
  pyproject.toml configuration, uv commands, build configuration, linting setup,
  type checking, or test runner configuration. Applies to all projects built from
  this project.
---

# uv + pyproject.toml Packaging Conventions

This skill defines the canonical packaging setup for all Python CLI projects built
using this SDLC. Every configuration here is opinionated and enforced.
Deviations require explicit justification in PLAN.md.

---

## 1. Toolchain

| Tool        | Role                                      | Replaces                        |
|-------------|-------------------------------------------|---------------------------------|
| `uv`        | Package manager, virtualenv, script runner| pip, pip-tools, virtualenv      |
| `hatchling` | Build backend                             | setuptools, flit, poetry-core   |
| `ruff`      | Linter and formatter                      | flake8, isort, black, pyupgrade |
| `mypy`      | Static type checker                       | —                               |
| `pytest`    | Test runner                               | unittest                        |
| `coverage`  | Coverage measurement                      | —                               |

Never introduce `pip`, `setuptools`, `black`, `isort`, or `flake8` directly.
All of these are superseded by the toolchain above.

---

## 2. Canonical pyproject.toml

This is the complete, opinionated default. Every project starts from this.

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "{project-name}"
version = "0.1.0"
description = "{project-description}"
readme = "README.md"
license = { file = "LICENSE" }
requires-python = ">=3.11"
authors = [{ name = "{author-name}", email = "{author-email}" }]
keywords = []
classifiers = [
    "Development Status :: 3 - Alpha",
    "Environment :: Console",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Operating System :: OS Independent",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Programming Language :: Python :: 3.13",
]
dependencies = [
    "click>=8.1",
]

[project.scripts]
{project-name} = "{package}.cli:main"

[project.urls]
Homepage = "https://github.com/{org}/{project-name}"
Repository = "https://github.com/{org}/{project-name}"
Issues = "https://github.com/{org}/{project-name}/issues"

# ---------------------------------------------------------------------------
# uv
# ---------------------------------------------------------------------------

[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "pytest-cov>=5.0",
    "mypy>=1.10",
    "ruff>=0.4",
    "pre-commit>=3.7",
    "bats-core",         # shell test runner — installed via Homebrew, listed here for documentation
]

# ---------------------------------------------------------------------------
# Hatchling
# ---------------------------------------------------------------------------

[tool.hatch.build.targets.wheel]
packages = ["src/{package}"]

# ---------------------------------------------------------------------------
# Ruff — linter and formatter
# ---------------------------------------------------------------------------

[tool.ruff]
target-version = "py311"
line-length = 88
src = ["src", "tests"]

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "B",    # flake8-bugbear
    "C4",   # flake8-comprehensions
    "UP",   # pyupgrade
    "S",    # flake8-bandit (security)
    "T20",  # flake8-print (no print statements)
    "RUF",  # ruff-specific rules
]
ignore = [
    "S101",  # allow assert in tests
]

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = [
    "S101",  # assert is expected in tests
    "S106",  # hardcoded passwords acceptable in test fixtures
]

[tool.ruff.lint.isort]
known-first-party = ["{package}"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
skip-magic-trailing-comma = false

# ---------------------------------------------------------------------------
# mypy — static type checker
# ---------------------------------------------------------------------------

[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_incomplete_defs = true
check_untyped_defs = true
disallow_untyped_decorators = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
show_error_codes = true
files = ["src"]

[[tool.mypy.overrides]]
module = "tests.*"
disallow_untyped_defs = false

# ---------------------------------------------------------------------------
# pytest
# ---------------------------------------------------------------------------

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = [
    "--strict-markers",
    "--strict-config",
    "--cov={package}",
    "--cov-report=term-missing",
    "--cov-report=xml",
    "--cov-fail-under=90",
]
markers = [
    "unit: pure unit tests with no external dependencies",
    "integration: tests that cross boundaries (DB, filesystem, subprocess)",
    "slow: tests that take more than 1 second",
]

# ---------------------------------------------------------------------------
# coverage
# ---------------------------------------------------------------------------

[tool.coverage.run]
source = ["src"]
branch = true
omit = [
    "tests/*",
    "scripts/*",
]

[tool.coverage.report]
show_missing = true
skip_covered = false
fail_under = 90
exclude_lines = [
    "pragma: no cover",
    "if __name__ == .__main__.:",
    "if TYPE_CHECKING:",
    "raise NotImplementedError",
    "@abstractmethod",
]
```

---

## 3. uv Workflow Commands

### Initial Setup

```bash
# Install uv (once, globally)
curl -LsSf https://astral.sh/uv/install.sh | sh

# After cloning — create virtualenv and install all dependencies
uv sync

# Activate the virtualenv
source .venv/bin/activate
```

### Dependency Management

```bash
# Add a runtime dependency
uv add click

# Add a dev dependency
uv add --dev pytest

# Remove a dependency
uv remove {package}

# Sync environment to lockfile (after pulling changes)
uv sync

# Update all dependencies to latest compatible versions
uv lock --upgrade

# Update a single dependency
uv lock --upgrade-package click
```

### Running Tools

```bash
# Run tests
uv run pytest

# Run linter
uv run ruff check .

# Run formatter
uv run ruff format .

# Run type checker
uv run mypy src/

# Run the CLI during development
uv run {project-name} --help
```

### Lockfile

- `uv.lock` is always committed to the repository. No exceptions.
- The lockfile ensures reproducible environments across all machines and CI.
- Never manually edit `uv.lock` — it is managed exclusively by `uv`.
- After any dependency change, commit both `pyproject.toml` and `uv.lock` together
  in the same commit with message: `chore(deps): update {package-name}`

---

## 4. Dependency Pinning Strategy

- Runtime dependencies: specify minimum version with `>=` — e.g. `click>=8.1`
- Dev dependencies: specify minimum version with `>=`
- Exact versions are enforced via `uv.lock`, not via `==` in `pyproject.toml`
- Never pin to exact versions in `pyproject.toml` — this breaks downstream consumers
- `uv.lock` provides the exact pinning for reproducible installs

---

## 5. Build and Distribution

```bash
# Build wheel and sdist
uv build

# Outputs to dist/
# dist/{project_name}-{version}-py3-none-any.whl
# dist/{project_name}-{version}.tar.gz
```

- The wheel is what Homebrew fetches and installs.
- Always build before release — `release.sh` handles this in sequence.
- Do not publish to PyPI unless explicitly decided for a project — Homebrew is the
  primary distribution channel for these CLI tools.

---

## 6. Code Quality Gates (Local)

All of these run via pre-commit hooks. They must all pass before any commit lands.

```bash
# Run all quality checks manually
uv run ruff check .          # lint
uv run ruff format --check . # format check
uv run mypy src/             # type check
uv run pytest                # tests + coverage
```

Ruff replaces all of: `flake8`, `isort`, `black`, `pyupgrade`, `bandit` (partially).
Do not install or suggest any of these tools independently.

---

## 7. Python Version Policy

- Minimum supported version: `3.11`
- Reasons: excellent typing support, `tomllib` in stdlib, `match` statements available,
  `ExceptionGroup` available, performance improvements over 3.10
- Type annotations use the modern syntax available in 3.11+:
  - `list[str]` not `List[str]`
  - `dict[str, int]` not `Dict[str, int]`
  - `str | None` not `Optional[str]`
  - `from __future__ import annotations` is not needed — 3.11 supports this natively

---

## 9. Why `uv run` Is Required (Not Optional)

Claude Code spawns a **fresh shell process for every bash command** it runs.
`source .venv/bin/activate` only affects the shell it runs in — the very
next command starts a new shell with no memory of that activation. Anthropic
has confirmed this is intentional behaviour that will not change.

This means venv activation cannot be relied on to give Claude the right Python.
`uv run` solves this because it resolves the project virtualenv per-command
by reading `pyproject.toml` and the `.venv/` directory — no activation needed,
works correctly in every stateless shell Claude spawns.

### The Three-Layer Enforcement Stack

The template uses three complementary layers to guarantee Claude always uses
the correct Python:

**Layer 1 — CLAUDE.md (instructional)**
Section on Python environment rules tells Claude to always use `uv run`.
Claude reads this at session start.

**Layer 2 — `.claude/hooks/pre_tool_use.py` (hard block)**
A Claude Code PreToolUse hook that intercepts any bare `python`, `python3`,
`pip`, or `pip3` call before it executes, blocks it, and explains the correct
`uv run` alternative. Claude cannot bypass this — it fires before the command
runs.

**Layer 3 — `.claude/settings.json` (environment injection)**
Injects `VIRTUAL_ENV` and the venv's `bin/` into every shell Claude spawns.
Belt-and-suspenders alongside the hook — handles edge cases like subprocess
calls or scripts that check `VIRTUAL_ENV` directly.

### What Claude Must Never Do

```bash
# WRONG — all of these resolve to system Python or bypass the lockfile
python script.py
python3 script.py
pip install requests
pip3 install requests

# CORRECT — always prefix with uv run or use uv add
uv run python script.py
uv run pytest
uv add requests
uv add --dev pytest
```

The hook will block the wrong forms and explain the correct alternative.
Claude should treat a hook block as a reminder, fix the command, and proceed.

---

## 10. What Claude Must Do With This Skill

## 10. What Claude Must Do With This Skill

When working on packaging or configuration tasks:

- Always use `uv run` for every Python command — never bare `python`, `python3`
- Always use `uv add` / `uv remove` — never `pip install` or `pip uninstall`
- Always use `uv sync` to install dependencies — never `pip install -r`
- If the pre_tool_use hook blocks a command, fix the command and proceed —
  treat it as a reminder, not an error
- Always commit `uv.lock` alongside `pyproject.toml` in the same commit
- Never introduce `black`, `isort`, `flake8` — `ruff` covers all of these
- Enforce `requires-python = ">=3.11"` — never lower this without explicit approval
- Enforce modern type annotation syntax — flag `Optional`, `List`, `Dict` imports
  from `typing` as NON-BLOCKING findings in code review
- Enforce `--cov-fail-under=90` — flag coverage drops as BLOCKING findings
- Never suggest `pip install -e .` — use `uv sync` instead
- Flag any `setup.py` or `setup.cfg` as BLOCKING — this template uses `pyproject.toml` only
