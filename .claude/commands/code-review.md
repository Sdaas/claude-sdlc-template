# /code-review — Code Review and Security Review Dialogue

Triggered by: workflows skill Steps 7-8, or `/code-review` (manual)

Code review and security review run in the same session — security review
is the final section, not a separate step. Load the `security` skill for
the security review section.

---

## Immediate Actions

1. Announce:

```
Starting Code Review + Security Review.
```

2. Identify changed files:

```bash
git diff main...HEAD --name-only
```

   If no active feature branch is obvious, ask: "Which branch or
   commit range should I review?"

3. Read every changed file in full before presenting any findings.

4. Run all tool checks and collect output:

```bash
shellcheck bootstrap.sh tests/test_bootstrap.sh
shfmt -d bootstrap.sh tests/test_bootstrap.sh   # warn if shfmt not installed, don't fail
bash tests/test_bootstrap.sh
```

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

Code review runs after the CODE gate completes — all tests are green and
the developer signals the implementation is ready.

Code review covers:

- All changed shell scripts (`bootstrap.sh`, `tests/test_bootstrap.sh`, `hooks/*.sh`)
- All changed configuration files (`.claude/`, `settings.json`, etc.)
- All changed documentation files

Code review does NOT cover:

- Files explicitly excluded in `.gitignore`
- Files unchanged by the current feature or bugfix

---

## What Claude Reviews For

### Correctness

- Does the implementation match the approved DESIGN.md?
- Does it solve the stated problem without introducing new ones?
- Are edge cases handled that were identified in the test strategy?
- Are all error paths handled explicitly?

### Test Quality

- Does every changed source file have corresponding test coverage?
- Are test names descriptive — do they read as sentences?
- Are assert helpers used consistently?
- Do tests cover both happy path and failure modes?

### Shell Script Checks

- Every script starts with `#!/usr/bin/env bash`
- Every script has `set -euo pipefail` immediately after shebang
- All variables are quoted: `"${variable}"` not `$variable`
- `$(...)` used for command substitution — no backticks
- No hardcoded paths — use variables or detect at runtime
- `shellcheck` passes with zero warnings
- `shfmt -d` produces no diff (formatting consistent, if shfmt installed)
- Functions are used for repeated logic
- All function-local variables declared with `local`
- Scripts are idempotent — safe to re-run without side effects
- External dependencies checked at startup before any work begins
- Non-zero exit code on every failure path
- Exit status of all invoked scripts and tools is checked

### Commit Quality

- Commits are atomic — one concern per commit
- Commit messages follow Conventional Commits format
- No debug commits (e.g. "wip", "fix fix", "test", "asdf")
- No commented-out code committed
- No TODO comments committed without a linked issue number

### Documentation

- README.md updated if user-facing behaviour changed
- CLAUDE.md updated if commands, skills, or gates changed
- Every new file in `.claude/commands/`, `.claude/skills/`, or `hooks/`
  is documented in README.md — this is BLOCKING if missing
- Internal links use relative paths, not absolute URLs
- All files and paths referenced in markdown actually exist in the repo

---

## Severity Definitions

**BLOCKING — must be resolved before review passes:**

- Correctness issues — implementation doesn't match design or breaks existing behaviour
- Missing tests for changed shell scripts
- shellcheck warnings (zero-warning policy)
- Missing `set -euo pipefail` in shell scripts
- Unquoted variables in shell scripts
- Security vulnerabilities (any finding from the security checklist)
- Committed secrets or credentials
- New file in `.claude/` or `hooks/` not documented in README.md

**NON-BLOCKING — should be resolved, may be deferred with reason:**

- shfmt formatting differences (if shfmt not installed on dev machine, defer)
- Style issues that don't affect correctness
- Test names that are vague but not wrong
- TODO comments without issue numbers

---

## Review Output Format

```markdown
## Code Review — {Feature or Bug Title}

**Date:** {YYYY-MM-DD}
**Reviewer:** Claude
**Commit range:** {start-sha}..{end-sha}
**Files reviewed:** {count} files
**Status:** IN REVIEW

---

### Summary

{2-3 sentence overview of what the implementation does and general quality assessment.}

---

### Tool Check Results

shellcheck: PASS | FAIL
shfmt: PASS | FAIL | SKIPPED (not installed)
bash tests/test_bootstrap.sh: PASS | FAIL ({N} passed, {N} failed)

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

---

### Security Review

{See security skill for full checklist. Security findings listed here
with the same BLOCKING / NON-BLOCKING classification.}

**Security findings:**

{numbered list, or "No security findings identified." with brief justification}

**Security dialogue record:**

{same format as above}

---

Total findings: {N} blocking, {N} non-blocking
Blocking findings resolved: YES | NO
Non-blocking findings: {N} resolved, {N} deferred
shellcheck: PASS | FAIL
shfmt: PASS | FAIL | SKIPPED
Tests: PASS | FAIL

Review passed: YES | NO
Approved by: Claude + {developer name}
Date approved: {YYYY-MM-DD}
```

---

## Passing Criteria

A code review passes when:

- All BLOCKING findings are resolved
- `shellcheck` passes with zero warnings
- `bash tests/test_bootstrap.sh` passes (zero failures)
- Security review has no unresolved BLOCKING findings
- Developer has given explicit sign-off
- CODE_REVIEW.md is committed alongside the implementation

---

## Rules

- Read every changed file before presenting any findings — no surprises
- Run all tool checks — never rely on developer's assertion they pass
- Never pass review with unresolved BLOCKING findings
- Security review always runs — even if code review found no issues
- If developer pushes back on a BLOCKING finding, record the disagreement
  — never silently drop a blocking finding
