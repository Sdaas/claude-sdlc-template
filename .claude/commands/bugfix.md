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

Starting Gate 1: CLASSIFY
```

2. Classify the bug — state the bug description in plain language,
   confirm it is STANDARD, confirm artifact naming, create the artifact
   folder `docs/decisions/{slug}/`.

3. Branch setup (after slug is confirmed):

   ```bash
   git rev-parse --abbrev-ref HEAD
   ```

   - **On main:** run `git status --short`. If dirty, warn:
     "You have uncommitted changes on main — they'll carry over to the
     new branch. Continue or stash first?" Wait for decision. Then:
     ```bash
     git checkout -b fix/{slug}
     ```
     If that fails (branch exists): `git checkout -b fix/{slug}-{YYYY-MM-DD}`.
     Announce: "Created branch fix/{slug}."

   - **On a non-main branch:** warn: "You're currently on branch
     {branch-name}. Continue here, or shall I create a new branch?"
     Wait for developer decision before proceeding.

4. Announce Gate 2:

```
Gate 2: REPRODUCE
```

5. Follow the Bug Fix Workflow step by step from the `workflows` skill.
   The REPRODUCE step comes before any design or planning.

## Rules

- REPRODUCE is never skipped — the failing test is the proof the bug exists
- Do not classify fix complexity until after REPRODUCE
- If the bug description is ambiguous, ask one clarifying question:
  "Can you describe the exact behaviour you're seeing and what you
  expected instead?" before starting
- If the bug has security implications, flag immediately and ensure
  SECURITY REVIEW is thorough
