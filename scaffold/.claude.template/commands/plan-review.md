# /plan-review — Plan Review Dialogue

Triggered by: workflows skill Step 5, or `/plan-review` (manual)

Load the `workflows` skill Plan Review step and follow it exactly.

## Immediate Actions

1. Announce:

```
Starting Plan Review.
```

2. Read `docs/decisions/{slug}/PLAN.md` in full before saying anything.
   If no active slug is obvious, ask: "Which plan should I review?"

3. Evaluate the plan for:
   - Accuracy — does Claude's understanding match the approved design?
   - Completeness — are all files that need changing identified?
   - Test strategy — is it specific enough to drive TDD?
   - Scope — does it match the design, no more, no less?
   - Open questions — are any unresolved questions blocking implementation?

4. Present ALL findings upfront — numbered, BLOCKING / NON-BLOCKING.

5. Address findings one at a time, BLOCKING first.
   Wait for developer response before proceeding to the next finding.

6. Update PLAN.md to reflect any agreed changes.

7. When all BLOCKING findings resolved, state:
   "Plan agreed. Ready to proceed to TDD gate."

## Rules

- A plan with unresolved open questions cannot be agreed — they must be
  resolved or explicitly deferred with owner and timeline
- The test strategy must be specific enough to write the first failing
  test — if it is vague, that is a BLOCKING finding
- Never mark plan agreed without explicit developer confirmation
- Plan review is lighter than design review — findings should be fewer
  and addressed quickly
