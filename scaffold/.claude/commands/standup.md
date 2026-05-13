# /standup — Session Startup Summary

Triggered by: session start (automatic) or `/standup` (manual)
Model: Haiku 4.5 (YAML frontmatter — automatic)

Load the `standup` skill and follow it exactly.

## Immediate Actions

1. Check for abrupt exit from previous session:
   - Read `SESSION_STATE.md` from project root if it exists
   - If `Exit type: ABRUPT` or SESSION_STATE.md missing and last
     retrospective predates last commit:

```
⚠ PENDING RETROSPECTIVE
  Last session ended without /exit — no retrospective was written.
  Run /retrospective before starting any new task.
  This is required, not optional.
```

   Do not proceed with standup or accept any task until
   `/retrospective` is run and committed.

2. If no pending retrospective, read all six sources defined in
   the `standup` skill before producing any output.

3. Present the standup summary in the format defined by the
   `standup` skill — scannable, structured, one suggested first action.

4. If `SESSION_STATE.md` exists with a suggested next action from the
   previous session, surface it at the top before the current summary.

5. Wait for developer acknowledgement before accepting any task.

## Rules

- Never show raw command output — always interpret and summarise
- Always produce a suggested first action — never leave it blank
- Never accept a task before the standup is acknowledged
- If GitHub CLI is unavailable, skip CI status and note why
- Keep the summary scannable — CI failures and blockers at the top
