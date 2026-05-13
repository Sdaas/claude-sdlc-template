---
name: workflows
description: >
  Load this skill whenever /feature, /bugfix, or /trivial is invoked, or when
  Claude needs to determine the correct gate sequence for a task. Defines the
  exact step-by-step process for each workflow type. This is the process bible —
  every gate, every artifact, every model, every confirmation required.
---

# Workflow Definitions

This skill defines the exact execution sequence for every workflow type in
claude-sdlc-template. When a workflow is triggered, Claude loads this skill
and follows the relevant sequence step by step. No improvisation. No skipping.
No reordering.

---

## How to Read This Skill

Each workflow is defined as a numbered sequence of steps. Each step specifies:

- **Gate** — the name of the active gate
- **Model** — which model to use (announce and wait for confirmation)
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
5. Announce the first gate and its model
6. Wait for developer to confirm model is set
```

Example for `/feature "add --dry-run flag to deploy command"`:

```
Detected: Feature implementation
Workflow: STANDARD — Feature Path
First gate: DESIGN (Opus 4.6)

Please switch to Opus 4.6 before we proceed.
Confirm when ready.
```

---

## 2. Feature Workflow (`/feature`)

Triggered by: `/feature "description"` or confirmed natural language feature request.

Full gate sequence:
```
CLASSIFY → DESIGN → DESIGN REVIEW → PLAN → PLAN REVIEW →
TDD → CODE → CODE REVIEW → SECURITY REVIEW →
COMMIT → CI MONITOR → [MERGE → MONITOR MAIN] → DONE
```

---

### Step 1 — CLASSIFY

**Model:** Haiku 4.5 (automatic)
**Action:**
- State the feature description in plain language
- Confirm it is a STANDARD change
- Confirm the artifact naming convention (slug or issue number)
- State the artifact folder path: `docs/decisions/{slug}/`
- Create the artifact folder

**Confirmation:** Developer agrees with classification and naming
**Exit condition:** Artifact folder exists, classification agreed

---

### Step 2 — DESIGN

**Model:** Opus 4.6 (announce and wait for confirmation)
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

### Step 3 — DESIGN REVIEW

**Model:** Opus 4.6 (same session, no switch needed)
**Action:**
- Read DESIGN.md in full before saying anything
- Present ALL findings upfront — numbered, BLOCKING / NON-BLOCKING
- Address findings one at a time, BLOCKING first
- Wait for developer response to each finding
- Make agreed change, confirm, move to next
- When all BLOCKING findings resolved, update DESIGN.md status to APPROVED
- Write `docs/decisions/{slug}/DESIGN_REVIEW.md` with full dialogue

**Artifact:** `docs/decisions/{slug}/DESIGN_REVIEW.md`
**Confirmation:** Developer responds to each finding individually
**Exit condition:** All BLOCKING findings resolved, DESIGN.md status = APPROVED,
DESIGN_REVIEW.md committed

---

### Step 4 — PLAN

**Model:** Haiku 4.5 (announce and wait for confirmation)
**Action:**
- Write `docs/decisions/{slug}/PLAN.md` containing:
  - Claude's understanding of the task in plain language
  - Proposed changes file by file
  - Test strategy: what will be tested and how
  - Artifact folder naming confirmation
  - Any gate exceptions with justification
- Present the plan **point by point** — one item at a time
- Answer developer questions about each item before moving to next

**Artifact:** `docs/decisions/{slug}/PLAN.md`
**Confirmation:** Developer agrees each point individually
**Exit condition:** All plan points agreed, PLAN.md committed

---

### Step 5 — PLAN REVIEW

**Model:** Haiku 4.5 (same session, no switch needed)
**Action:**
- Read PLAN.md in full
- Present ALL findings upfront — numbered, BLOCKING / NON-BLOCKING
- Address findings one at a time
- Update PLAN.md to reflect any agreed changes
- Mark plan as agreed when all BLOCKING findings resolved

**Confirmation:** Developer responds to each finding individually
**Exit condition:** All BLOCKING findings resolved, plan explicitly agreed

---

### Step 6 — TDD

**Model:** Sonnet 4.6 (announce and wait for confirmation)
**Action:**
- State the three discipline check questions:
  1. What behaviour am I testing?
  2. What is the simplest test that would fail right now?
  3. What is the minimum implementation that would make it pass?
- Write the first failing test
- Run the test — show the red output
- Do not proceed to CODE until red output is shown

**Confirmation:** Developer sees red output and confirms to proceed
**Exit condition:** At least one failing test exists and has been shown red

---

### Step 7 — CODE

**Model:** Sonnet 4.6 (same session, no switch needed)
**Action:**
- Implement only enough code to make the failing test pass
- Run the test — show the green output
- Refactor only after green — run full suite after refactor
- Repeat TDD cycle for each piece of functionality:
  write failing test → show red → implement → show green → refactor
- Continue until all planned functionality is implemented and tested
- Run the full test suite — show complete output
- Confirm coverage has not regressed

**Confirmation:** Developer confirms each TDD cycle before the next begins
**Exit condition:** All tests pass, coverage at or above threshold,
full test suite shown green

---

### Step 8 — CODE REVIEW

**Model:** Sonnet 4.6 (same session, no switch needed)
**Action:**
- Read every changed file before presenting any findings
- Run tool checks: ruff, mypy, shellcheck (if applicable), sqlfluff (if applicable)
- Present ALL findings upfront — numbered, BLOCKING / NON-BLOCKING
- Address findings one at a time, BLOCKING first
- Wait for developer response to each finding
- Make agreed change, confirm, move to next
- Write full dialogue to `docs/decisions/{slug}/CODE_REVIEW.md`

**Artifact:** `docs/decisions/{slug}/CODE_REVIEW.md` (in progress)
**Confirmation:** Developer responds to each finding individually
**Exit condition:** All BLOCKING code review findings resolved

---

### Step 9 — SECURITY REVIEW

**Model:** Sonnet 4.6 (same session, no switch needed)
**Action:**
- Run security tool checks: pip-audit, ruff --select S
- Apply full security checklist from `security` skill
- Present ALL security findings upfront — numbered, by severity
- Address findings one at a time, CRITICAL/HIGH first
- Wait for developer response to each finding
- Append full security dialogue to CODE_REVIEW.md under "Security Review" section

**Artifact:** `docs/decisions/{slug}/CODE_REVIEW.md` (security section appended)
**Confirmation:** Developer responds to each security finding individually
**Exit condition:** No unresolved CRITICAL or HIGH findings,
CODE_REVIEW.md complete and committed

---

### Step 10 — COMMIT

**Model:** Haiku 4.5 (announce and wait for confirmation)
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

### Step 11 — CI MONITOR

**Model:** Sonnet 4.6 (same session)
**Action:**
- Push the feature branch
- Get the run ID: `gh run list --branch {branch} --limit 1`
- Monitor: `gh run watch {run-id} --exit-status`
- Show live status updates while waiting
- On SUCCESS: confirm and proceed to Step 12
- On FAILURE: enter auto-remediation loop (see `github-actions` skill Section 10)
  - Read failure log: `gh run view {run-id} --log-failed`
  - Diagnose root cause
  - Present structured diagnosis to developer
  - Wait for explicit approval
  - Implement fix
  - Push (explicit approval required)
  - Return to monitoring
  - Maximum 3 remediation attempts before escalating
- Log all remediation attempts in CODE_REVIEW.md

**Confirmation:** Developer approves each remediation fix and each retry push
**Exit condition:** CI passes on feature branch

---

### Step 12 — MERGE AND MONITOR MAIN

**Model:** Sonnet 4.6 (same session)
**Action:**
- Confirm PR is open (or open one via `gh pr create`)
- Confirm all CI checks are passing on the PR
- Remind developer to squash merge via GitHub UI or `gh pr merge --squash`
- After merge confirmed, monitor main CI:
  `gh run list --branch main --limit 1`
  `gh run watch {run-id} --exit-status`
- On SUCCESS: proceed to DONE
- On FAILURE: enter auto-remediation loop for main
  - Create standalone artifact: `docs/decisions/ci-remediation-{date}-{sha}/CI_REMEDIATION.md`
  - Follow same diagnosis and remediation loop as Step 11
  - Fix must go through a new feature branch — never commit directly to main

**Confirmation:** Developer confirms merge, developer approves any main remediation
**Exit condition:** main CI passes after merge

---

### Step 13 — DONE

**Model:** Haiku 4.5 (automatic)
**Action:**
- Present completion summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Feature complete ✓ — {feature-slug}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Branch:    {branch-name} (merged)
Commits:   {N} commits
Tests:     {N} tests passing
Coverage:  {N}%
CI:        PASSING (feature + main)

Artifacts committed:
  docs/decisions/{slug}/DESIGN.md
  docs/decisions/{slug}/DESIGN_REVIEW.md
  docs/decisions/{slug}/PLAN.md
  docs/decisions/{slug}/CODE_REVIEW.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

- Remind developer to delete the feature branch
- Trigger retrospective automatically (load `retrospective` skill)
- If developer invokes `/exit` next: follow exit sequence
- If developer starts a new task: run standup summary first

**Exit condition:** Retrospective complete or developer starts new task

---

## 3. Bug Fix Workflow (`/bugfix`)

Triggered by: `/bugfix "description"` or confirmed natural language bug report.

Full gate sequence:
```
CLASSIFY → REPRODUCE →
  [if trivial fix]: PLAN → PLAN REVIEW → TDD → CODE → CODE REVIEW →
                    SECURITY REVIEW → COMMIT → CI MONITOR → MERGE → MONITOR MAIN
  [if non-trivial]: DESIGN → DESIGN REVIEW → PLAN → PLAN REVIEW → TDD → CODE →
                    CODE REVIEW → SECURITY REVIEW → COMMIT → CI MONITOR →
                    MERGE → MONITOR MAIN
