---
name: python-cli
description: >
  Load this skill for any task involving Python CLI project structure, conventions,
  entry points, argument parsing, shell scripts, SQL, logging, or test organisation.
  Applies to this project.
---

# Python CLI Project Conventions

This skill defines the structural and coding conventions for all Python CLI projects
built using this SDLC. These are opinionated defaults. Deviations require
explicit justification in PLAN.md.

---

## 1. Project Structure

```
{project-name}/
├── src/
│   └── {package}/
│       ├── __init__.py
│       ├── cli.py              # argument parsing and command registration only
│       ├── commands/           # one file per subcommand
│       │   └── __init__.py
│       └── core/               # business logic — no CLI concerns here
│           └── __init__.py
├── scripts/
│   ├── bootstrap.sh            # project init and rename after cloning template
│   ├── release.sh              # release process driver
│   └── *.sh                    # other project shell scripts
├── sql/
│   ├── migrations/             # versioned sequentially, e.g. 001_init.sql
│   ├── queries/                # named query files called from Python
│   └── seeds/                  # test and dev data
├── tests/
│   ├── unit/                   # pure Python unit tests, no external dependencies
│   ├── integration/            # tests crossing boundaries: DB, filesystem, subprocess
│   ├── shell/                  # bats tests for shell scripts
│   └── conftest.py             # shared fixtures, hooks, pytest configuration
├── docs/
│   └── decisions/              # DESIGN, PLAN, review artifacts — one folder per feature
├── .github/
│   └── workflows/
├── pyproject.toml
├── CLAUDE.md
├── README.md
├── CONTRIBUTING.md
└── DEVELOPER_GUIDE.md
```

The `sql/` directory is optional. Include it only if the project uses SQL.
If a project has no shell scripts beyond `bootstrap.sh` and `release.sh`, the
`scripts/` directory still exists — those two scripts are always present.

---

## 2. CLI Conventions

### Framework

- Use `click` as the CLI framework. No exceptions. Do not use `argparse` directly.
- `click` is composable, well-tested, and works reliably with Homebrew-distributed tools.
- Do not use `typer` — `click` is the standard for this template.

### Separation of Concerns

- `cli.py` handles argument parsing and command registration only. Zero business logic.
- Business logic lives exclusively in `core/`. It must be fully testable without
  invoking the CLI layer.
- `commands/` contains one file per subcommand. No monolithic command files.
- If a command file exceeds 100 lines, it is a signal to split logic into `core/`.

### Entry Point

Declared in `pyproject.toml`:

```toml
[project.scripts]
{project-name} = "{package}.cli:main"
```

### Error Handling

- Surface errors via `click.ClickException` for expected errors with clean messages.
- Use `click.echo(..., err=True)` for warnings and secondary error output to stderr.
- Exit codes are explicit, non-zero for all error conditions, and documented in README.
- No raw Python tracebacks ever reach the user in production.
- Use `if __name__ == "__main__"` guard in `cli.py` for direct invocation during dev.

---

## 3. Shell Script Conventions

### Shebang

Always use:

```bash
#!/usr/bin/env bash
```

Never use `#!/bin/bash`. The `env` form searches `$PATH` for bash, picking up the
environment's bash (e.g. a modern Homebrew-installed bash on macOS) rather than
hardcoding `/bin/bash`, which on macOS is an ancient version 3.2 (2007) due to
licensing constraints. Since these tools are distributed via Homebrew to users with
unknown system configurations, portability is essential.

### Safety Header

Every script must have this as the first line after the shebang:

```bash
set -euo pipefail
```

- `set -e` — exit immediately on error
- `set -u` — treat unset variables as errors
- `set -o pipefail` — catch failures in pipes, not just the last command

### Quality Standards

- All scripts must pass `shellcheck` with zero warnings.
- All scripts must pass `shfmt -d` with zero diff (formatting enforced).
- Inline `shellcheck` suppressions require a comment explaining why.
- Scripts are single-responsibility — one script, one job.
- Scripts must be callable from both CI and local dev without environment-specific changes.
- All variables are quoted: `"${variable}"` not `$variable`.
- Use `$(...)` for command substitution — never backticks.
- Functions are preferred over repeated code blocks.
- No function exceeds 40 lines. Split at 30-40 lines as a forcing function.
- All function-local variables declared with `local`.
- Scripts must be idempotent — safe to run multiple times without side effects.

### Dependency Checks

Every script that relies on external tools must verify they exist before doing any
work. Run a preflight block near the top:

```bash
for cmd in jq curl git; do
    command -v "${cmd}" &>/dev/null || { echo "Required: ${cmd}" >&2; exit 1; }
done
```

Fail fast with a clear message — never let a missing tool cause a confusing mid-script error.

### Temporary File Handling

Use `mktemp` for temporary files and clean up with `trap`:

```bash
TMP=$(mktemp)
trap 'rm -f "${TMP}"' EXIT
```

Never use predictable filenames like `/tmp/myscript.tmp`.

