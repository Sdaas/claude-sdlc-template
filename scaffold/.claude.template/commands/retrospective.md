# /retrospective — Session Retrospective

Triggered by: `/exit` sequence (automatic) or `/retrospective` (manual)

Load the `retro-protocol` skill and follow it exactly.

## Immediate Actions

1. Announce:

```
Starting session retrospective.
Reading session transcript and recent artifacts...
```

2. Read the last two retrospective artifacts from
   `docs/retrospectives/` before writing anything — check for
   recurring patterns.

3. Analyse the full session across all four dimensions:
   - Process
   - Cost
   - Effectiveness
   - Communication

4. Write the retrospective artifact to:
   `docs/retrospectives/{YYYY-MM-DD}-{slug}.md`
   following the format in the `retro-protocol` skill exactly.

5. Present the retrospective to the developer.

6. Say: "Please review the findings and add any notes to the
   Developer Notes section. I'll commit once you're ready."

7. Wait for developer acknowledgement and any additions to
   Developer Notes.

8. Commit the retrospective:
   `docs(retrospective): add session retrospective {YYYY-MM-DD}`

9. If triggered by `/exit`: return to the exit command sequence
   (Step 3 — write SESSION_STATE.md).
   If triggered manually: confirm completion and await next task.

## Rules

- Always analyse all four dimensions — never skip one
- Always include at least one POSITIVE finding per dimension
- Always produce exactly three top recommendations
- Always leave Developer Notes blank — developer fills it in
- Never commit retrospective without developer acknowledgement
- Flag any UNCHANGED recurring pattern appearing 3+ times —
  recommend a structural fix in CLAUDE.md or a skill
- If this is the first retrospective (no previous ones exist),
  omit the Recurring Patterns section entirely