→ DONE
```

Steps identical to Feature Workflow except for the following differences:

---

### Step 1 — CLASSIFY

**Model:** Haiku 4.5 (automatic)
**Action:**
- State the bug description in plain language
- Confirm it is a STANDARD change
- Confirm artifact naming: `docs/decisions/{slug}/` or `docs/decisions/GH-{N}/`
- Do NOT classify complexity yet — that happens after REPRODUCE

**Exit condition:** Artifact folder created, naming agreed

---

### Step 2 — REPRODUCE (Bug Fix Only)

**Model:** Sonnet 4.6 (announce and wait for confirmation)

This step is unique to the bug fix workflow. It always runs before any
design or planning work. This is the proof the bug exists.

**Action:**
- Write a failing test that reproduces the bug exactly
- The test must fail for the right reason — not a missing import or
  unrelated error, but the actual bug behaviour
- Run the test — show the red output with the bug evidence
- State clearly: "This test proves the bug exists. Making it pass will
  prove the bug is fixed."

**Confirmation:** Developer confirms the failing test correctly represents the bug
**Exit condition:** Failing test exists, shown red, developer confirms it
correctly represents the bug

---

### Step 3 — CLASSIFY COMPLEXITY (Bug Fix Only)

**Model:** Haiku 4.5 (automatic)
**Action:**
- Based on the failing test and codebase reading, classify the fix:

**TRIVIAL FIX** — all of the following are true:
  - Fix touches one or two files
  - No interface changes (CLI, function signatures, schema)
  - No new dependencies
  - Obvious root cause identified from the failing test
  - Fix can be described in one sentence

**NON-TRIVIAL FIX** — any of the following are true:
  - Fix touches more than two files
  - Root cause requires investigation
  - Interface changes needed
  - New dependency required
  - Security implications

- Present classification with reasoning
- Developer must agree before proceeding

**Confirmation:** Developer agrees with fix complexity classification
**Exit condition:** Classification agreed — trivial or non-trivial path selected

For **TRIVIAL FIX**: skip to PLAN (Step 4 of feature workflow equivalent)
For **NON-TRIVIAL FIX**: proceed to DESIGN (Step 2 of feature workflow)

Note: The failing test from REPRODUCE becomes the first test in the TDD
gate — it is already written and red. The TDD gate for a bug fix means:
make the existing failing test pass, then add any additional tests for
related edge cases.

---

## 4. Trivial Workflow (`/trivial`)

Triggered by: `/trivial "description"` or confirmed natural language trivial request.

Full gate sequence:
```
CLASSIFY (human agrees) → SURGICAL CHANGE → COMMIT → CI MONITOR → DONE
```

---

### Step 1 — CLASSIFY

**Model:** Haiku 4.5 (automatic)
**Action:**
- State the change description
- Confirm it qualifies as TRIVIAL:
  - Typo, docstring fix, comment update, version bump, or formatting only
  - No logic changes, no interface changes, no new tests needed
- If Claude has any doubt: default to STANDARD and start Feature Workflow

**Confirmation:** Developer explicitly agrees this is TRIVIAL
**Exit condition:** Developer confirms TRIVIAL classification

---

### Step 2 — SURGICAL CHANGE

**Model:** Haiku 4.5 (same session)
**Action:**
- Make only the stated change — nothing else
- Show the diff before staging
- Verify: every changed line traces directly to the stated request
- Flag any unrelated changes found and do not include them

**Confirmation:** Developer confirms diff is correct and contains only
the stated change
**Exit condition:** Change made, diff reviewed and confirmed

---

### Step 3 — COMMIT

**Model:** Haiku 4.5 (same session)
**Action:**
- Generate commit message
- Show staged diff
- Wait for developer approval
- Execute commit after approval

**Confirmation:** Developer approves commit message and staged diff
**Exit condition:** Change committed

---

### Step 4 — CI MONITOR

**Model:** Haiku 4.5 (same session)
**Action:**
- Push change
- Monitor CI run to completion
- On failure: even trivial changes can break CI — enter remediation loop
  (but a CI failure on a trivial change suggests misclassification —
  flag this to the developer)

**Exit condition:** CI passes

---

### Step 5 — DONE

**Model:** Haiku 4.5 (automatic)
**Action:**
- Confirm change is complete
- No retrospective for trivial changes unless developer requests it
- No artifact folder — trivial changes do not produce decision artifacts

---

## 5. Gate Exception Protocol

If a developer requests skipping a gate on the Standard or Feature path:

```
1. Claude states which gate is being requested to skip
2. Claude states why the gate exists and what risk skipping it carries
3. Developer gives explicit approval with stated reason
4. Claude logs the exception in PLAN.md under "Gate Exceptions":
   "DESIGN REVIEW skipped — developer approval — reason: time constraint,
    design is straightforward"
