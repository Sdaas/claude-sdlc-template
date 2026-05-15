---
name: security
description: >
  Load this skill for any task involving security review, evaluating security
  implications of a change, or conducting the security review section of a
  code review. Security review is mandatory and runs as part of every code
  review — it is never a separate optional step.
---

# Security Review Conventions

This skill defines the full security checklist for this repo, how Claude
conducts the security review dialogue, and what constitutes a passing
security review. Security review is mandatory for every STANDARD change.
It runs as the final section of code review.

---

## 1. Scope

Security review covers all changed files:

- Shell scripts (`bootstrap.sh`, `tests/test_bootstrap.sh`, `hooks/*.sh`)
- Configuration files (`.claude/settings.json`, etc.)
- Documentation (README.md — check for accidentally exposed paths or credentials)

---

## 2. Full Security Checklist

### 2.1 Secrets and Credentials

- [ ] No API keys, tokens, passwords, or secrets in any source file
- [ ] No secrets in comments
- [ ] No hardcoded credentials in shell scripts
- [ ] No credentials passed as command-line arguments (visible in `ps` output)
- [ ] `git log` checked for accidentally committed secrets (not just current diff)

### 2.2 Input Validation

- [ ] All user-supplied arguments validated before use
- [ ] File paths from user input constrained to safe directories — no path traversal
- [ ] No user input passed directly to shell commands without sanitisation

### 2.3 Shell Script Security

- [ ] `set -euo pipefail` present in every script
- [ ] All variables quoted: `"${variable}"` not `$variable`
- [ ] No `eval` with user-controlled input
- [ ] No `curl | bash` patterns — download, verify, then execute
- [ ] Temp files use `mktemp` — never predictable filenames
- [ ] `trap` set to clean up temp files on EXIT
- [ ] Scripts do not run as root unless explicitly required and documented
- [ ] No hardcoded absolute paths that break on non-standard installations
- [ ] Redirects checked: failed writes must exit non-zero
- [ ] External dependencies checked at startup before any work begins

### 2.4 Error Handling

- [ ] Error messages do not expose sensitive paths or system internals to the user
- [ ] Silent failure (`|| true`, empty catch) only where explicitly intentional
      and documented with a comment
- [ ] Non-zero exit codes on all error paths

### 2.5 File System Safety

- [ ] Temp files created with `mktemp` — never in predictable locations
- [ ] Temp files cleaned up via `trap ... EXIT`
- [ ] Files written to user-specified destinations, not system directories
- [ ] File permissions not broadened beyond what is necessary

---

## 3. Severity Definitions

**CRITICAL (always BLOCKING):**
- Hardcoded credentials in any committed file
- `eval` with user-controlled input
- Path traversal vulnerability
- Credentials printed to stdout/logs

**HIGH (always BLOCKING):**
- Missing `set -euo pipefail`
- Unquoted variables that could cause word splitting or globbing on user input
- Temp files with predictable names (race condition / symlink attack)
- Silent failure swallowing security-relevant errors

**MEDIUM (BLOCKING by default, may be downgraded with justification):**
- Information leakage in error messages (internal paths)
- Missing `trap` for temp file cleanup
- External dependency not checked at startup

**LOW (NON-BLOCKING):**
- Minor style issues that could become security issues if patterns spread

---

## 4. Review Output Format

Security findings are recorded in `CODE_REVIEW.md` under a dedicated section:

```markdown
### Security Review

**Reviewer:** Claude
**Status:** IN REVIEW

#### Checklist Coverage

- [x] 2.1 Secrets and Credentials
- [x] 2.2 Input Validation
- [x] 2.3 Shell Script Security
- [x] 2.4 Error Handling
- [x] 2.5 File System Safety

#### Security Findings

**CRITICAL / HIGH (BLOCKING)**

1. {Finding title}
   Severity: CRITICAL | HIGH
   File: {filename}:{line}
   Issue: {what the vulnerability is}
   Impact: {what an attacker could do}
   Recommendation: {how to fix it}
   Resolution: {filled in after dialogue}

**MEDIUM / LOW**

2. {Finding title}
   Severity: MEDIUM | LOW
   ...

#### Security Dialogue Record

**Finding 1 — {title}**
Claude: {finding detail and impact}
Developer: {response}
Resolution: {agreed fix or DEFERRED: {reason}}

#### Security Review Final Status

No CRITICAL findings: YES | NO
No unresolved HIGH findings: YES | NO
All MEDIUM findings addressed or deferred with justification: YES | NO

Security review passed: YES | NO
```

---

## 5. Tools to Run

```bash
# Static analysis — must pass with zero warnings
shellcheck bootstrap.sh tests/test_bootstrap.sh hooks/*.sh

# Formatting check (warn if shfmt not installed)
shfmt -d bootstrap.sh tests/test_bootstrap.sh hooks/*.sh

# Check for secrets accidentally staged
git diff --staged | grep -iE "(password|secret|token|api_key|private_key)" || true
```

---

## 6. What Claude Must Do With This Skill

When conducting security review:


- Run the full checklist — never skip sections because "this change is simple"
- Run shellcheck and report the output
- Classify every finding by severity before the dialogue begins
- Never downgrade a CRITICAL finding
- Never pass a security review with an unresolved CRITICAL or HIGH finding
- MEDIUM findings may be deferred only with explicit developer justification
