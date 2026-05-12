---
name: standup
description: >
  Load this skill at the start of every session. Defines what Claude reads,
  how it interprets session state, and how it structures the standup summary.
  Triggered automatically at session start and by the /standup command.
  Uses Haiku 4.5 via YAML frontmatter routing.
model: claude-haiku-4-5
---

# Standup Convention

This skill defines the session startup process for all projects built from
claude-sdlc-template. The standup runs at the start of every session before
any task is accepted. Its purpose is to reconstruct the full project state
so Claude can act as an informed co-pilot from the first message, not after
several minutes of catch-up.

Uses Haiku 4.5 — lightweight, fast, no Opus-level reasoning needed here.

---

## 1. When Standup Runs

- Automatically at the start of every Claude Code session
- When the developer invokes `/standup` manually
- Never skipped — Claude does not accept a task until standup is acknowledged

---

## 2. What Claude Reads

Claude reads the following sources in order. All reads happen before any
output is produced.

### 2.1 Git Log (Last 10 Commits on main)

```bash
git log main --oneline -10
```

Tells Claude what has been completed recently and when the last release was.

### 2.2 Current Branch

```bash
git rev-parse --abbrev-ref HEAD
git log main..HEAD --oneline --no-merges
```

Tells Claude what feature or fix is in progress and how many commits it has.

### 2.3 Working Directory Status

```bash
git status --short
git diff --stat
```

Tells Claude if there are uncommitted changes and which files are modified.

### 2.4 Open Decision Artifacts

```bash
find docs/decisions/ -name "*.md" -newer .git/refs/heads/main 2>/dev/null | sort
```

Claude reads every artifact in `docs/decisions/` that has been modified
since the last main commit. For each artifact folder found:

- Read `DESIGN.md` — check status field (DRAFT / IN REVIEW / APPROVED)
- Read `PLAN.md` — check if plan is agreed
- Read `CODE_REVIEW.md` — check for unresolved findings or open CI remediation
- Read `DESIGN_REVIEW.md` — check for unresolved findings

### 2.5 CI Status

```bash
# Most recent run on current branch
gh run list --branch $(git rev-parse --abbrev-ref HEAD) --limit 1 \
  --json status,conclusion,name,url \
  --jq '.[0] | "Status: \(.status) | Conclusion: \(.conclusion) | \(.name) | \(.url)"'

# Most recent run on main
gh run list --branch main --limit 1 \
  --json status,conclusion,name,url \
  --jq '.[0] | "Status: \(.status) | Conclusion: \(.conclusion) | \(.name) | \(.url)"'
```

### 2.6 Open Retrospectives

```bash
ls docs/retrospectives/ 2>/dev/null | tail -3
```

Claude notes the date of the most recent retrospective and any recurring
recommendations that appeared in the last two retrospectives.

---

## 3. State Interpretation Rules

Claude interprets what it reads against these rules to determine session state.

### Active Gate Detection

Claude determines the current gate for any in-progress standard change by
reading the artifact state:

| Artifact state                                           | Current gate         |
|----------------------------------------------------------|----------------------|
| DESIGN.md exists, status = DRAFT                         | DESIGN               |
| DESIGN.md exists, status = IN REVIEW                     | DESIGN REVIEW        |
| DESIGN.md approved, PLAN.md missing or not agreed        | PLAN                 |
| PLAN.md exists, no test files added yet                  | TDD                  |
| Test files exist, implementation incomplete              | CODE                 |
| Implementation complete, CODE_REVIEW.md missing          | CODE REVIEW          |
| CODE_REVIEW.md exists, blocking findings unresolved      | CODE REVIEW          |
| CODE_REVIEW.md complete, CI failing                      | CI REMEDIATION       |
| CI passing, not yet merged to main                       | READY TO MERGE       |
| Merged to main, main CI running                          | MONITORING MAIN      |

### Blocked State Detection

Claude flags a task as BLOCKED if any of the following are true:

- DESIGN_REVIEW.md or CODE_REVIEW.md has unresolved BLOCKING findings
- CI has been failing for more than 3 remediation attempts
- PLAN.md has unresolved open questions
- A merge conflict exists in the working directory

### Stale Branch Detection

A branch is stale if:

- It has not been committed to in more than 2 calendar days
- It is more than 10 commits behind main

Claude flags stale branches and recommends rebasing before continuing.

---

## 4. Standup Summary Format

Claude presents one clean, structured summary. No raw command output.
No walls of text. The summary is scannable in under 30 seconds.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Session Standup — {project-name}
{YYYY-MM-DD HH:MM}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RECENTLY COMPLETED
  {commit message 1}  ({N} days ago)
  {commit message 2}  ({N} days ago)
  Last release: v{version} on {date}   ← omit if no releases yet

IN PROGRESS
  Branch:  {branch-name}
  Gate:    {current gate}
  Commits: {N} commits ahead of main
  Status:  {ON TRACK | BLOCKED | STALE}

  {If BLOCKED}: Blocked on: {reason}
  {If STALE}:   Last commit: {N} days ago — recommend rebase before continuing

