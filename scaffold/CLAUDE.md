# CLAUDE.md — Behavioral Contract for claude-sdlc-template

This file governs how Claude behaves in every session. These are not suggestions.
They are mandatory process rules. Deviating from them requires explicit human approval,
stated in the session before the deviation occurs.

---

## Section 1 — Karpathy's Four Principles

*Derived from Andrej Karpathy's observations on LLM coding pitfalls.*

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1.1 Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 1.2 Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 1.3 Surgical Changes

Touch only what you must. Clean up only your own mess.

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 1.4 Goal-Driven Execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work")
require constant clarification.

---

## Section 2 — Workflow Triggers

### Canonical Triggers (Preferred)

The developer starts work using explicit slash commands. These are unambiguous and
immediately start the correct workflow without a confirmation step.

```
/feature "description"    → full standard workflow, starting at DESIGN
/bugfix "description"     → reproduce-first workflow, design gate conditional on complexity
/trivial "description"    → trivial workflow, no design or review gates
/standup                  → session startup summary (also runs automatically)
/retrospective            → session retrospective analysis (also runs automatically at session end)
/design-review            → design review dialogue on current DESIGN.md
/plan-review              → plan review dialogue on current PLAN.md
/code-review              → code review + security review dialogue on current changes
/release                  → hands off to release.sh interactively
/exit                     → retrospective → save SESSION_STATE.md → signal safe to close
```

### Natural Language Triggers (Supported with Confirmation)

If the developer describes work in natural language instead of using a slash command,
Claude must:

1. Detect the intent (feature, bugfix, or trivial)
2. State the detected intent and which workflow it maps to
3. Wait for explicit human confirmation before proceeding

Example:

> Developer: "I want to add a --dry-run flag to the deploy command"
> Claude: "I'll treat this as a feature implementation. This triggers the STANDARD
> workflow starting with DESIGN using Opus 4.6. Shall I proceed, or did you mean
> something different?"

Claude does not proceed until the human confirms. This confirmation counts as the
classification agreement required below.

### Change Classification

Every task has a classification. It must be stated and agreed before work begins.

**TRIVIAL** — typos, docstring fixes, comment updates, version bumps, formatting
**STANDARD** — everything else: features, bug fixes, refactors, dependency changes

Rules:

- Classification must be stated explicitly at the start of every task.
- Human must agree with the classification before work begins.
- When in doubt, default to STANDARD.
- Mid-task scope creep must be flagged immediately — stop, reclassify, get agreement.

---

## Section 3 — Gate Sequences

Claude must state the active gate at all times. Never skip a gate. Never reorder gates.
Skipping any gate requires explicit human approval, stated in the session and logged
in PLAN.md under "Gate Exceptions."

### Trivial Path (`/trivial`)

```
CLASSIFY (human agrees) → SURGICAL CHANGE → COMMIT
```

### Feature Path (`/feature`)

```
CLASSIFY → DESIGN → DESIGN REVIEW → PLAN → PLAN REVIEW →
TDD (red first) → CODE → CODE REVIEW → SECURITY REVIEW →
COMMIT → RELEASE (if applicable, human triggered)
```

### Bug Fix Path (`/bugfix`)

The first act for every bug fix is always a failing test that proves the bug exists.
Design gate is conditional on complexity.

```
REPRODUCE (write failing test proving the bug, show red output) →
CLASSIFY complexity (trivial fix or non-trivial fix, human agrees) →

  if trivial fix:
    PLAN → PLAN REVIEW → TDD → CODE → CODE REVIEW → SECURITY REVIEW → COMMIT

  if non-trivial fix:
    DESIGN → DESIGN REVIEW → PLAN → PLAN REVIEW →
    TDD → CODE → CODE REVIEW → SECURITY REVIEW → COMMIT
```

The REPRODUCE step is never skipped for bug fixes — it is the proof that the bug
exists and becomes the green condition that proves the fix works.

---

## Section 4 — Model Routing

There are two routing mechanisms. Which one applies depends on whether the task
is automated or interactive.

### Automatic Routing (Automated Tasks)

Automated, non-interactive tasks declare their model in the skill or command YAML
frontmatter. Claude Code uses that model automatically — no developer action needed.

| Task                  | Model      | Mechanism        |
|-----------------------|------------|------------------|
| Commit messages       | Haiku 4.5  | YAML frontmatter |
| STANDUP               | Haiku 4.5  | YAML frontmatter |
| CLASSIFY              | Haiku 4.5  | YAML frontmatter |

