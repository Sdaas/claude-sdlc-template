---
name: security
description: >
  Load this skill for any task involving security review, evaluating security
  implications of a change, checking for vulnerabilities, or conducting the
  security review section of a code review. Applies to all STANDARD changes
  in projects built from claude-sdlc-template. Security review is mandatory
  and runs as part of every code review — it is never a separate optional step.
---

# Security Review Conventions

This skill defines the full security checklist, how Claude conducts the security
review dialogue, and what constitutes a passing security review. Security review
is mandatory for every STANDARD change. It runs as the final section of code
review using Sonnet 4.6.

---

## 1. Scope

Security review covers all changed files:

- Python source files and tests
- Shell scripts
- SQL files and migrations
- Configuration files (pyproject.toml, GitHub Actions workflows, .env examples)
- Documentation (README, CONTRIBUTING — check for accidentally committed secrets
  or instructions that could introduce vulnerabilities)

---

## 2. Full Security Checklist

### 2.1 Secrets and Credentials

- [ ] No API keys, tokens, passwords, or secrets in any source file
- [ ] No secrets in comments or docstrings
- [ ] No secrets in test fixtures — use environment variables or pytest fixtures
      that generate values at test time
- [ ] No `.env` files committed — `.env.example` with placeholder values is acceptable
- [ ] No credentials in GitHub Actions workflow files — use GitHub Secrets
- [ ] `git log` and commit history checked for accidentally committed secrets
      (not just the current diff)

**Shell-specific:**
- [ ] No hardcoded credentials in shell scripts
- [ ] Secrets passed via environment variables, not command-line arguments
      (command-line arguments are visible in `ps` output)

### 2.2 Input Validation

- [ ] All CLI arguments and options validated before use
- [ ] File paths from user input sanitised — check for path traversal:

```python
# WRONG — path traversal vulnerability
def read_file(filename: str) -> str:
    return Path(filename).read_text()

# CORRECT — constrain to safe directory
def read_file(filename: str) -> str:
    safe_dir = Path.home() / ".config" / "myapp"
    target = (safe_dir / filename).resolve()
    if not str(target).startswith(str(safe_dir)):
        raise ValueError(f"Path traversal detected: {filename}")
    return target.read_text()
```

- [ ] Integer inputs validated for range before use
- [ ] URLs from user input validated before use — check scheme, do not
      allow `file://` unless explicitly required
- [ ] No user input passed directly to shell commands

### 2.3 Injection Vulnerabilities

**Python:**
- [ ] No `eval()` or `exec()` with user-controlled input
- [ ] No `subprocess` calls with `shell=True` and user-controlled input:

```python
# WRONG — shell injection
subprocess.run(f"echo {user_input}", shell=True)

# CORRECT — use list form, never shell=True with user input
subprocess.run(["echo", user_input], shell=False, check=True)
```

- [ ] No `pickle.loads()` on untrusted data
- [ ] No `yaml.load()` — use `yaml.safe_load()` exclusively

**SQL:**
- [ ] No string interpolation or f-strings in SQL queries — parameterised only:

```python
# WRONG — SQL injection
cursor.execute(f"SELECT * FROM users WHERE name = '{name}'")

# CORRECT
cursor.execute("SELECT * FROM users WHERE name = ?", (name,))
```

- [ ] No raw SQL constructed from user input through any mechanism

**Shell:**
- [ ] All variables quoted in shell scripts: `"${variable}"` not `$variable`
- [ ] User input never passed directly to shell commands without sanitisation
- [ ] No `eval` in shell scripts with user-controlled input

### 2.4 File System Safety

- [ ] File operations use `pathlib.Path` — never `os.path` with string concatenation
- [ ] Temporary files created with `tempfile` module — never predictable paths
- [ ] File permissions set explicitly when creating files:

```python
import tempfile
import stat

# Create temp file with restricted permissions
fd, path = tempfile.mkstemp()
os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)  # 600 — owner read/write only
```

- [ ] No world-writable files created by the tool
- [ ] Config files written to user home directory, not system directories

### 2.5 Error Handling and Information Leakage

- [ ] Error messages do not expose internal paths, stack traces, or system details
      to the user in production:

```python
# WRONG — leaks internal detail
except FileNotFoundError as e:
    click.echo(f"Error: {e}")  # exposes full path

# CORRECT — user-friendly message, detail goes to logger
except FileNotFoundError:
    logger.error("Config file not found", exc_info=True)
    raise click.ClickException("Configuration file not found. Run 'init' first.")
```

- [ ] No sensitive data logged at DEBUG level that could be exposed in verbose mode
- [ ] Exception handling never silently swallows errors:

```python
# WRONG — silent failure
try:
    do_something()
except Exception:
    pass

# CORRECT — log and re-raise or handle explicitly
try:
    do_something()
except SpecificError as e:
    logger.error("Failed to do something: %s", e, exc_info=True)
    raise
```

### 2.6 Dependency Security

- [ ] No new dependencies added without review of their security record
- [ ] Dependencies pinned via `uv.lock` — no floating versions in production
- [ ] New dependencies checked against known vulnerability databases:

```bash
# Check for known vulnerabilities in dependencies
uv run pip-audit

# Or using the GitHub Advisory Database via safety
uv run safety check
```

- [ ] No dependencies with known critical vulnerabilities introduced
- [ ] Transitive dependencies reviewed if a new direct dependency is added

### 2.7 GitHub Actions Workflow Security

- [ ] No secrets printed to logs: `echo "$SECRET"` is a vulnerability
- [ ] `GITHUB_TOKEN` permissions scoped to minimum required:

