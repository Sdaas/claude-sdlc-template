---
name: workflows
description: >
  Load this skill whenever /feature, /bugfix, or /trivial is invoked, or when
  Claude needs to determine the correct gate sequence for a task. Defines the
  exact step-by-step process for each workflow type. This is the process bible —
  every gate, every artifact, every confirmation required.
---

# Workflow Definitions

This skill defines the exact execution sequence for every workflow type in
this repo. When a workflow is triggered, Claude loads this skill
and follows the relevant sequence step by step. No improvisation. No skipping.
No reordering.

The full test suite for this repo is:
```bash
shellcheck bootstrap.sh tests/test_bootstrap.sh
shfmt -d bootstrap.sh tests/test_bootstrap.sh   # warn if shfmt not installed
bash tests/test_bootstrap.sh
```

---

## How to Read This Skill

Each workflow is defined as a numbered sequence of steps. Each step specifies:

- **Gate** — the name of the active gate
- **Action** — exactly what Claude does
- **Artifact** — what is written and where
- **Confirmation** — what Claude waits for before proceeding
- **Exit condition** — what "done" means for this step

---

## 1. Trigger Protocol

Before starting any workflow, Claude must:

```
1. State the detected intent and workflow type
2. State the classification (TRIVIAL or STANDARD)
3. For natural language triggers: wait for developer confirmation
4. For slash command triggers: proceed after stating the workflow
5. Announce the first gate
```

---

## 2. Feature Workflow (`/feature`)

Triggered by: `/feature "description"` or confirmed natural language feature request.

Full gate sequence:
```
CLASSIFY → DESIGN → PLAN → PLAN REVIEW →
CODE (write test first, show red, implement, show green) →
CODE REVIEW → SECURITY REVIEW → COMMIT → MERGE → DONE
```

---

### Step 1 — CLASSIFY

**Action:**
- State the feature description in plain language
- Confirm it is a STANDARD change
- Confirm the artifact naming convention (slug or issue number)
- State the artifact folder path: `docs/decisions/{slug}/`
- Create the artifact folder
- **Branch setup** (after slug confirmed):
  - Run `git rev-parse --abbrev-ref HEAD`
  - If on **main**: check `git status --short`. If dirty, warn about
    uncommitted changes and wait for decision. Then:
    `git checkout -b {type}/{slug}` — if that fails (branch exists),
    use `git checkout -b {type}/{slug}-{YYYY-MM-DD}`.
    Announce: "Created branch {type}/{slug}."
    (`{type}` = `feature` for `/feature`, `fix` for `/bugfix`)
  - If on a **non-main branch**: warn "You're on branch {branch-name}.
    Continue here, or create a new branch?" — wait for decision.

**Confirmation:** Developer agrees with classification, naming, and branch
**Exit condition:** Artifact folder exists, classification agreed, branch confirmed

---

### Step 2 — DESIGN


**Action:**
- Read any related existing code, open artifacts, git log
- Write `docs/decisions/{slug}/DESIGN.md` following the `design-doc` skill
- Present the design **section by section** — do not present all at once
- Incorporate developer feedback inline as each section is discussed
- When all sections agreed, update status to IN REVIEW

**Artifact:** `docs/decisions/{slug}/DESIGN.md` (status: IN REVIEW)
**Confirmation:** Developer agrees each section before Claude moves to the next
**Exit condition:** All sections discussed, DESIGN.md status = IN REVIEW

---

### Step 3 — PLAN


**Action:**
- Write `docs/decisions/{slug}/PLAN.md` containing:
  - Claude's understanding of the task in plain language
  - Proposed changes file by file
  - Documentation updates required (README.md, CLAUDE.md, etc.)
  - Test strategy: what will be added to `tests/test_bootstrap.sh`
  - Any gate exceptions with justification
- Present the plan **point by point** — one item at a time
- Answer developer questions about each item before moving to next

**Artifact:** `docs/decisions/{slug}/PLAN.md`
**Confirmation:** Developer agrees each point individually
**Exit condition:** All plan points agreed, PLAN.md committed

---

### Step 4 — PLAN REVIEW


**Action:**
- Read PLAN.md in full
- Present ALL findings upfront — numbered, BLOCKING / NON-BLOCKING
- Address findings one at a time
- Update PLAN.md to reflect any agreed changes
- Mark plan as agreed when all BLOCKING findings resolved

**Confirmation:** Developer responds to each finding individually
**Exit condition:** All BLOCKING findings resolved, plan explicitly agreed

---

### Step 5 — CODE



**TDD discipline check — state these before writing any code:**
1. What behaviour am I testing?
2. What is the simplest test that would fail right now?
3. What is the minimum implementation that would make it pass?

**Action:**
- Write the failing test in `tests/test_bootstrap.sh`
- Run: `bash tests/test_bootstrap.sh` — show the red output (FAIL count > 0)
- Do not proceed past the first test until red is shown
- Implement only enough in `bootstrap.sh` to make the failing test pass
- Run `bash tests/test_bootstrap.sh` — show the green output (0 failures)
- Refactor only after green — run full suite after refactor
- Repeat TDD cycle for each piece of functionality
- When all planned functionality implemented, run the full suite:
  ```bash
  shellcheck bootstrap.sh tests/test_bootstrap.sh
  bash tests/test_bootstrap.sh
  ```
- Show complete output

**Confirmation:** Developer confirms each TDD cycle (red → green) before the next begins
**Exit condition:** All tests pass, full suite shown green, shellcheck clean

---

### Step 6 — CODE REVIEW


**Action:**
- Read every changed file before presenting any findings
- Run tool checks: `shellcheck bootstrap.sh tests/test_bootstrap.sh`,
  `shfmt -d bootstrap.sh tests/test_bootstrap.sh`, `bash tests/test_bootstrap.sh`
