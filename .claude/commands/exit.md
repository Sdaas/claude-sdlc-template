# /exit — Session Exit Command

When this command is invoked, execute the following sequence completely
and in order. Do not skip any step. Do not signal safe to close until
all steps are complete.

---

## Exit Sequence

### Step 1 — Announce Exit

Say:
"Starting session exit sequence. I will run the retrospective, save
session state, and then signal when it is safe to close."

### Step 2 — Run Retrospective

Load the `retro-protocol` skill and run a full retrospective on this session.
Follow the retro-protocol skill exactly:
- Analyse all four dimensions (Process, Cost, Effectiveness, Communication)
- Present findings to the developer
- Wait for developer to review and add notes to Developer Notes section
- Commit the retrospective artifact

Do not proceed to Step 3 until the retrospective is committed.

### Step 3 — Write SESSION_STATE.md

Write `SESSION_STATE.md` to the project root with the following content.
This file is in `.gitignore` — do not commit it.

```markdown
# Session State

**Saved at:** {YYYY-MM-DD HH:MM:SS UTC}
**Exit type:** GRACEFUL
**Retrospective:** COMPLETE
**Retrospective artifact:** docs/retrospectives/{filename}

---

## Active Work

**Branch:** {current branch name, or "main" if no feature branch}
**Gate:** {current gate, or "NONE — no active feature" if clean}
**Feature slug:** {slug or "none"}

### Open Artifacts

{For each artifact in docs/decisions/ modified since last main commit:}
- {slug}/DESIGN.md — {DRAFT | IN REVIEW | APPROVED}
- {slug}/PLAN.md — {agreed | not yet agreed | N/A}
- {slug}/CODE_REVIEW.md — {N blocking findings unresolved | complete | N/A}

### Uncommitted Changes

{If working directory is clean:}
Working directory clean — nothing uncommitted.

{If changes exist:}
{N} files modified:
{list each file, one per line}

---

## CI Status

**Feature branch ({branch-name}):** {PASSING | FAILING | UNKNOWN | N/A}
**main:** {PASSING | FAILING | UNKNOWN}

{If any CI is FAILING:}
Last failure: {job name} — {one-line summary}

---

## Next Session

**Suggested first action:**
{One specific, actionable sentence describing exactly what to do at the
start of the next session. Be concrete — name the file, gate, or finding.}

**Context for standup:**
{2-3 sentences of context that would help reconstruct session state
quickly at standup. Include anything not obvious from git log or artifacts.}
```

### Step 4 — Final Signal

Say exactly this:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Session exit complete ✓

Retrospective committed:
  docs/retrospectives/{filename}

Session state saved:
  SESSION_STATE.md (local only — not committed)

Next session suggested action:
  {one-line suggested first action}

Type "/quit" to exit claude. 
   Dont run quit, exit or /exit - that will trigger a loop
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Rules

- Never signal safe to close before all four steps are complete
- Never skip the retrospective — even if the session was short or trivial
- Never commit SESSION_STATE.md — it is in .gitignore
- If the retrospective reveals a BLOCKING process issue (e.g. a gate was
  skipped without approval), note it prominently in SESSION_STATE.md
  under "Context for standup" so the next session standup flags it
- The "Suggested first action" in SESSION_STATE.md must be specific —
  never "continue working on the feature"