```yaml
permissions:
  contents: read    # not write unless needed
  pull-requests: write  # only if needed
```

- [ ] Third-party Actions pinned to a full commit SHA, not a mutable tag:

```yaml
# WRONG — mutable tag, supply chain risk
uses: actions/checkout@v4

# CORRECT — pinned to commit SHA
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
```

- [ ] No user-controlled input interpolated into `run:` steps without sanitisation
- [ ] Workflow trigger conditions reviewed — avoid `pull_request_target` without
      careful review

### 2.8 Shell Script Security

- [ ] `set -euo pipefail` present in every script
- [ ] No `eval` with user-controlled input
- [ ] No `curl | bash` patterns — download, verify checksum, then execute
- [ ] Temporary files use `mktemp` — never predictable filenames
- [ ] Scripts do not run as root unless explicitly required and documented

### 2.9 Homebrew Formula Security

- [ ] `sha256` computed fresh for every release — never reused
- [ ] Resource block sha256 values verified against PyPI checksums
- [ ] No `curl | bash` in formula `install` block
- [ ] Formula does not grant elevated permissions post-install

---

## 3. Severity Definitions for Security Findings

**CRITICAL (always BLOCKING):**
- Injection vulnerabilities (SQL, shell, command)
- Hardcoded secrets or credentials in any committed file
- Path traversal vulnerabilities
- `shell=True` with user-controlled input
- Secrets printed to logs or error output

**HIGH (always BLOCKING):**
- Missing input validation on user-controlled data
- Silent exception swallowing that hides security-relevant errors
- Dependencies with known critical vulnerabilities
- GitHub Actions using mutable tags for third-party actions
- World-readable files containing sensitive data

**MEDIUM (BLOCKING by default, may be downgraded with justification):**
- Information leakage in error messages (internal paths, stack traces)
- `yaml.load()` instead of `yaml.safe_load()`
- Temporary files with predictable names
- Missing file permission setting on created files
- Floating dependency versions (not pinned via lockfile)

**LOW (NON-BLOCKING):**
- Debug logging that includes non-sensitive internal state
- Minor information leakage that doesn't expose actionable data
- Style issues that could become security issues if patterns spread

---

## 4. Review Output Format

Security findings are recorded in `CODE_REVIEW.md` under a dedicated section.
They follow the same dialogue format as code review findings.

```markdown
### Security Review

**Reviewer:** Claude (Sonnet 4.6)
**Checklist version:** {date of this skill file}
**Status:** IN REVIEW

#### Checklist Coverage

Sections reviewed:
- [x] 2.1 Secrets and Credentials
- [x] 2.2 Input Validation
- [x] 2.3 Injection Vulnerabilities
- [x] 2.4 File System Safety
- [x] 2.5 Error Handling and Information Leakage
- [x] 2.6 Dependency Security
- [x] 2.7 GitHub Actions Workflow Security (if workflows changed)
- [x] 2.8 Shell Script Security (if shell scripts changed)
- [x] 2.9 Homebrew Formula Security (if formula changed)

#### Security Findings

**CRITICAL / HIGH (BLOCKING)**

1. {Finding title}
   Severity: CRITICAL | HIGH
   File: {filename}:{line}
   Issue: {what the vulnerability is}
   Impact: {what an attacker could do}
   Recommendation: {how to fix it}
   Resolution: {filled in after dialogue}

**MEDIUM / LOW (see severity)**

2. {Finding title}
   Severity: MEDIUM | LOW
   File: {filename}:{line}
   Issue: {what the issue is}
   Recommendation: {suggestion}
   Resolution: {filled in after dialogue}

#### Security Dialogue Record

**Finding 1 — {title}**
Claude: {finding detail and impact}
Developer: {response}
Claude: {updated recommendation or acknowledgement}
Resolution: {agreed fix or DEFERRED: {reason}}

#### Security Review Final Status

pip-audit: PASS | FAIL | NOT RUN (reason)
No CRITICAL findings: YES | NO
No unresolved HIGH findings: YES | NO
All MEDIUM findings addressed or deferred with justification: YES | NO

Security review passed: YES | NO
```

---

## 5. Tools to Run

Claude runs these tools as part of security review and reports their output:

```bash
# Check Python dependencies for known vulnerabilities
uv run pip-audit

# Run ruff with security rules (S ruleset — bandit)
uv run ruff check --select S .

# Check for secrets accidentally staged (if pre-commit not already run)
git diff --staged | grep -iE "(password|secret|token|api_key|private_key)" || true

# Check shell scripts
shellcheck scripts/*.sh

# Lint SQL
sqlfluff lint sql/ --dialect sqlite  # adjust dialect as needed
```

---

## 6. What Claude Must Do With This Skill

When conducting security review:

- Always use Sonnet 4.6
- Always run the full checklist — never skip sections because "this change is simple"
- Always run pip-audit and report the output
- Always run ruff with the S ruleset and report findings
- Classify every finding by severity before the dialogue begins
- Never downgrade a CRITICAL finding — these are always BLOCKING
- Never pass a security review with an unresolved CRITICAL or HIGH finding
- MEDIUM findings may be deferred only with explicit developer justification
  recorded in the dialogue
- Always check GitHub Actions workflows if any `.github/` files changed
- Always check shell scripts if any `scripts/*.sh` files changed
- Flag any `shell=True` in subprocess calls as CRITICAL — no exceptions
- Flag any string interpolation in SQL as CRITICAL — no exceptions
- Flag any hardcoded secret as CRITICAL — no exceptions