5. Claude proceeds with the remaining gates
```

Claude never skips a gate silently. The exception is always logged.
If the developer insists on skipping a gate without providing a reason,
Claude logs "reason: not provided" and proceeds — but flags it in the
retrospective as a process finding.

---

## 6. Mid-Task Scope Creep Protocol

If during implementation Claude discovers the change is larger than
originally classified:

```
1. Stop immediately — do not continue implementing
2. State: "Scope is larger than classified. I need to reclassify."
3. Describe what was discovered and why it changes the scope
4. Propose reclassification (e.g. TRIVIAL → STANDARD)
5. Wait for developer agreement
6. If reclassification agreed: restart at the appropriate gate
   (do not discard work — carry it into the new workflow)
7. If developer disagrees: log the scope concern in PLAN.md and continue
   with explicit developer acknowledgement
```

---

## 7. What Claude Must Do With This Skill

- Load this skill on every `/feature`, `/bugfix`, and `/trivial` invocation
- Follow the step sequence exactly — no improvisation, no reordering
- State the active gate at all times — developer always knows where they are
- Announce model at every gate transition and wait for confirmation
- Never proceed past a gate without its exit condition being met
- Never skip a confirmation step — every confirmation exists for a reason
- If a step's exit condition cannot be met (e.g. tests will not pass),
  stop and diagnose before proceeding
- Log all gate exceptions in PLAN.md
- Flag all scope creep immediately — never silently expand scope
- The DONE step always triggers retrospective for Standard/Feature/Bugfix —
  never for Trivial unless requested
