---
name: git-workflow
description: >
  Load this skill for any task involving git operations, branch naming, commit
  messages, pull requests, merge strategy, or git history management. Applies
  to this project.
---

# Git Workflow Conventions

This skill defines the branching strategy, commit conventions, pull request
process, and git history standards for
this project. These conventions are enforced by pre-commit hooks,
pre-push hooks, and GitHub Actions.

---

## 1. Branching Strategy

This project uses a simplified trunk-based development model appropriate
for solo and small-team CLI tool development.

### Branch Structure

```
main                    # production-ready, protected, never committed to directly
├── feature/{slug}      # new features — branched from main, merged via PR
├── fix/{slug}          # bug fixes — branched from main, merged via PR
├── chore/{slug}        # maintenance — deps, tooling, config changes
├── docs/{slug}         # documentation only changes
└── release/{version}   # release preparation — created by release.sh
```

### Branch Naming Rules

- Format: `{type}/{slug}`
- Slug is lowercase, hyphen-separated, derived from the feature description
- Slug matches the artifact folder name in `docs/decisions/`
- Maximum 50 characters total including the type prefix
- No uppercase, no underscores, no special characters except hyphens

```bash
# CORRECT
feature/add-dry-run-flag
fix/config-not-found-on-first-run
chore/upgrade-click-to-8-2
docs/update-contributing-guide

# WRONG
feature/AddDryRunFlag
fix/config_not_found
Feature/add-dry-run
```

### Branch Lifecycle

```bash
# Start a new feature
git checkout main
git pull origin main
git checkout -b feature/{slug}

# Work on the branch through all gates
# ...

# Push and open PR when CODE REVIEW and SECURITY REVIEW pass
git push origin feature/{slug}
# Open PR via GitHub CLI or web UI

# After PR merged — clean up
git checkout main
git pull origin main
git branch -d feature/{slug}
```

### Rules

- Never commit directly to `main` — no exceptions
- `main` is always releasable — every commit on main must pass all CI checks
- Feature branches are short-lived — aim to merge within one session or one day
- Do not accumulate large branches with many unrelated commits — one feature,
  one branch

---

## 2. Commit Conventions

All commits follow the Conventional Commits specification.
Enforced by pre-commit hook.

### Format

```
{type}({scope}): {description}

{optional body}

{optional footer}
```

### Types

| Type       | When to use                                              |
|------------|----------------------------------------------------------|
| `feat`     | A new feature visible to the user                        |
| `fix`      | A bug fix                                                |
| `docs`     | Documentation only — no code changes                     |
| `style`    | Formatting, whitespace — no logic changes                |
| `refactor` | Code restructuring — no feature change, no bug fix       |
| `test`     | Adding or updating tests only                            |
| `chore`    | Build process, dependency updates, tooling               |
| `security` | Security fix — use instead of `fix` for security issues  |
| `release`  | Release preparation — used only by `release.sh`          |

### Scope

Scope is the area of the codebase affected. Use the subcommand name, module
name, or component name. Keep it short.

```
feat(deploy): add --dry-run flag
fix(config): resolve file not found on first run
chore(deps): upgrade click to 8.2.0
test(auth): add parametrized token validation tests
security(input): sanitise file path before read
```

### Description

- Lowercase, imperative mood: "add", "fix", "update", "remove"
- No period at the end
- Maximum 72 characters
- Complete the sentence: "This commit will {description}"

```bash
# CORRECT — imperative, lowercase, no period, meaningful
feat(deploy): add --dry-run flag to simulate deployment
fix(config): create default config on first run if missing
chore(deps): upgrade click from 8.1 to 8.2

# WRONG
feat(deploy): Added dry run flag.    # past tense, has period
fix: fixed it                        # vague, no scope
WIP                                  # not a valid commit
asdf                                 # not a valid commit
```

### Commit Body

Use the body to explain *why*, not *what*. The diff shows what changed.
The body explains the reasoning.

```
fix(config): create default config on first run if missing

Previously the tool exited with an unhelpful error if ~/.config/mytool
did not exist. Users had to know to run `init` first. Now the tool
creates a sensible default config automatically, which is the expected
behaviour for a CLI tool installed via Homebrew.

Closes #42
```

### Breaking Changes

Breaking changes are documented in the footer:

```
feat(auth): replace token file with keychain integration

BREAKING CHANGE: The ~/.config/mytool/token file is no longer used.
Existing tokens must be migrated by running `mytool auth migrate`.
```

### Commit Atomicity

One commit = one logical change. Ask: "If I revert this commit, does exactly
one thing change?" If the answer is no, split the commit.

```bash
# Split a commit that does two things
git add src/package/core/auth.py tests/unit/core/test_auth.py
git commit -m "feat(auth): add token validation"

git add src/package/commands/login.py tests/unit/commands/test_login.py
git commit -m "feat(login): wire token validation into login command"
```

---

## 3. Commit Message Generation (Automated)

Commit messages for routine commits are generated by Claude using Haiku 4.5
via the `git-workflow` command. The command reads the staged diff and produces
a Conventional Commits-compliant message.

The developer reviews and approves the message before the commit is made.
Claude never commits autonomously.

```bash
# Generate a commit message for staged changes
/commit

# Claude reads: git diff --staged
# Claude produces: type(scope): description + optional body
# Developer approves or edits
# Developer runs: git commit -m "{approved message}"
```

---

## 4. Pull Request Conventions

### PR Title

Same format as a commit message: `{type}({scope}): {description}`

