# /code-review — Code Review and Security Review Dialogue

Triggered by: workflows skill Steps 8-9, or `/code-review` (manual)
Model: Sonnet 4.6 (announce and wait for confirmation)

Code review and security review run in the same session — security review
is the final section, not a separate step. Load the `security` skill for
the security review section.

---

## Immediate Actions

1. Announce model:

```
Starting Code Review + Security Review (Sonnet 4.6).
Please switch to Sonnet 4.6 before we proceed.
Confirm when ready.
```

2. Identify changed files:

```bash
git diff main...HEAD --name-only
```

   If no active feature branch is obvious, ask: "Which branch or
   commit range should I review?"

3. Read every changed file in full before presenting any findings.

4. Run all tool checks and collect output:
   - `uv run ruff check .`
   - `uv run ruff format --check .`
   - `uv run mypy src/`
   - `shellcheck scripts/*.sh` (if shell files changed)
   - `uv run sqlfluff lint sql/` (if SQL files changed)
   - `uv run pip-audit`
   - `uv run ruff check --select S .` (security ruleset)

5. Present ALL code review findings upfront — numbered, BLOCKING /
   NON-BLOCKING. Include tool check failures as findings.

6. Address code review findings one at a time, BLOCKING first.

7. When all code review findings resolved, transition to security review:

```
Code review complete. Starting Security Review.
```

8. Apply the full security checklist from the `security` skill.
   Present ALL security findings upfront.

9. Address security findings one at a time, CRITICAL/HIGH first.

10. Write full dialogue to `docs/decisions/{slug}/CODE_REVIEW.md`
    including the Security Review section.

11. When all BLOCKING findings (code + security) resolved:
    - Update CODE_REVIEW.md with final status
    - Commit CODE_REVIEW.md
    - State: "Code review and security review complete. Ready for COMMIT gate."

---

## When Code Review Runs

Code review runs after the CODE gate completes — all tests are green, coverage
has not regressed, and the developer signals the implementation is ready.

Code review covers:

- All changed Python source files
- All changed shell scripts
- All changed SQL files
- All changed configuration files (pyproject.toml, GitHub Actions workflows, etc.)
- All new or modified test files

Code review does NOT cover:

- Generated files (lockfiles, compiled assets)
- Files explicitly excluded in `.gitignore`
- Files unchanged by the current feature or bugfix

---

## What Claude Reviews For

### Correctness

- Does the implementation match the approved DESIGN.md?
- Does it solve the stated problem without introducing new ones?
- Are edge cases handled that were identified in the test strategy?
- Are all error paths handled explicitly?
- Are return types and function signatures consistent with the design?

### Test Quality

- Does every changed source file have corresponding test coverage?
- Are test names descriptive — do they read as sentences?
- Are parametrize used for input variation rather than duplicated tests?
- Are fixtures used correctly — shared in conftest.py, local when appropriate?
- Are mocks applied at the right boundary?
- Do integration tests use real dependencies, not mocked ones?
- Do bats tests have setup() and teardown()?
- Is coverage at or above the threshold after this change?

### Code Quality

- Is the code as simple as it could be for the problem it solves?
- Are there abstractions that aren't justified by the requirements?
- Are there features or configurability that wasn't requested?
- Does the code follow the conventions in the python-cli skill?
- Is the separation of concerns maintained — cli.py has no business logic,
  core/ has no CLI concerns?
- Are there any print() statements in core/ (should be logging)?
- Are log levels used consistently?
- Are type annotations present on all functions?
- Does mypy pass with strict mode on this code?

### Python-Specific Checks

- No mutable default arguments:

```python
# WRONG
def process(items: list = []) -> None:

# CORRECT
def process(items: list | None = None) -> None:
    if items is None:
        items = []
```

- No bare `except:` clauses — always catch specific exceptions:

```python
# WRONG
try:
    connect()
except:
    pass

# CORRECT
try:
    connect()
except ConnectionError as e:
    logger.error("Connection failed", exc_info=True)
    raise
```

- No `assert` in production code (only in tests):

```python
# WRONG — assert is stripped in optimised Python builds
assert user is not None

# CORRECT
if user is None:
    raise ValueError("User must not be None")
```

- f-strings used for formatting, not `%` or `.format()`:

