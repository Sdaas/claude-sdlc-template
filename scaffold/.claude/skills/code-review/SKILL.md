---
name: code-review
description: >
  Load this skill for any task involving code review, reviewing a pull request,
  evaluating code quality, or conducting the code review gate in the STANDARD
  workflow. Applies to all projects built from claude-sdlc-template. Triggered
  automatically after CODE gate completes, via /code-review command.
---

# Code Review Conventions

This skill defines what Claude looks for during code review, how the review
dialogue is conducted, and what constitutes a passing review. Code review is
mandatory for every STANDARD change. It always includes a Security Review section.

Uses Sonnet 4.6.

---

## 1. When Code Review Runs

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

## 2. What Claude Reviews For

### 2.1 Correctness

- Does the implementation match the approved DESIGN.md?
- Does it solve the stated problem without introducing new ones?
- Are edge cases handled that were identified in the test strategy?
- Are all error paths handled explicitly?
- Are return types and function signatures consistent with the design?

### 2.2 Test Quality

- Does every changed source file have corresponding test coverage?
- Are test names descriptive — do they read as sentences?
- Are parametrize used for input variation rather than duplicated tests?
- Are fixtures used correctly — shared in conftest.py, local when appropriate?
- Are mocks applied at the right boundary?
- Do integration tests use real dependencies, not mocked ones?
- Do bats tests have setup() and teardown()?
- Is coverage at or above the threshold after this change?

### 2.3 Code Quality

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

### 2.4 Python-Specific Checks

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

### 2.5 Shell Script Checks

- Every script starts with `#!/usr/bin/env bash`
- Every script has `set -euo pipefail` immediately after shebang
- All variables are quoted: `"${variable}"` not `$variable`
- No hardcoded paths — use variables or detect at runtime
- `shellcheck` passes with zero warnings
- Functions are used for repeated logic
- Scripts are single-responsibility

### 2.6 SQL Checks

- No string interpolation in SQL — parameterised queries only
- Migration files follow zero-padded sequential naming
- No edits to previously committed migration files
- All new SQL files pass `sqlfluff` lint
- Query files are named for their intent

### 2.7 Commit Quality

- Commits are atomic — one concern per commit
- Commit messages follow Conventional Commits format
- No debug commits (e.g. "wip", "fix fix", "test", "asdf")
- No commented-out code committed
- No TODO comments committed without a linked issue number

### 2.8 Documentation

- Public functions have docstrings
- CLI commands have help text on every argument and option
- README updated if user-facing behaviour changed
- CONTRIBUTING.md updated if developer workflow changed
- Inline comments explain why, not what

---

## 3. Severity Definitions

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

## 4. Review Output Format

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

```markdown
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
```

Total findings: {N} blocking, {N} non-blocking
Blocking findings resolved: YES | NO
Non-blocking findings: {N} resolved, {N} deferred
Coverage after change: {N}% ({direction} from baseline)
Mypy: PASS | FAIL
Ruff: PASS | FAIL
Shellcheck: PASS | FAIL (if shell scripts changed)
Sqlfluff: PASS | FAIL (if SQL changed)

Review passed: YES | NO
Approved by: Claude + {developer name}
Date approved: {YYYY-MM-DD}
```

---

## 5. Review Dialogue Protocol

Follows the standard protocol from CLAUDE.md Section 8.

Additional rules specific to code review:

- Claude reads every changed file before presenting any findings — no incremental
  findings that appear mid-dialogue because Claude hadn't read the whole diff yet
- Claude presents the complete findings list upfront, then addresses one at a time
- When a finding is resolved, Claude confirms the fix before moving to the next
- Claude runs the tool checks (mypy, ruff, shellcheck, sqlfluff) and reports
  their output as part of the review — does not rely on the developer's claim
  that they pass
- Security review findings are presented after all code findings are resolved —
  security is a separate dialogue within the same review session

---

## 6. Passing Criteria

A code review passes when:

- All BLOCKING findings are resolved
- All linter checks pass: ruff, mypy, shellcheck (if applicable), sqlfluff (if applicable)
- Coverage is at or above threshold
- Security review has no unresolved BLOCKING findings
- Developer has given explicit sign-off
- CODE_REVIEW.md is committed alongside the implementation

A code review does not pass by silence or by the developer saying "looks fine."
Explicit sign-off is required. If the developer disagrees with a BLOCKING finding,
the disagreement is recorded in the dialogue and escalated — Claude does not
silently drop a blocking finding.

---

## 7. What Claude Must Do With This Skill

When conducting a code review:

- Always use Sonnet 4.6
- Always read every changed file before presenting any findings
- Always present the complete findings list before addressing any individual finding
- Always run tool checks and report their output — never rely on developer assertions
- Always classify every finding as BLOCKING or NON-BLOCKING before the dialogue
- Never drop a BLOCKING finding because the developer pushes back —
  record the disagreement and flag it
- Never pass a review with unresolved BLOCKING findings
- Always conduct security review as part of code review — never skip it
- Always commit CODE_REVIEW.md alongside the implementation files
- Flag any deviation from python-cli conventions as at minimum NON-BLOCKING
- Flag missing docstrings on public functions as NON-BLOCKING
- Flag missing docstrings on CLI arguments and options as BLOCKING —
  users depend on help text