The PR title becomes the squash commit message on merge.

### PR Description Template

```markdown
## Summary

{What this PR does in 2-3 sentences.}

## Changes

- {Bullet list of significant changes}
- {One bullet per logical change}

## Testing

- [ ] Unit tests pass: `uv run pytest -m unit`
- [ ] Integration tests pass: `uv run pytest -m integration`
- [ ] Shell tests pass: `bats tests/shell/`
- [ ] Coverage at or above threshold
- [ ] Ruff passes: `uv run ruff check .`
- [ ] Mypy passes: `uv run mypy src/`
- [ ] Shellcheck passes (if shell scripts changed)
- [ ] Sqlfluff passes (if SQL changed)

## Artifacts

- [ ] `docs/decisions/{slug}/DESIGN.md` committed
- [ ] `docs/decisions/{slug}/DESIGN_REVIEW.md` committed
- [ ] `docs/decisions/{slug}/PLAN.md` committed
- [ ] `docs/decisions/{slug}/CODE_REVIEW.md` committed (includes security review)

## Related Issues

Closes #{issue-number}
```

### PR Rules

- One PR per feature or bug fix — matches one artifact folder
- PR must pass all CI checks before merge — no exceptions
- PR must have at least the CODE_REVIEW.md artifact committed
- Squash merge is the default — preserves clean linear history on `main`
- Delete the branch after merge

---

## 5. Merge Strategy

**Default: Squash merge**

All PRs are squash-merged into `main`. This produces one clean commit per
feature or bug fix on `main`, regardless of how many intermediate commits
were on the feature branch.

The squash commit message is the PR title — which follows Conventional Commits
format. This means `main`'s git log is a clean, readable history of features
and fixes.

```
main log after several features:
feat(deploy): add --dry-run flag
fix(config): create default config on first run
feat(auth): add token validation
chore(deps): upgrade click to 8.2
```

**Exception: Release commits**

Release commits (`release/{version}`) are merged with a regular merge commit,
not squashed. This preserves the release boundary in the history.

---

## 6. Git History Rules

- Never force-push to `main` — no exceptions
- Force-push to feature branches is acceptable before PR is opened, never after
- Never rewrite history that has been pushed to a shared branch
- Merge commits are only permitted for release branches
- `git bisect` must work — every commit on `main` must be in a working state

### Cleaning Up Before PR

Before opening a PR, clean up the feature branch:

```bash
# Rebase onto latest main
git fetch origin
git rebase origin/main

# If you have messy intermediate commits, squash them interactively
git rebase -i origin/main

# Check the result
git log origin/main..HEAD --oneline
```

---

## 7. Tag Conventions

Tags are created exclusively by `release.sh`. Never create release tags manually.

```
v{MAJOR}.{MINOR}.{PATCH}   # e.g. v1.2.3
```

- Tags are annotated, not lightweight:

```bash
git tag -a v1.2.3 -m "Release v1.2.3"
```

- Tags are pushed explicitly:

```bash
git push origin v1.2.3
```

- Never delete or move a published tag — create a new release instead

---

## 8. .gitignore Standards

Every project includes these in `.gitignore`:

```gitignore
# Python
__pycache__/
*.py[cod]
*.pyo
*.pyd
.Python
*.egg-info/
dist/
build/
.eggs/

# uv / virtualenv
.venv/
venv/

# Testing and coverage
.pytest_cache/
.coverage
coverage.xml
htmlcov/

# mypy
.mypy_cache/

# ruff
.ruff_cache/

# Environment
.env
.env.local
*.env

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Editor
.idea/
.vscode/
*.swp
*.swo
*~

# Session state — operational, not history
SESSION_STATE.md

# Temporary files
tmp/
temp/
*.tmp

# Distribution
dist/
*.whl
*.tar.gz
```

---

## 9. Post-Push Monitoring

Every `git push` is immediately followed by CI monitoring. This is mandatory
and never handed off to the developer.

```bash
# After every push — get the run ID and monitor
RUN_ID=$(gh run list --branch $(git rev-parse --abbrev-ref HEAD) \
  --limit 1 --json databaseId --jq '.[0].databaseId')

gh run watch "${RUN_ID}" --exit-status
```

If CI fails, Claude enters the auto-remediation loop defined in CLAUDE.md
Section 14 and the `github-actions` skill Section 10.

After a squash merge to `main`, Claude also monitors the `main` CI run:

```bash
# Monitor main after merge
RUN_ID=$(gh run list --branch main --limit 1 --json databaseId \
  --jq '.[0].databaseId')

gh run watch "${RUN_ID}" --exit-status
```

A push is not considered complete until CI passes. Claude never moves to the
next workflow gate while CI is still running or has failed.

---

## 10. What Claude Must Do With This Skill

When performing any git-related task:

- Never commit directly to `main` — always work on a feature or fix branch
- Always generate commit messages using Haiku 4.5 via `/commit` — never
  write them without the command
- Always present the generated commit message for developer approval before
  committing — Claude never runs `git commit` autonomously
- Flag any vague commit message (e.g. "wip", "fix", "asdf") as BLOCKING
  in code review
- Flag any debug-style commits in the branch history as NON-BLOCKING —
  recommend squashing before PR
- Ensure the artifact folder slug matches the branch name slug
- Remind the developer to delete the branch after merge
- Never use `--no-verify` without explicit developer approval logged in the session
- Flag any `git push --force` to a shared branch as a BLOCKING concern