```python
# WRONG
message = "Hello %s" % name
message = "Hello {}".format(name)

# CORRECT
message = f"Hello {name}"
```

- Pathlib used for all file paths, not `os.path`:

```python
# WRONG
import os
path = os.path.join(home, ".config", "app")

# CORRECT
from pathlib import Path
path = Path.home() / ".config" / "app"
```

### Shell Script Checks

- Every script starts with `#!/usr/bin/env bash`
- Every script has `set -euo pipefail` immediately after shebang
- All variables are quoted: `"${variable}"` not `$variable`
- `$(...)` used for command substitution — no backticks
- No hardcoded paths — use variables or detect at runtime
- `shellcheck` passes with zero warnings
- `shfmt -d` produces no diff (formatting consistent)
- Functions are used for repeated logic
- No function exceeds 40 lines
- All function-local variables declared with `local`
- Scripts are single-responsibility
- Scripts are idempotent — safe to re-run without side effects
- External dependencies checked at startup before any work begins
- `-h` / `--help` and `--verbose` flags present
- No BLUE colour used in output (reserved for Claude Code UI)
- Non-zero exit code on every failure path
- Exit status of all invoked scripts and tools is checked

### SQL Checks

- No string interpolation in SQL — parameterised queries only
- Migration files follow zero-padded sequential naming
- No edits to previously committed migration files
- All new SQL files pass `sqlfluff` lint
- Query files are named for their intent

### Commit Quality

- Commits are atomic — one concern per commit
- Commit messages follow Conventional Commits format
- No debug commits (e.g. "wip", "fix fix", "test", "asdf")
- No commented-out code committed
- No TODO comments committed without a linked issue number

### Documentation

- Public functions have docstrings
- CLI commands have help text on every argument and option
- README updated if user-facing behaviour changed
- CONTRIBUTING.md updated if developer workflow changed
- OVERVIEW.md and CLAUDE.md updated if commands, skills, or gates changed
- Inline comments explain why, not what

Documentation update checks are **BLOCKING** if any of the following are true:
- A file was added, renamed, or deleted and directory listings in docs were not updated
- User-facing behaviour changed and README was not updated
- Developer workflow changed and CONTRIBUTING.md was not updated
- A command or skill was added or removed and CLAUDE.md Section 2 was not updated

**Markdown quality** — applies to every `.md` file created or modified:

- Internal links use relative paths (`../docs/setup.md`), not absolute URLs
- All files and paths referenced in markdown actually exist in the repo
- Anchor links (`[#section]`) match the actual generated heading IDs
- Files longer than two screens have a table of contents that matches the actual headings
- All code blocks specify a language tag for syntax highlighting
- Terminal commands exclude the shell prompt so they are copy-paste friendly
- Command output is visually separated from commands (e.g. a blank line or comment)
- Headers follow strict hierarchy — no skipped levels (`#` → `##` → `###`)
- Instruction documents list prerequisites at the top
- No spelling errors, no broken markdown syntax

---

## Severity Definitions

Every finding is classified as BLOCKING or NON-BLOCKING before the dialogue begins.

**BLOCKING — must be resolved before review passes:**

- Correctness issues — implementation doesn't match design or breaks existing behaviour
- Missing tests for changed code
- Coverage regression
- Security vulnerabilities (any finding from the security checklist)
- Production assert statements
- Bare except clauses
- String interpolation in SQL
- Missing `set -euo pipefail` in shell scripts
- Type annotation missing on public functions
- Mypy strict mode failures
- Committed secrets or credentials

**NON-BLOCKING — should be resolved, may be deferred with reason:**

