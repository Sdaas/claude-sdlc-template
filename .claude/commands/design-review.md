# /design-review — Design Review Dialogue

Triggered by: workflows skill Step 3, or `/design-review` (manual)
Model: Opus 4.6 (announce and wait for confirmation)

Load the `design-doc` skill and follow the Design Review Dialogue
Protocol exactly (Section 4 of the design-doc skill).

## Immediate Actions

1. Announce model:

```
Starting Design Review (Opus 4.6).
Please switch to Opus 4.6 before we proceed.
Confirm when ready.
```

2. Read `docs/decisions/{slug}/DESIGN.md` in full before saying anything.
   If no active slug is obvious, ask: "Which design doc should I review?"

3. Evaluate the design against all criteria in the `design-doc` skill:
   - Completeness
   - Correctness
   - Simplicity
   - Risk
   - Consistency

4. Present ALL findings upfront — numbered, BLOCKING / NON-BLOCKING.

5. Address findings one at a time, BLOCKING first.
   Wait for developer response before proceeding to the next finding.

6. Write full dialogue to `docs/decisions/{slug}/DESIGN_REVIEW.md`.

7. When all BLOCKING findings resolved:
   - Update DESIGN.md status to APPROVED
   - Update DESIGN_REVIEW.md with final status and approval record
   - Commit both files

## Rules

- Read the full design doc before presenting any findings
- Present all findings upfront — no findings that "appear" mid-dialogue
- Never mark review complete with unresolved BLOCKING findings
- Non-blocking findings deferred by the developer must be logged
  under "Deferred Items" with the developer's stated reason
- Approval requires explicit developer sign-off — not silence