### Announced Routing (Interactive Gates)

For interactive dialogue gates, Claude cannot switch its own model mid-session.
Claude Code's model is set when the session starts. For these gates, Claude
announces the required model at the start of the gate and waits for the developer
to confirm the switch before proceeding.

| Gate / Task             | Model      | Mechanism               |
|-------------------------|------------|-------------------------|
| PLAN, PLAN REVIEW       | Haiku 4.5  | Claude announces, developer switches |
| CODE                    | Sonnet 4.6 | Claude announces, developer switches |
| CODE REVIEW             | Sonnet 4.6 | Claude announces, developer switches |
| SECURITY REVIEW         | Sonnet 4.6 | Claude announces, developer switches |
| RETROSPECTIVE           | Sonnet 4.6 | Claude announces, developer switches |
| DESIGN                  | Opus 4.6   | Claude announces, developer switches |
| DESIGN REVIEW           | Opus 4.6   | Claude announces, developer switches |
| Architectural decisions | Opus 4.6   | Claude announces, developer switches |

### Announcement Protocol

At the start of every interactive gate, Claude must say:

> "Starting {GATE NAME}. This gate uses {Model}. Please switch to {Model}
> before we proceed. Confirm when ready."

Claude does not proceed until the developer confirms the model is set.

### Rules

- Never silently assume the correct model is active — always announce and confirm.
- If task complexity escalates mid-session, flag it and recommend a model upgrade
  before continuing.
- Manual override is always available — developer states the override explicitly
  and Claude logs it in the session artifact.
- A developer choosing to use a more capable model than specified is always
  acceptable. A developer choosing a less capable model requires explicit
  acknowledgement of the tradeoff.

---

## Section 5 — Planning Contract

Applies to every STANDARD change. No exceptions.

Before any code file is opened for writing:

- Claude writes PLAN.md capturing:
  - Its understanding of the task (in plain language)
  - Proposed changes, file by file
  - Test strategy: what will be tested and how
  - Naming convention for the decision artifact folder (slug or issue number)
  - Any gate exceptions being requested, with justification

- Claude presents the plan point by point, interactively.
- Human must explicitly agree on the plan.
- Claude does not touch implementation files until plan is agreed and first
  failing test is written and shown red.

---

## Section 6 — TDD Contract

- Write the failing test first — always.
- Run the test. Show the red output. Do not proceed without showing it.
- Implement only enough code to make the test pass.
- Refactor only after green.
- Test coverage must not regress on any commit.
- Implementation is complete only when all tests pass.
- Tests are not optional for any non-trivial change.

---

## Section 7 — Ask, Never Assume

- Ambiguous requirement → stop, ask, wait for the answer before proceeding.
- Multiple valid approaches → present tradeoffs, never pick silently.
- Scope feels larger than expected → flag before proceeding.
- External dependency or API → confirm it exists before building against it.
- Unavoidable assumptions → state explicitly and log them in PLAN.md.

---

## Section 8 — Review Protocol

All reviews — Design Review, Plan Review, and Code Review — follow the same
dialogue protocol. No exceptions.

```
1. Read the artifact in full before saying anything.
2. Present ALL findings upfront — numbered, categorised as BLOCKING or NON-BLOCKING.
3. Address findings one at a time, BLOCKING findings first.
4. Wait for human response to each finding before proceeding.
5. Make the agreed change. Confirm it. Move to the next finding.
6. Mark review complete only when all BLOCKING findings are resolved.
7. Persist the full dialogue in the review artifact.
```

Non-blocking findings that the human chooses to defer must be logged in the artifact
under "Deferred Items" with the human's stated reason.

---

## Section 9 — Security Review

- Runs on every STANDARD change. No exceptions.
- Uses Sonnet 4.6.
- Follows the same dialogue protocol as Section 8.
- Findings and dialogue are persisted in CODE_REVIEW.md under a "Security Review" section.

Minimum security checklist (skill `security/` contains the full list):

- No secrets, tokens, or credentials in code or comments
- Input validation on all external inputs
- No use of `eval`, `exec`, `shell=True` without explicit justification
- Dependencies pinned and checked against known vulnerabilities
- File paths sanitised before use
- Error messages do not leak internal state

---

## Section 10 — Commit Discipline

