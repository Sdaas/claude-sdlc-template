# /code-review — Code Review and Security Review Dialogue

Triggered by: workflows skill Steps 8-9, or `/code-review` (manual)
Model: Sonnet 4.6 (announce and wait for confirmation)

Load the `code-review` skill and `security` skill. Follow both exactly.
Code review and security review run in the same session — security review
is the final section, not a separate step.

## Immediate Actions

1. Announce model:

```
Starting Code Review + Security Review (Sonnet 4.6).
Please switch to Sonnet 4.6 before we proceed.
Confirm when ready.
```

2. Identify changed files:

```bash
git diff main...HEAD --name-only
```

   If no active feature branch is obvious, ask: "Which branch or
   commit range should I review?"

3. Read every changed file in full before presenting any findings.

4. Run all tool checks and collect output:
   - `uv run ruff check .`
   - `uv run ruff format --check .`
   - `uv run mypy src/`
   - `shellcheck scripts/*.sh` (if shell files changed)
   - `uv run sqlfluff lint sql/` (if SQL files changed)
   - `uv run pip-audit`
   - `uv run ruff check --select S .` (security ruleset)

5. Present ALL code review findings upfront — numbered, BLOCKING /
   NON-BLOCKING. Include tool check failures as findings.

6. Address code review findings one at a time, BLOCKING first.

7. When all code review findings resolved, transition to security review:

```
Code review complete. Starting Security Review.
```

8. Apply the full security checklist from the `security` skill.
   Present ALL security findings upfront.

9. Address security findings one at a time, CRITICAL/HIGH first.

10. Write full dialogue to `docs/decisions/{slug}/CODE_REVIEW.md`
    including the Security Review section.

11. When all BLOCKING findings (code + security) resolved:
    - Update CODE_REVIEW.md with final status
    - Commit CODE_REVIEW.md
    - State: "Code review and security review complete. Ready for COMMIT gate."

## Rules

- Read every changed file before presenting any findings — no surprises
- Run all tool checks — never rely on developer's assertion they pass
- Never pass review with unresolved BLOCKING or CRITICAL findings
- If developer pushes back on a BLOCKING finding, record the disagreement
  — never silently drop a blocking finding
- Security review always runs — even if code review found no issues
- CI remediation log appended here if CI fails after push
