# /feature — Feature Implementation Workflow

Triggered by: `/feature "description"`

Load the `workflows` skill and follow the Feature Workflow exactly
(Section 2 of the workflows skill).

## Immediate Actions

1. Announce the workflow:

```
Detected: Feature implementation
Workflow: STANDARD — Feature Path
Classification: STANDARD

Starting Gate 1: CLASSIFY
```

2. Classify the feature — state it in plain language, confirm it is
   STANDARD, confirm artifact naming (slug or issue number), create
   the artifact folder `docs/decisions/{slug}/`.

3. Branch setup (after slug is confirmed):

   ```bash
   git rev-parse --abbrev-ref HEAD
   ```

   - **On main:** run `git status --short`. If dirty, warn:
     "You have uncommitted changes on main — they'll carry over to the
     new branch. Continue or stash first?" Wait for decision. Then:
     ```bash
     git checkout -b feature/{slug}
     ```
     If that fails (branch exists): `git checkout -b feature/{slug}-{YYYY-MM-DD}`.
     Announce: "Created branch feature/{slug}."

   - **On a non-main branch:** warn: "You're currently on branch
     {branch-name}. Continue here, or shall I create a new branch?"
     Wait for developer decision before proceeding.

4. Announce Gate 2:

```
Gate 2: DESIGN
```

5. Follow the Feature Workflow step by step from the `workflows` skill.
   Do not skip steps. Do not reorder steps.

## Rules

- If the description is ambiguous, ask one clarifying question before
  starting — do not assume scope
- Always complete the full gate sequence before marking the feature done