- One concern per commit — atomic and traceable to a single intent.
- Conventional Commits format is mandatory:
  `type(scope): description` — e.g. `feat(auth): add token validation`
- Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `security`
- No `--no-verify` without explicit human approval stated in the session.
- No secrets, tokens, credentials, or environment-specific values ever committed.
- Pre-commit hooks are part of the process, not obstacles to route around.

---

## Section 11 — Artifact Discipline

Every STANDARD change produces and commits these artifacts alongside the code.
Artifacts live in `docs/decisions/` named by feature slug or issue number.

```
docs/decisions/{slug}/          # e.g. add-auth-command
├── DESIGN.md                   # written before implementation, approved before TDD
├── DESIGN_REVIEW.md            # full design review dialogue
├── PLAN.md                     # Claude's understanding, change list, test strategy
└── CODE_REVIEW.md              # full code review dialogue + Security Review section
```

Or by issue number:

```
docs/decisions/{GH-42}/
├── DESIGN.md
...
```

Naming convention is chosen at task start and stated in PLAN.md. Both formats are valid.
Artifacts are committed in the same PR or commit as the code they describe.

---

## Section 12 — Release

- Release is triggered exclusively by a human invoking `release.sh`.
- Claude never triggers a release autonomously.
- `release.sh` drives the full sequence:
  - Version bump in `pyproject.toml`
  - Changelog generation
  - Git tag creation
  - GitHub Actions release workflow trigger
- Claude drives the script interactively — presenting each step, getting confirmation,
  then executing.
- The release skill (`skills/release/`) contains the full sequence specification.

---

## Section 13 — Session Startup and Shutdown

### Session Startup — `/standup`

Every session begins with `/standup` before any task is accepted. Uses Haiku 4.5.

Claude must:

- Read the recent git log (last 10 commits)
- Read any open or in-progress artifacts in `docs/decisions/`
- Identify the current active gate for any in-progress standard change
- Present a structured summary:
  - What was completed recently
  - What is in progress and at which gate
  - What is blocked or has unresolved review findings
  - Suggested first action for this session

Claude does not accept a new task until the standup summary has been presented
and the human has acknowledged it.

### Session Exit — `/exit`

When the developer invokes `/exit`, Claude must complete the following
sequence before signalling it is safe to close. Claude never skips steps.

```
1. Run /retrospective — full session analysis
2. Wait for developer to review and add notes
3. Commit retrospective artifact
4. Write SESSION_STATE.md to project root with:
   - Exit type: GRACEFUL
   - Active branch and gate
   - Open artifact statuses
   - CI status
   - Suggested first action for next session
5. Tell developer: "Session state saved. Safe to close."
```

`SESSION_STATE.md` is in `.gitignore` — it is operational state, not
project history. It is written on every `/exit` and overwritten at the
start of every session by `/standup`.

If the session ends without `/exit` (window close, crash, Ctrl+C):
- No retrospective is written
- No `SESSION_STATE.md` is written
- At next session, `/standup` detects the missing retrospective and
  **requires** the developer to run `/retrospective` before accepting
  any new task

The retrospective may also be triggered manually at any time with `/retrospective`.

Uses Sonnet 4.6. Output persisted to `docs/retrospectives/{YYYY-MM-DD}-{slug}.md`.

Claude analyses the full session transcript across four dimensions:

- **Process** — were gates followed? were any skipped or reordered? were approvals obtained?
- **Cost** — was the right model used at each gate? were there avoidable back-and-forth loops?
- **Effectiveness** — did Claude ask the right questions early? did assumptions cause rework?
- **Communication** — were prompts clear and specific? were responses appropriately concise?

Findings are presented as numbered recommendations, each with a concrete
"next time, do this instead" suggestion. The developer may add their own notes
before the retrospective artifact is committed.

---

## Section 14 — Post-Push Monitoring Contract

Every `git push` triggers a CI monitoring loop. Claude monitors until the run
completes. This is not optional and is never handed off to the developer to check
manually.

### Monitoring Scope

- Every push to a **feature branch** — monitors the CI workflow run
- Every push to **`main`** after a squash merge — monitors the CI workflow run
- Every tag push during **release** — monitors the release workflow run

### Success Path

```
PUSH → poll Actions run → SUCCESS → log result → continue workflow
```

### Failure Path — Auto-Remediation Loop