OPEN ARTIFACTS
  {slug}/DESIGN.md        — {status}
  {slug}/CODE_REVIEW.md   — {N} blocking findings unresolved   ← if applicable
  {slug}/PLAN.md          — {agreed | not yet agreed}

CI STATUS
  {branch-name}: {PASSING | FAILING | IN PROGRESS | UNKNOWN}
  main:          {PASSING | FAILING | IN PROGRESS | UNKNOWN}
  {If FAILING}: Last failure: {job name} — {one line summary}

UNCOMMITTED CHANGES
  {N} files modified   ← omit if working directory is clean
  {list of changed files, max 5}

RETROSPECTIVE NOTE
  Last retrospective: {date}
  Recurring recommendation: {most recent recurring item}  ← omit if none

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUGGESTED FIRST ACTION
  {One clear, specific suggestion based on the state above}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Suggested First Action Rules

The suggested first action must be specific and immediately actionable.
Never vague. Never more than two sentences.

| State                              | Suggested action                                      |
|------------------------------------|-------------------------------------------------------|
| DESIGN gate                        | "Continue writing DESIGN.md — currently at DRAFT"     |
| DESIGN REVIEW gate                 | "Resume design review — Finding 2 is next"            |
| PLAN gate                          | "Write PLAN.md for {slug} before opening any files"   |
| TDD gate                           | "Write the next failing test for {feature}"           |
| CODE gate                          | "Implement enough to pass the failing test"           |
| CODE REVIEW with blocking findings | "Resolve blocking finding N: {title}"                 |
| CI REMEDIATION                     | "Diagnose CI failure on {branch} — {job} failed"      |
| READY TO MERGE                     | "Open a PR for {branch} — all gates passed"           |
| MONITORING MAIN                    | "Monitor main CI run — {status}"                      |
| Nothing in progress                | "Start a new task with /feature or /bugfix"           |
| BLOCKED                            | "Resolve: {specific blocker} before proceeding"       |
| STALE branch                       | "Rebase {branch} onto main before continuing"         |

---

## 5. Edge Cases

### Abrupt Exit Detection (No /exit Used)

At standup, Claude checks for a missing retrospective from the previous session:

```bash
# Check if last session ended gracefully
# SESSION_STATE.md exists but no matching retrospective artifact
LAST_STATE_DATE=$(grep "Saved at:" SESSION_STATE.md 2>/dev/null | head -1)
LAST_RETRO=$(ls docs/retrospectives/ 2>/dev/null | tail -1)
```

If `SESSION_STATE.md` exists with `Exit type: ABRUPT` or if there is no
`SESSION_STATE.md` at all and the last retrospective predates the last commit:

Claude surfaces this prominently at the top of the standup summary:

```
⚠ PENDING RETROSPECTIVE
  Last session ended without /exit — no retrospective was written.
  You must run /retrospective before starting any new task.
  This is required, not optional.
```

Claude does not present the suggested first action and does not accept
any task until the developer runs `/retrospective` and it is committed.

### SESSION_STATE.md Detection

Claude reads `SESSION_STATE.md` from the project root if it exists.
If present, the "suggested first action" from the previous session is
surfaced at the top of the standup summary as additional context.

```
PREVIOUS SESSION SUGGESTED:
  {next action from SESSION_STATE.md}
```

This is shown before the current standup analysis so the developer can
immediately see where they left off.

No git history, no artifacts, no CI runs. Claude presents:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Session Standup — {project-name}
{date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NEW PROJECT — no history yet.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUGGESTED FIRST ACTION
  Start your first feature with: /feature "description"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### GitHub CLI Not Available

If `gh` is not authenticated or not installed, skip CI status section and note:

```
CI STATUS
  Unavailable — GitHub CLI not authenticated.
  Run: gh auth login
```

### Multiple Features In Progress

If multiple feature branches exist, list them all under IN PROGRESS and
identify which one is furthest along. Suggest the furthest-along branch
as the first action unless it is blocked.

---

## 6. Acknowledgement

Claude does not accept a task until the developer acknowledges the standup.
Acceptable acknowledgements:

- "ok", "got it", "continue", "let's go", "understood"
- Any message that directly starts a task ("let's work on the CI failure")
- Any `/command` invocation

If the developer's first message is a task request without acknowledging
standup, Claude presents the standup first, then says:
"Standup above — shall I proceed with {task}?"

---

## 7. What Claude Must Do With This Skill

- Always use Haiku 4.5 — this is a lightweight read-and-summarise task
- Always read all six sources before producing any output
- Never show raw command output — always interpret and summarise
- Always produce the suggested first action — never leave it blank
- Never accept a task before the developer acknowledges the standup
- Keep the summary scannable — flag anything that needs immediate attention
  at the top, not buried in the middle
- If CI is failing, always surface it prominently — never bury it under
  artifact status
- If a branch is stale, always flag it — stale branches accumulate conflicts
