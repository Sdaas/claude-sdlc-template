---
name: tdd
description: >
  Load this skill for any task involving test-driven development, writing tests,
  shell test conventions, or the TDD cycle. Applies to all work on this repo.
  This skill governs how Claude approaches every non-trivial code change to
  bootstrap.sh.
---

# TDD Conventions and Process

This skill defines the test-driven development process and testing conventions
for this repo. TDD is not optional. It is the only permitted development method
for STANDARD changes to `bootstrap.sh`.

---

## 1. The TDD Cycle

Every STANDARD change follows this cycle without exception:

```
RED      → Write a failing test that describes the desired behaviour
RED      → Run: bash tests/test_bootstrap.sh
           Show the failure output. Do not proceed without seeing red.
GREEN    → Write the minimum code in bootstrap.sh to make the test pass.
GREEN    → Run: bash tests/test_bootstrap.sh
           Show the passing output.
REFACTOR → Clean up the implementation. Tests must still pass after refactor.
REFACTOR → Run: bash tests/test_bootstrap.sh — show the full output.
```

### Non-Negotiable Rules

- Never write implementation code before a failing test exists.
- Never skip showing the red output — paste the actual FAIL count from test_bootstrap.sh.
- Never write more implementation than the failing test requires.
- Never refactor while red — get to green first, then clean up.
- Never mark a feature complete until the full test suite passes.

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

## 2. Shell Test Structure

### Directory Layout

```
tests/
└── test_bootstrap.sh   # single test file — all assertions for bootstrap.sh
```

### Test Framework

`tests/test_bootstrap.sh` uses a set of hand-written assert helpers. These
are the only testing primitives available — no external framework required.

```bash
assert_true  "description" <command>      # passes if command exits 0
assert_false "description" <command>      # passes if command exits non-zero
assert_exit_nonzero "description" "cmd"  # passes if eval of cmd exits non-zero
assert_file_contains "description" <file> <pattern>  # passes if grep finds pattern
```

### Writing a New Test

Add assertions at the end of the appropriate test block in `test_bootstrap.sh`,
or add a new named block:

```bash
# ─────────────────────────────────────────────────────────────────
# My new test block
# ─────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}My new test block${RESET}"

# Each test bootstraps into a fresh temp directory and cleans up
DEST=$(mktemp -d)
bash "${BOOTSTRAP}" --dest "${DEST}" --name "testproject" --author "Test" \
    --email "test@example.com" --github "testuser" --description "A test" \
    --python "3.12" --tap "test/homebrew-tools" 2>/dev/null

assert_true  "expected file exists" test -f "${DEST}/expected-file"
assert_false "unexpected file absent" test -f "${DEST}/unexpected-file"
assert_file_contains "file has expected content" "${DEST}/some-file" "expected string"

rm -rf "${DEST}"
```

### TDD RED Output Example

When you write a new failing assertion, the output will look like:

```
My new test block
  FAIL expected file exists  [condition false: test -f /tmp/tmp.XYZ/expected-file]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Results: 35 passed, 1 failed, 0 skipped
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Show this output before implementing. This is the RED step.

### TDD GREEN Output Example

After implementing the fix:

```
My new test block
  PASS expected file exists

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Results: 36 passed, 0 failed, 0 skipped
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Show this output before moving on. This is the GREEN step.

---

## 3. Full Suite

The complete test suite for this repo — run before every commit:

```bash
shellcheck bootstrap.sh tests/test_bootstrap.sh
shfmt -d bootstrap.sh tests/test_bootstrap.sh   # skip with warning if shfmt not installed
bash tests/test_bootstrap.sh
```

All three must pass (shellcheck: zero warnings; test_bootstrap.sh: 0 failed).

---

## 4. What Claude Must Do With This Skill

When implementing any STANDARD change to `bootstrap.sh`:

- State the three discipline check questions before writing any test
- Write the test in `tests/test_bootstrap.sh` first — show the file change
- Run `bash tests/test_bootstrap.sh` and paste the FAIL output — this is RED
- Never write implementation before showing red
- Implement in `bootstrap.sh` — minimum code to pass the test
- Run `bash tests/test_bootstrap.sh` and paste the PASS output — this is GREEN
- Repeat TDD cycle for each piece of functionality
- After all cycles complete, run the full suite and show the complete output
- Never mark the CODE gate complete without showing a green full suite run