```
PUSH → poll Actions run → FAILURE →
  1. Read full failure log via: gh run view --log-failed
  2. Diagnose root cause
  3. Classify fix:
       TRIVIAL (lint, format, import order) → implement immediately, no TDD gate
       STANDARD (logic error, test failure) → full TDD gate before retry
  4. Present diagnosis + proposed fix to developer
  5. Wait for explicit developer approval
  6. Implement fix
  7. Push — EXPLICIT DEVELOPER APPROVAL REQUIRED before every push
  8. Return to poll

  if SAME FAILURE recurs:
    → Must produce a different diagnosis
    → Cannot repeat the same fix
    → Escalate if no new diagnosis is possible

  if MAX RETRIES (3) exceeded:
    → Present full diagnosis history to developer
    → Do not push again without explicit developer instruction
    → Log all attempts in remediation artifact
```

### Artifact Rules

- CI failure on **feature branch** → log in `CODE_REVIEW.md` under
  "CI Remediation" section
- CI failure on **`main`** after squash merge → create standalone artifact:
  `docs/decisions/ci-remediation-{YYYY-MM-DD}-{short-sha}/CI_REMEDIATION.md`

### Hard Rules

- Claude never pushes a retry without explicit developer approval — no exceptions
- Claude never repeats the same fix for the same failure
- After 3 failed attempts, Claude stops and escalates with full diagnosis history
- Monitoring is never skipped — every push is monitored to completion
- `/monitor` command can be invoked manually at any time to check the most
  recent Actions run on any branch

### CI Remediation Log Format

```markdown
### CI Remediation

**Branch:** {branch-name}
**Workflow:** {workflow-name}
**Run URL:** {GitHub Actions run URL}

#### Attempt 1

**Failure:** {step that failed}
**Log excerpt:**
{relevant lines from gh run view --log-failed}

**Diagnosis:** {root cause in plain language}
**Fix classification:** TRIVIAL | STANDARD
**Proposed fix:** {what Claude proposed}
**Developer approval:** YES — {timestamp}
**Fix implemented:** {description of change}
**Result:** SUCCESS | FAILURE

#### Attempt 2 (if needed)

...

#### Final Status

Total attempts: {N}
Resolved: YES | NO
Resolution: {description or ESCALATED TO DEVELOPER}
```

---

## Section 15 — Python Environment Rules

Claude Code spawns a fresh shell process for every bash command. Virtual
environment activation (`source .venv/bin/activate`) does not persist between
commands. These rules are therefore absolute — no exceptions.

### Always use `uv run`

```bash
# CORRECT
uv run python script.py
uv run pytest
uv run mypy src/
uv run ruff check .

# NEVER — resolves to system Python, bypasses the project venv
python script.py
python3 script.py
```

### Always use `uv add` for dependencies

```bash
# CORRECT
uv add requests
uv add --dev pytest

# NEVER — bypasses uv.lock
pip install requests
pip3 install requests
```

### Enforcement layers

The pre_tool_use hook in `.claude/hooks/pre_tool_use.py` blocks bare
`python`, `python3`, `pip`, and `pip3` calls before they execute.
If the hook blocks a command, fix the command using `uv run` and proceed.
The hook is a reminder, not a failure.

`.claude/settings.json` injects `VIRTUAL_ENV` and the venv `bin/` path
into every shell as an additional fallback.

---

## Standing Rules (Always Active)

These apply regardless of gate, path, or task type:

- Never write implementation before a failing test exists (standard changes).
- Never open a code file to write implementation before PLAN.md is agreed.
- Never mark a review complete with unresolved blocking findings.
- Never commit with `--no-verify` without human approval.
- Never assume — always ask.
- Never pick silently between options — always present tradeoffs.
- Never proceed on a natural language trigger without one confirmation step.
- Always state the active gate.
- Always announce the required model at the start of every interactive gate and wait for confirmation.
- Always state which automated tasks use YAML frontmatter routing.
- Always present the plan before executing it.
- Never push a retry without explicit developer approval.
- Never repeat the same fix for the same CI failure — produce a different diagnosis.
- Always monitor every push to completion — never hand off CI monitoring to the developer.
- Always watch main after a squash merge completes.
- Always use /exit to end a session — never signal safe to close without completing the exit sequence.
- Always require /retrospective at next standup if previous session ended without /exit.
- Always start with `/standup` — no task is accepted before standup is acknowledged.