- Style issues that don't affect correctness
- Docstrings missing on internal (non-public) functions
- Suboptimal but correct logic
- Test names that are vague but not wrong
- Minor log level inconsistencies
- `%` or `.format()` string formatting instead of f-strings
- `os.path` instead of `pathlib` (flag, don't block)
- TODO comments without issue numbers

---

## Review Output Format

```markdown
## Code Review — {Feature or Bug Title}

**Date:** {YYYY-MM-DD}
**Reviewer:** Claude (Sonnet 4.6)
**Commit range:** {start-sha}..{end-sha}
**Files reviewed:** {count} files ({N} Python, {N} shell, {N} SQL, {N} config)
**Status:** IN REVIEW

---

### Summary

{2-3 sentence overview of what the implementation does and general quality assessment.}

---

### Findings

**BLOCKING**

1. {Finding title}
   File: {filename}:{line}
   Issue: {what is wrong}
   Recommendation: {what to change}
   Resolution: {filled in after dialogue}

**NON-BLOCKING**

2. {Finding title}
   File: {filename}:{line}
   Issue: {what could be improved}
   Recommendation: {suggestion}
   Resolution: {filled in after dialogue — or DEFERRED: {reason}}

---

### Dialogue Record

**Finding 1 — {title}**
Claude: {finding detail}
Developer: {response}
Claude: {updated recommendation or acknowledgement}
Resolution: {agreed change or DEFERRED}

...

---

### Security Review

{See security skill for full checklist. Security findings are listed here
with the same BLOCKING / NON-BLOCKING classification.}

**Security findings:**

{numbered list, or "No security findings identified." with brief justification}

**Security dialogue record:**

{same format as above}

### CI Remediation (appended after push if CI fails)

\`\`\`markdown
### CI Remediation

**Branch:** {branch-name}
**Workflow:** {workflow-name}
**Run URL:** {GitHub Actions run URL}

#### Attempt 1

**Failed job:** {job-name}
**Failed step:** {step-name}
**Diagnosis:** {root cause in plain language}
**Log excerpt:**
{5-15 most relevant lines from gh run view --log-failed}

**Fix classification:** TRIVIAL | STANDARD
**Proposed fix:** {what Claude proposed}
**Developer approval:** YES — {timestamp}
**Fix implemented:** {description of change}
**Result:** SUCCESS | FAILURE

#### Attempt 2 (if needed)

...

#### Final Status

Total attempts: {N} of 3 maximum
Resolved: YES | NO
Resolution: {description or ESCALATED TO DEVELOPER}
\`\`\`

Total findings: {N} blocking, {N} non-blocking
Blocking findings resolved: YES | NO
Non-blocking findings: {N} resolved, {N} deferred
Coverage after change: {N}% ({direction} from baseline)
Mypy: PASS | FAIL
Ruff: PASS | FAIL
Ruff --select S (bandit): PASS | FAIL
pip-audit: PASS | FAIL
Shellcheck: PASS | FAIL (if shell scripts changed)
Shfmt: PASS | FAIL (if shell scripts changed)
Sqlfluff: PASS | FAIL (if SQL changed)

Review passed: YES | NO
Approved by: Claude + {developer name}
Date approved: {YYYY-MM-DD}
```

---

## Review Dialogue Protocol

- Read every changed file before presenting any findings — no incremental
  findings that appear mid-dialogue because Claude hadn't read the whole diff yet
- Present the complete findings list upfront, then address one at a time
- When a finding is resolved, confirm the fix before moving to the next
- Run the tool checks (mypy, ruff, shellcheck, sqlfluff) and report their
  output — do not rely on the developer's claim that they pass
- Security review findings are presented after all code findings are resolved —
  security is a separate dialogue within the same review session

---

## Passing Criteria

A code review passes when:

- All BLOCKING findings are resolved
- All linter checks pass: ruff, mypy, shellcheck (if applicable), shfmt (if applicable), sqlfluff (if applicable)
- `ruff check --select S` passes (bandit security rules — zero findings)
- `pip-audit` passes (no known vulnerabilities in dependencies)
- Coverage is at or above threshold
- Security review has no unresolved BLOCKING findings
- Developer has given explicit sign-off
- CODE_REVIEW.md is committed alongside the implementation

A code review does not pass by silence or by the developer saying "looks fine."
Explicit sign-off is required. If the developer disagrees with a BLOCKING finding,
the disagreement is recorded in the dialogue and escalated — never silently drop
a blocking finding.

---

## Rules

- Read every changed file before presenting any findings — no surprises
- Run all tool checks — never rely on developer's assertion they pass
- Never pass review with unresolved BLOCKING or CRITICAL findings
- If developer pushes back on a BLOCKING finding, record the disagreement
  — never silently drop a blocking finding
- Security review always runs — even if code review found no issues
- Flag any deviation from python-cli conventions as at minimum NON-BLOCKING
- Flag missing docstrings on public functions as NON-BLOCKING
- Flag missing docstrings on CLI arguments and options as BLOCKING —
  users depend on help text
- CI remediation log appended here if CI fails after push
