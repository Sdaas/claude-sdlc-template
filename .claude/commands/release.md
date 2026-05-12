# /release — Release Process

Triggered by: `/release` (manual only — never automatic)
Model: Sonnet 4.6 (announce and wait for confirmation)

Load the `release` skill and follow it exactly. Claude acts as co-pilot
while `scripts/release.sh` drives the mechanical execution.

## Immediate Actions

1. Announce model:

```
Starting Release Process (Sonnet 4.6).
Please switch to Sonnet 4.6 before we proceed.
Confirm when ready.
```

2. Present the pre-release checklist from the `release` skill Section 2.
   Go through each item with the developer. Every item must be confirmed
   before proceeding.

3. Present version bump options and recommendation based on commits since
   last release. Wait for developer to select.

4. Confirm:

```
Release version: {NEW_VERSION}
This will:
  - Run the full test suite
  - Bump version in pyproject.toml
  - Update CHANGELOG.md
  - Create git tag v{NEW_VERSION}
  - Trigger GitHub Actions release workflow
  - Update Homebrew formula in tap repo
  - Verify installation via Homebrew

Shall I hand off to release.sh? [y/N]
```

5. On developer confirmation, instruct:

```
Run: ./scripts/release.sh

I will monitor each step and flag anything unexpected.
Tell me the output of each step as it completes.
```

6. Co-pilot through each of the 17 steps in `release.sh`:
   - Explain what each step does before it runs
   - Interpret the output after it completes
   - Flag anything unexpected before the developer confirms the next step
   - If any step fails, diagnose and recommend remediation before proceeding

7. After Step 17 (post-release summary), confirm release is complete
   and trigger retrospective.

## Rules

- Never trigger a release autonomously — always require developer to
  invoke release.sh manually
- Always present the pre-release checklist before anything else
- Always co-pilot interactively — explain each step, interpret output
- If brew audit fails (Step 14), do not proceed — help fix the formula
- If Homebrew installation verification fails (Step 16), the release is
  not complete — diagnose before declaring done
- Record the release version in the session retrospective
