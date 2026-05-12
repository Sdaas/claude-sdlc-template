# /trivial — Trivial Change Workflow

Triggered by: `/trivial "description"`

Load the `workflows` skill and follow the Trivial Workflow exactly
(Section 4 of the workflows skill).

## Immediate Actions

1. Announce the workflow:

```
Detected: Trivial change
Workflow: TRIVIAL Path
Model: Haiku 4.5 (automatic throughout)
```

2. Confirm the change qualifies as TRIVIAL:
   - Typo, docstring fix, comment update, version bump, or formatting only
   - No logic changes
   - No interface changes
   - No new tests required
   - Can be described in one sentence

3. State: "I will make only this change and nothing else."

4. Follow the Trivial Workflow from the `workflows` skill.

## Rules

- If ANY doubt exists about whether the change is truly trivial,
  default to STANDARD and start `/feature` or `/bugfix` instead
- The surgical change principle applies strictly — touch only what
  was stated, nothing adjacent
- If the diff reveals the change is larger than described, stop
  immediately, reclassify, and restart with the appropriate workflow
- No artifacts are created for trivial changes
- No retrospective is triggered unless the developer requests it
- A CI failure on a trivial change is a signal of possible misclassification —
  flag this to the developer before remediating