### Arguments and Output

- Every script supports `-h` / `--help` (usage message + exit 0).
- Every script supports `--verbose` (off by default).
- Do not use BLUE as an output colour. It is reserved for Claude Code's own UI
  and causes visual confusion when scripts are run inside a Claude session.
- Always exit with a non-zero code on failure. `set -e` handles most cases, but
  explicit `exit 1` in error paths is clearer and required where `set -e` would
  not fire (e.g. after a conditional that detected an error).
- When invoking other scripts or tools, always check the exit status and surface
  any failure immediately.

### Testing

- All shell scripts are tested with `bats` in `tests/shell/`.
- TDD applies to shell scripts — write the failing bats test first, then the script.
- Bats test files mirror script names: `scripts/release.sh` → `tests/shell/test_release.bats`

---

## 4. SQL Conventions

SQL may appear in three forms in these projects. Each has specific rules.

### Raw Migration Files

- Live in `sql/migrations/`
- Named with zero-padded sequential numbers: `001_init.sql`, `002_add_users.sql`
- Migration files are append-only — never edit a committed migration file
- Each migration file is self-contained and idempotent where possible
- Migration tool: **PENDING DECISION** — candidates are:
  - `alembic` — Python-native, good fit for SQLAlchemy projects, integrates with uv
  - `flyway` — JVM-based, very mature, good for mixed-language teams
  - Raw versioned files — simple, no dependencies, requires process discipline
  - Record the decision in the project's `CLAUDE.md` as a project-specific override

### Query Files

- Live in `sql/queries/`
- Named for their intent: `get_active_users.sql`, `deactivate_account.sql`
- Loaded from Python at runtime — never hardcoded inline except for trivial one-liners
- All query files linted with `sqlfluff`

### Embedded SQL in Python

- Always use parameterised queries. Never string interpolation or f-strings for SQL.

```python
# CORRECT
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))

# NEVER DO THIS
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
```

- Embedded SQL linted via `sqlfluff` Python plugin in CI.

### Testing SQL

- Integration tests run against a real test database — never mock the DB layer.
- Test database is ephemeral — created and destroyed per test session.
- Seeds live in `sql/seeds/` and are loaded by `conftest.py` fixtures.

---

## 5. Logging Conventions

- Use stdlib `logging` exclusively. No third-party logging libraries.
- One logger per module, always:

```python
import logging
logger = logging.getLogger(__name__)
```

- The CLI entry point (`cli.py`) configures log level based on flags:
  - Default: `WARNING`
  - `--verbose`: `INFO`
  - `--debug`: `DEBUG`
- Never use `print()` for application output in `core/`. Always use `logging`.
- `click.echo()` is acceptable in `cli.py` and `commands/` for user-facing output.
- Log levels used consistently:
  - `DEBUG` — internal state, useful for developers debugging
  - `INFO` — user-facing progress and status messages
  - `WARNING` — recoverable unexpected conditions
  - `ERROR` — failures; always include exception info with `exc_info=True`

---

## 6. Testing Conventions

### Python Tests

- Framework: `pytest` exclusively.
- `click.testing.CliRunner` for all CLI-layer tests — never invoke the CLI via
  subprocess in unit tests.
- Core logic tested independently of the CLI layer.
- Test file naming mirrors source structure:
  `src/{package}/core/auth.py` → `tests/unit/core/test_auth.py`
- Fixtures shared across tests live in `tests/conftest.py`.
- Integration tests that hit the filesystem, DB, or subprocesses live in
  `tests/integration/` — never mix with unit tests.

### Shell Tests

- Framework: `bats` (Bash Automated Testing System).
- All bats tests live in `tests/shell/`.
- Bats test files mirror script names.
- Each bats test must set up and tear down its own state — no shared mutable state.

### Coverage

- Minimum coverage threshold enforced in `pyproject.toml`.
- Coverage must not regress on any commit — pre-push hook enforces this.
- Coverage is measured across Python only — shell and SQL have their own test suites.

---

## 7. Bootstrap Script

When cloning the template, the developer runs:

```bash
./scripts/bootstrap.sh <project-name> <package-name>
```

The script:

- Renames all occurrences of `{project-name}` and `{package}` throughout the repo
- Renames the `src/{package}/` directory
- Updates `pyproject.toml` entry points
- Reinitialises git history with a clean initial commit
- Confirms each step with the developer before executing

The bootstrap script itself is tested with bats.

---

## 8. What Claude Must Do With This Skill

When working on any Python CLI project from this template:

- Enforce `src/` layout — never suggest flat package layout
- Enforce `cli.py` purity — flag any business logic found there
- Enforce `click` — reject suggestions to use `argparse` directly
- Enforce `#!/usr/bin/env bash` and `set -euo pipefail` on every shell script
- Enforce parameterised SQL — flag any string interpolation in SQL queries
- Enforce `logging` over `print()` in `core/`
- Flag any deviation from this structure in code review as a BLOCKING finding
