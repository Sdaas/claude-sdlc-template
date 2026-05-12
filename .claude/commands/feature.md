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

Starting Gate 1: CLASSIFY (Haiku 4.5 — automatic)
```

2. Classify the feature — state it in plain language, confirm it is
   STANDARD, confirm artifact naming (slug or issue number), create
   the artifact folder `docs/decisions/{slug}/`.

3. Announce Gate 2 and model:

```
Gate 2: DESIGN
Model: Opus 4.6

Please switch to Opus 4.6 before we proceed.
Confirm when ready.
```

4. Follow the Feature Workflow step by step from the `workflows` skill.
   Do not skip steps. Do not reorder steps.

## Rules

- If the description is ambiguous, ask one clarifying question before
  starting — do not assume scope
- If the feature touches SQL, load the `python-cli` skill SQL conventions
- If the feature touches shell scripts, load the `python-cli` shell conventions
- If the feature has Homebrew distribution implications, load the `homebrew` skill
- Always complete the full gate sequence before marking the feature done