- Present ALL findings upfront — numbered, BLOCKING / NON-BLOCKING
- Address findings one at a time, BLOCKING first
- Write full dialogue to `docs/decisions/{slug}/CODE_REVIEW.md`

**Artifact:** `docs/decisions/{slug}/CODE_REVIEW.md`
**Confirmation:** Developer responds to each finding individually
**Exit condition:** All BLOCKING code review findings resolved

---

### Step 7 — SECURITY REVIEW


**Action:**
- Apply full security checklist from `security` skill
- Present ALL security findings upfront — numbered, by severity
- Address findings one at a time, CRITICAL/HIGH first
- Append full security dialogue to CODE_REVIEW.md under "Security Review" section

**Artifact:** `docs/decisions/{slug}/CODE_REVIEW.md` (security section appended)
**Confirmation:** Developer responds to each security finding individually
**Exit condition:** No unresolved CRITICAL or HIGH findings,
CODE_REVIEW.md complete and committed

---

### Step 8 — COMMIT


**Action:**
- Generate commit message(s) following Conventional Commits format
- Present each commit message for developer approval
- Stage files for each atomic commit
- Show the staged diff before each commit
- Wait for explicit developer approval before each commit
- Execute the commit after approval
- Never use --no-verify without explicit developer approval

**Confirmation:** Developer approves each commit message and staged diff
**Exit condition:** All changes committed, git log shows clean atomic commits

---

### Step 9 — MERGE


**Action:**
- Confirm PR is open (or open one via `gh pr create`)
- Confirm all checks are passing
- Remind developer to squash merge via GitHub UI or `gh pr merge --squash`
- After merge confirmed: proceed to DONE

**Confirmation:** Developer confirms merge
**Exit condition:** Feature branch merged to main

---

### Step 10 — DONE


**Action:**
- Present completion summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Feature complete ✓ — {feature-slug}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Branch:    {branch-name} (merged)
Tests:     {N} passed, 0 failed
shellcheck: PASS

Artifacts committed:
  docs/decisions/{slug}/DESIGN.md
  docs/decisions/{slug}/PLAN.md
  docs/decisions/{slug}/CODE_REVIEW.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

- Remind developer to delete the feature branch
- Trigger retrospective automatically

**Exit condition:** Retrospective complete or developer starts new task

---

## 3. Bug Fix Workflow (`/bugfix`)

Triggered by: `/bugfix "description"` or confirmed natural language bug report.

Full gate sequence:
```
CLASSIFY → REPRODUCE →
  [if trivial fix]: PLAN → PLAN REVIEW → CODE → CODE REVIEW →
                    SECURITY REVIEW → COMMIT → MERGE
  [if non-trivial]: DESIGN → PLAN → PLAN REVIEW → CODE →
                    CODE REVIEW → SECURITY REVIEW → COMMIT → MERGE
→ DONE
```

Steps are identical to the Feature Workflow except for the following:

---

### Step 2 — REPRODUCE (Bug Fix Only)



Write a failing test in `tests/test_bootstrap.sh` that reproduces the bug exactly.
The test must fail for the right reason — the actual bug behaviour, not a
missing import or unrelated error.

Run `bash tests/test_bootstrap.sh` — show the red output with the bug evidence.

State: "This test proves the bug exists. Making it pass will prove the bug is fixed."

**Confirmation:** Developer confirms the failing test correctly represents the bug
**Exit condition:** Failing test shown red, developer confirms it is correct

---

### Step 3 — CLASSIFY COMPLEXITY (Bug Fix Only)



**TRIVIAL FIX** — all of the following:
- Fix touches one or two files
- No interface changes
- Obvious root cause from the failing test
- Fix described in one sentence

**NON-TRIVIAL FIX** — any of the following:
- Fix touches more than two files
- Root cause requires investigation
- Interface changes needed
- Security implications

For **TRIVIAL FIX**: skip DESIGN, go directly to PLAN.
For **NON-TRIVIAL FIX**: proceed to DESIGN.

The failing test from REPRODUCE becomes the first test in CODE — it is
already written and red.

---

## 4. Trivial Workflow (`/trivial`)

Gate sequence:
```
CLASSIFY → SURGICAL CHANGE → COMMIT → DONE
```

See the `trivial.md` command for full details.

---

## 5. Gate Exception Protocol

If a developer requests skipping a gate:

1. Claude states which gate and why it exists
2. Developer gives explicit approval with stated reason
3. Claude logs the exception in PLAN.md under "Gate Exceptions"
4. Claude proceeds with remaining gates

Claude never skips a gate silently. The exception is always logged.

---

## 6. Mid-Task Scope Creep Protocol

If implementation is larger than classified:

1. Stop immediately
2. State: "Scope is larger than classified. I need to reclassify."
3. Describe what was discovered
4. Propose reclassification
5. Wait for developer agreement
6. If agreed: restart at the appropriate gate (carry existing work forward)

---

## 7. What Claude Must Do With This Skill

- Load this skill on every `/feature`, `/bugfix`, and `/trivial` invocation
- Follow the step sequence exactly — no improvisation, no reordering
- State the active gate at all times
- Announce the active gate at every transition
- Never proceed past a gate without its exit condition being met
- Log all gate exceptions in PLAN.md
- Flag all scope creep immediately — never silently expand scope
- The DONE step always triggers retrospective for Feature/Bugfix
- **Branch rules:**
  - `/trivial` — may run on any branch including main; never creates a branch
  - `/feature` and `/bugfix` — never proceed on main; create `feature/{slug}`
    or `fix/{slug}` from main, or warn and wait if already on a non-main branch
