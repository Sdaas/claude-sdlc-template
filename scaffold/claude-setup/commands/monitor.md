# /monitor — CI Monitor and Auto-Remediation

Triggered by: workflows skill Steps 11-12 (automatic after push),
or `/monitor` (manual)
Model: Sonnet 4.6

Load the `github-actions` skill Section 10 and follow it exactly.

## Immediate Actions

1. Determine which run to monitor:

```bash
# Current branch run
BRANCH=$(git rev-parse --abbrev-ref HEAD)
RUN_ID=$(gh run list --branch "${BRANCH}" --limit 1 \
  --json databaseId --jq '.[0].databaseId')

echo "Monitoring run ${RUN_ID} on branch ${BRANCH}..."
```

   If invoked manually without context, ask: "Should I monitor the
   current branch (${branch}), main, or a specific run ID?"

2. Monitor until completion:

```bash
gh run watch "${RUN_ID}" --exit-status
```

   Show status updates while waiting. Do not go silent.

3. On SUCCESS:

```
CI passed ✓
Run: {run-url}
Branch: {branch}
All jobs: PASSING
```

   Return to the calling workflow step.

4. On FAILURE — enter auto-remediation loop:

   a. Read failure log:
      `gh run view {run-id} --log-failed`

   b. Diagnose root cause using patterns from `github-actions` skill
      Section 10.

   c. Classify fix: TRIVIAL or STANDARD

   d. Present structured diagnosis:

   ```
   CI Failure Diagnosis
   ────────────────────
   Run ID:      {run-id}
   Run URL:     {url}
   Failed job:  {job-name}
   Failed step: {step-name}

   Root cause:
   {Plain language explanation}

   Relevant log excerpt:
   {5-15 most relevant lines}

   Fix classification: TRIVIAL | STANDARD

   Proposed fix:
   {Specific description of what will change}

   Shall I implement this fix? [y/N]
   ```

   e. Wait for explicit developer approval — YES required to proceed.

   f. Implement fix following the classification:
      - TRIVIAL: implement directly
      - STANDARD: follow TDD gate before implementing

   g. Show diff before pushing.

   h. Ask: "Shall I push this fix? [y/N]"
      Wait for explicit approval.

   i. Push. Return to monitoring.

   j. Track attempt count. After 3 failed attempts:

   ```
   ✗ Maximum remediation attempts reached (3/3).

   Attempt history:
   1. {fix attempted} → {result}
   2. {fix attempted} → {result}
   3. {fix attempted} → {result}

   This requires manual investigation. Do not push further changes
   until the root cause is understood.

   Shall I open the Actions page for manual review?
   ```

5. Log all attempts in:
   - Feature branch: `docs/decisions/{slug}/CODE_REVIEW.md`
     under "CI Remediation" section
   - main branch: `docs/decisions/ci-remediation-{date}-{sha}/CI_REMEDIATION.md`

## Rules

- Never push a retry without explicit developer approval
- Never repeat the same fix for the same failure — produce a different
  diagnosis each attempt
- For transient failures (network timeout, rate limit): retry the run
  via `gh run rerun {run-id}` without a code change
- After 3 failed attempts: stop and escalate — do not push again
- Always log every attempt before moving on
