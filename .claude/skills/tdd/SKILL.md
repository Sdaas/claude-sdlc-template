---
name: tdd
description: >
  Load this skill for any task involving test-driven development, writing tests,
  pytest conventions, bats tests for shell scripts, test fixtures, coverage,
  mocking, or the TDD cycle. Applies to all projects built from
  claude-sdlc-template. This skill governs how Claude approaches every
  non-trivial code change.
---

# TDD Conventions and Process

This skill defines the test-driven development process and testing conventions
for all projects built from claude-sdlc-template. TDD is not optional. It is
the only permitted development method for STANDARD changes.

---

## 1. The TDD Cycle

Every STANDARD change follows this cycle without exception:

```
RED   → Write a failing test that describes the desired behaviour
RED   → Run the test. Show the failure output. Do not proceed without seeing red.
GREEN → Write the minimum code to make the test pass. Nothing more.
GREEN → Run the test. Show the passing output.
REFACTOR → Clean up the implementation. Tests must still pass after refactor.
REFACTOR → Run the full test suite. Show the output.
```

### Non-Negotiable Rules

- Never write implementation code before a failing test exists.
- Never skip showing the red output — paste the actual pytest/bats failure.
- Never write more implementation than the failing test requires.
- Never refactor while red — get to green first, then clean up.
- Never mark a feature complete until the full test suite passes.
- Coverage must not regress. The pre-push hook enforces this mechanically.

### The Discipline Check

Before writing any implementation, Claude must answer these three questions
explicitly in the session:

```
1. What behaviour am I testing?
2. What is the simplest test that would fail right now?
3. What is the minimum implementation that would make it pass?
```

If Claude cannot answer all three, it must stop and ask for clarification.

---

## 2. Python Test Structure

### Directory Layout

```
tests/
├── unit/               # fast, no external dependencies
│   ├── core/           # mirrors src/{package}/core/
│   ├── commands/       # mirrors src/{package}/commands/
│   └── test_cli.py     # CLI layer tests using CliRunner
├── integration/        # slower, crosses boundaries
│   ├── test_db.py      # database integration tests
│   ├── test_filesystem.py
│   └── test_subprocess.py
├── shell/              # bats tests for shell scripts
│   └── test_*.bats
└── conftest.py         # shared fixtures, hooks, session setup
```

### Test File Naming

Mirror the source structure exactly:

```
src/{package}/core/auth.py          → tests/unit/core/test_auth.py
src/{package}/commands/login.py     → tests/unit/commands/test_login.py
src/{package}/cli.py                → tests/unit/test_cli.py
scripts/release.sh                  → tests/shell/test_release.bats
```

### Test Function Naming

Use descriptive names that read as sentences:

```python
# CORRECT — readable, describes behaviour
def test_login_returns_error_when_credentials_invalid():
def test_config_file_created_on_first_run():
def test_version_flag_prints_current_version():

# WRONG — vague, non-descriptive
def test_login():
def test_config():
def test_version():
```

---

## 3. pytest Conventions

### Basic Test Structure

```python
import pytest
from click.testing import CliRunner
from {package}.cli import main


class TestLoginCommand:
    """Tests for the login subcommand."""

    def test_login_succeeds_with_valid_credentials(self) -> None:
        runner = CliRunner()
        result = runner.invoke(main, ["login", "--user", "alice", "--token", "valid"])
        assert result.exit_code == 0
        assert "Logged in" in result.output

    def test_login_fails_with_invalid_token(self) -> None:
        runner = CliRunner()
        result = runner.invoke(main, ["login", "--user", "alice", "--token", "bad"])
        assert result.exit_code != 0
        assert "Invalid token" in result.output
```

### Fixtures

Shared fixtures live in `tests/conftest.py`. Test-local fixtures stay in the
test file. Never duplicate fixture definitions across files.

```python
# tests/conftest.py
import pytest
from pathlib import Path
from click.testing import CliRunner


@pytest.fixture
def runner() -> CliRunner:
    """Provide a Click test runner."""
    return CliRunner()


@pytest.fixture
def tmp_config(tmp_path: Path) -> Path:
    """Provide a temporary config directory."""
    config_dir = tmp_path / ".config" / "{package}"
    config_dir.mkdir(parents=True)
    return config_dir


@pytest.fixture(scope="session")
def test_db():
    """Provide an ephemeral test database for the session."""
    # Setup
    db = create_test_database()
    load_seeds(db)
    yield db
    # Teardown
    db.drop()
```

### Markers

Use markers to categorise tests. Declared in `pyproject.toml`:

```python
@pytest.mark.unit
def test_pure_logic():
    ...

@pytest.mark.integration
def test_hits_database():
    ...

@pytest.mark.slow
def test_takes_a_while():
    ...
```

Run subsets:

```bash
uv run pytest -m unit          # fast feedback loop
uv run pytest -m integration   # boundary tests
uv run pytest -m "not slow"    # skip slow tests locally
```

### Parametrize

Use `pytest.mark.parametrize` for input variation — never duplicate test
functions for similar inputs:

```python
@pytest.mark.parametrize("token,expected_exit", [
    ("valid_token", 0),
    ("",            1),
    ("expired",     1),
    ("malformed",   1),
])
def test_login_exit_codes(token: str, expected_exit: int) -> None:
    runner = CliRunner()
    result = runner.invoke(main, ["login", "--token", token])
    assert result.exit_code == expected_exit
```

### Mocking

Use `unittest.mock` from stdlib. No third-party mocking libraries.

