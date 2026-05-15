# /bugfix — Bug Fix Workflow

Triggered by: `/bugfix "description"`

Load the `workflows` skill and follow the Bug Fix Workflow exactly
(Section 3 of the workflows skill).

## Immediate Actions

1. Announce the workflow:

```
Detected: Bug fix
Workflow: STANDARD — Bug Fix Path
Classification: STANDARD

Starting Gate 1: CLASSIFY (Haiku 4.5 — automatic)
```

2. Classify the bug — state the bug description in plain language,
   confirm it is STANDARD, confirm artifact naming, create the artifact
   folder `docs/decisions/{slug}/`.

3. Announce Gate 2 and model:

```
Gate 2: REPRODUCE
Model: Sonnet 4.6

Please switch to Sonnet 4.6 before we proceed.
Confirm when ready.
```

4. Follow the Bug Fix Workflow step by step from the `workflows` skill.
   The REPRODUCE step comes before any design or planning.

## Rules

- REPRODUCE is never skipped — the failing test is the proof the bug exists
- Do not classify fix complexity until after REPRODUCE
- If the bug description is ambiguous, ask one clarifying question:
  "Can you describe the exact behaviour you're seeing and what you
  expected instead?" before starting
- If the bug has security implications, flag immediately and ensure
  SECURITY REVIEW is thorough
- If the bug is in a shell script, load the `python-cli` shell conventions
  and use bats for the reproducing test
- If the bug is in SQL, load the `python-cli` SQL conventions