```python
from unittest.mock import MagicMock, patch


def test_api_call_retried_on_timeout() -> None:
    with patch("{package}.core.client.requests.get") as mock_get:
        mock_get.side_effect = [TimeoutError(), MagicMock(status_code=200)]
        result = fetch_with_retry("https://api.example.com")
        assert mock_get.call_count == 2
        assert result is not None
```

Mocking rules:

- Mock at the boundary — patch the thing your code calls, not the internals of
  external libraries.
- Never mock core business logic to make CLI tests pass — test the seam.
- Never mock the database in integration tests — use a real test database.

### Exception Testing

```python
def test_raises_value_error_on_empty_input() -> None:
    with pytest.raises(ValueError, match="Input cannot be empty"):
        parse_config("")
```

Always assert the exception message with `match=` — do not test the exception
type alone.

---

## 4. CLI Layer Testing

Always use `click.testing.CliRunner`. Never invoke the CLI via subprocess in unit tests.

```python
from click.testing import CliRunner
from {package}.cli import main


def test_help_flag_exits_cleanly() -> None:
    runner = CliRunner()
    result = runner.invoke(main, ["--help"])
    assert result.exit_code == 0
    assert "Usage:" in result.output


def test_version_flag_shows_version() -> None:
    runner = CliRunner()
    result = runner.invoke(main, ["--version"])
    assert result.exit_code == 0
    # Version string should match pyproject.toml
    from importlib.metadata import version
    assert version("{package}") in result.output


def test_command_with_file_input(tmp_path: Path) -> None:
    input_file = tmp_path / "input.txt"
    input_file.write_text("test content")
    runner = CliRunner()
    with runner.isolated_filesystem(temp_dir=tmp_path):
        result = runner.invoke(main, ["process", str(input_file)])
    assert result.exit_code == 0
```

Use `runner.isolated_filesystem()` for any test that touches the filesystem.

---

## 5. Shell Script Testing with bats

### bats Test Structure

```bash
#!/usr/bin/env bats

# tests/shell/test_release.bats

setup() {
    # Runs before each test
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
    cp scripts/release.sh "${TEST_DIR}/release.sh"
}

teardown() {
    # Runs after each test — always clean up
    rm -rf "${TEST_DIR}"
}

@test "release.sh exits non-zero when version argument missing" {
    run bash "${TEST_DIR}/release.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "release.sh validates semver format" {
    run bash "${TEST_DIR}/release.sh" "not-a-version"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid version"* ]]
}

@test "release.sh succeeds with valid semver" {
    run bash "${TEST_DIR}/release.sh" "1.2.3" "--dry-run"
    [ "$status" -eq 0 ]
}
```

### bats Rules

- Every bats test file must have `setup()` and `teardown()` functions.
- `teardown()` must clean up all temporary state — even when tests fail.
- Use `run` before any command you want to capture output from.
- Assert `$status` explicitly — never assume exit code.
- Use `[[ "$output" == *"pattern"* ]]` for output assertions.
- Test both happy path and failure modes for every script.
- TDD applies — write the failing bats test before writing the script.

### Running bats Tests

```bash
# Run all shell tests
bats tests/shell/

# Run a specific test file
bats tests/shell/test_release.bats

# Run with verbose output
bats --verbose-run tests/shell/
```

---

## 6. Integration Test Conventions

Integration tests cross real boundaries. They are slower and have external
dependencies. They live exclusively in `tests/integration/`.

```python
# tests/integration/test_db.py
import pytest
from {package}.core.repository import UserRepository


@pytest.mark.integration
class TestUserRepository:
    """Integration tests for UserRepository against a real test database."""

    def test_create_user_persists_to_db(self, test_db) -> None:
        repo = UserRepository(test_db)
        user = repo.create(username="alice", email="alice@example.com")
        assert user.id is not None
        fetched = repo.get_by_id(user.id)
        assert fetched.username == "alice"

    def test_get_nonexistent_user_returns_none(self, test_db) -> None:
        repo = UserRepository(test_db)
        result = repo.get_by_id(99999)
        assert result is None
```

Integration test rules:

- Use a real test database — never mock the DB layer.
- Test database is ephemeral — created and destroyed per session via fixture.
- Never share mutable state between integration tests.
- Integration tests must be runnable in CI — no local-only dependencies.

---

## 7. Coverage Standards

- Minimum threshold: 90% — enforced in `pyproject.toml` and pre-push hook.
- Branch coverage is measured, not just line coverage.
- Coverage must not regress on any commit.
- Exclusions are acceptable only for:
  - `if __name__ == "__main__":` blocks
  - `if TYPE_CHECKING:` blocks
  - `raise NotImplementedError` in abstract methods
  - Lines explicitly marked `# pragma: no cover` with a comment justifying why

```python
# Acceptable pragma usage
def platform_specific_path() -> Path:
    if sys.platform == "win32":  # pragma: no cover
        return Path("C:/Users")  # Windows not supported, excluded from coverage
    return Path.home()
```

View coverage report after running tests:

```bash
uv run pytest                    # generates coverage XML and terminal report
open htmlcov/index.html          # browse coverage by file (if html report enabled)
```

---

## 8. What Claude Must Do With This Skill

When implementing any STANDARD change:

- State the three discipline check questions before writing any test
- Write the test first — show the file, show the failing run output
- Never write implementation before showing red
- Use descriptive test names that read as sentences
- Use `pytest.mark.parametrize` for input variation — never duplicate test functions
- Use `CliRunner` for all CLI tests — never subprocess in unit tests
- Use `setup()` / `teardown()` in every bats test file
- Flag any test that mocks the database as a BLOCKING finding in code review
- Flag any coverage regression as a BLOCKING finding in code review
- Flag vague test names (e.g. `test_login`) as NON-BLOCKING findings in code review
- Never mark implementation complete without showing a green full test suite run
