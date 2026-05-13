---
name: release
description: >
  Load this skill for any task involving the release process, version bumping,
  changelog generation, git tagging, GitHub release creation, or Homebrew
  formula updates. Triggered by the /release command. Claude acts as co-pilot
  while release.sh drives the mechanical execution.
---

# Release Process Conventions

This skill defines the complete release process for
this project. The release is driven by `scripts/release.sh`, which
runs interactively. Claude acts as co-pilot: explaining each step, interpreting
output, and flagging problems before they become incidents.

Uses Sonnet 4.6.

---

## 1. Release Philosophy

- Releases are always triggered by a human — never autonomously by Claude or CI
- Every release starts from a clean, passing `main` branch
- The release script asks questions before executing — it never assumes
- Every step is confirmed by the developer before execution
- The script is idempotent where possible — safe to re-run if interrupted
- A release is not complete until Homebrew installation is verified on macOS

---

## 2. Pre-Release Checklist

Before invoking `release.sh`, the developer and Claude verify:

- [ ] All features intended for this release are merged to `main`
- [ ] `main` CI is green — all checks passing
- [ ] No unresolved issues tagged for this milestone
- [ ] `CHANGELOG.md` entries are accurate and complete
- [ ] Version number follows semantic versioning rules (see Section 3)
- [ ] Developer has push access to both the project repo and the tap repo
- [ ] Homebrew tap repo is accessible locally (see DEVELOPER_GUIDE.md)

Claude presents this checklist interactively before the developer invokes
the script. Developer confirms each item.

---

## 3. Semantic Versioning Rules

Format: `MAJOR.MINOR.PATCH`

| Change type                              | Version bump |
|------------------------------------------|--------------|
| Breaking change to CLI interface or API  | MAJOR        |
| New feature, backward compatible         | MINOR        |
| Bug fix, backward compatible             | PATCH        |
| Security fix                             | PATCH        |
| Documentation or tooling only            | No release needed |

Rules:
- `0.x.x` — initial development, anything may change
- `1.0.0` — first stable release, semver contract begins
- Never skip versions — increment by one
- MAJOR bump resets MINOR and PATCH to zero: `1.4.3` → `2.0.0`
- MINOR bump resets PATCH to zero: `1.4.3` → `1.5.0`

Claude presents the version bump options and recommendation based on the
changes in this release. Developer makes the final decision.

---

## 4. Release Sequence

This is the exact sequence `release.sh` follows. Every step pauses for
developer confirmation before executing.

```
Step 1:  Verify prerequisites
Step 2:  Show changes since last release
Step 3:  Determine and confirm version bump
Step 4:  Run full test suite
Step 5:  Update version in pyproject.toml
Step 6:  Update CHANGELOG.md
Step 7:  Commit version bump and changelog
Step 8:  Create and push annotated git tag
Step 9:  Trigger GitHub Actions release workflow
Step 10: Wait for GitHub release to be created
Step 11: Compute sha256 of release tarball
Step 12: Generate Homebrew resource blocks
Step 13: Update Homebrew formula
Step 14: Run brew audit on updated formula
Step 15: Commit and push formula update to tap repo
Step 16: Verify Homebrew installation
Step 17: Post-release summary
```

---

## 5. Step-by-Step Specification

### Step 1 — Verify Prerequisites

```bash
# Check we are on main
# Check main is clean (no uncommitted changes)
# Check main is up to date with origin
# Check GitHub CLI is authenticated
# Check tap repo is accessible
# Check uv is available
# Check brew is available (macOS only)
```

Fails hard if any prerequisite is not met. Provides clear remediation instructions.

### Step 2 — Show Changes Since Last Release

```bash
# Get last release tag
LAST_TAG=$(git describe --tags --abbrev=0)

# Show commits since last tag
git log "${LAST_TAG}..HEAD" --oneline --no-merges

# Show changed files
git diff "${LAST_TAG}..HEAD" --stat
```

Developer reviews the changes and confirms they are ready for release.

### Step 3 — Determine Version Bump

Script presents:
- Current version from `pyproject.toml`
- Commit types since last release (feat/fix/breaking)
- Recommended bump based on Conventional Commits analysis
- Three choices: MAJOR / MINOR / PATCH

Developer selects the bump. Script computes and displays the new version.
Developer confirms before proceeding.

### Step 4 — Run Full Test Suite

```bash
uv sync --frozen
uv run pytest
uv run ruff check .
uv run ruff format --check .
uv run mypy src/
shellcheck scripts/*.sh    # if shell scripts exist
sqlfluff lint sql/         # if SQL files exist
uv run pip-audit
```

All checks must pass. Script aborts if any check fails.
Developer is shown the full output. Must confirm before proceeding.

### Step 5 — Update Version in pyproject.toml

```bash
# Update version field
sed -i '' "s/^version = .*/version = \"${NEW_VERSION}\"/" pyproject.toml

# Verify the change
grep "^version" pyproject.toml
```

Developer confirms the change looks correct.

### Step 6 — Update CHANGELOG.md

Script opens `CHANGELOG.md` in `$EDITOR` with a pre-populated template:

```markdown
## [${NEW_VERSION}] — ${DATE}

### Added
{feat commits go here}

### Fixed
{fix commits go here}

### Security
{security commits go here}

### Changed
{other commits go here}
```

Commit messages since last tag are pre-populated under the appropriate headings.
Developer edits, saves, and closes the editor.
Script displays the diff and asks for confirmation.

### Step 7 — Commit Version Bump and Changelog

```bash
git add pyproject.toml CHANGELOG.md
git commit -m "release: bump version to ${NEW_VERSION}"
git push origin main
```

Developer confirms before commit and before push separately.

### Step 8 — Create and Push Annotated Tag

```bash
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
git push origin "v${NEW_VERSION}"
```

Developer confirms. Script displays the tag before pushing.

### Step 9 — Trigger GitHub Actions Release Workflow

Pushing the tag automatically triggers `release.yml` in GitHub Actions.
The release workflow runs four jobs in sequence:

```
validate-tag   Confirms tag version matches pyproject.toml version
build          Runs full test suite, builds wheel and sdist
release        Creates GitHub Release and uploads artifacts
verify         Installs via Homebrew on macOS and verifies version
```

Script opens the Actions URL in the browser:

```bash
gh run list --workflow=release.yml --limit=1
open "https://github.com/{org}/{project-name}/actions/workflows/release.yml"
```

### Step 10 — Wait for GitHub Release to Be Created

Script polls until the GitHub release is created by the Actions workflow:

```bash
while ! gh release view "v${NEW_VERSION}" &>/dev/null; do
    echo "Waiting for GitHub release to be created..."
    sleep 15
done
echo "GitHub release v${NEW_VERSION} is live."
```

Timeout after 10 minutes with a clear error message if the release workflow fails.

### Step 11 — Compute sha256 of Release Tarball

```bash
TARBALL_URL="https://github.com/{org}/{project-name}/archive/refs/tags/v${NEW_VERSION}.tar.gz"
SHA256=$(curl -sL "${TARBALL_URL}" | shasum -a 256 | cut -d' ' -f1)
echo "sha256: ${SHA256}"
```

Developer confirms the sha256 looks like a valid hash (64 hex characters).

### Step 12 — Generate Homebrew Resource Blocks

```bash
# Export runtime dependencies in pip-compatible format
uv export --no-dev --format requirements-txt > /tmp/requirements.txt

# Generate resource blocks using poet
poet -r /tmp/requirements.txt

# Clean up
rm /tmp/requirements.txt
```

Script displays the resource blocks. Developer reviews before proceeding.

### Step 13 — Update Homebrew Formula

```bash
# Pull latest tap repo
cd "${TAP_REPO_PATH}"
git checkout main
git pull origin main

# Update the formula
# - Replace sha256 value
# - Replace resource blocks
# - Verify url tag matches new version
```

Script displays the full diff of the formula changes.
Developer confirms before proceeding.

### Step 14 — Run brew audit on Updated Formula

```bash
cd "${TAP_REPO_PATH}"
brew audit --strict Formula/{project-name}.rb
```

Must pass with zero warnings and zero errors.
Script aborts if audit fails. Developer fixes formula and re-runs from Step 13.

### Step 15 — Commit and Push Formula Update

```bash
cd "${TAP_REPO_PATH}"
git add Formula/{project-name}.rb
git commit -m "feat({project-name}): release v${NEW_VERSION}"
git push origin main
```

Developer confirms before commit and before push separately.

### Step 16 — Verify Homebrew Installation

```bash
brew update
brew tap {org}/tools
brew install {project-name}

# Verify version matches
INSTALLED_VERSION=$({project-name} --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
if [ "${INSTALLED_VERSION}" != "${NEW_VERSION}" ]; then
    echo "ERROR: Installed version ${INSTALLED_VERSION} does not match release ${NEW_VERSION}"
    exit 1
fi

# Run brew's test block
brew test {project-name}

# Clean up
brew uninstall {project-name}
```

This step runs on macOS only. On other platforms, script prints instructions
for manual verification.

### Step 17 — Post-Release Summary

Script prints a release summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Release v${NEW_VERSION} complete ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

GitHub release:   https://github.com/{org}/{project-name}/releases/tag/v${NEW_VERSION}
Homebrew install: brew tap {org}/tools && brew install {project-name}
sha256:           ${SHA256}
Tag:              v${NEW_VERSION}
Released at:      $(date -u +"%Y-%m-%dT%H:%M:%SZ")

Next steps:
  - Announce the release if applicable
  - Close the milestone on GitHub
  - Update any related documentation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 6. Interruption and Recovery

If `release.sh` is interrupted at any step, it can be safely re-run.
The script detects its current state and resumes from the last incomplete step.

State is tracked in a temporary file: `/tmp/.release-state-{project-name}`
This file is removed on successful completion.

If the script detects an inconsistent state (e.g. tag exists but formula not
updated), it presents the state clearly and asks the developer how to proceed:
continue, abort, or reset.

---

## 7. CHANGELOG.md Format

```markdown
# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.3] — 2026-05-11

### Added
- feat(deploy): add --dry-run flag to simulate deployment without executing

### Fixed
- fix(config): create default config on first run if missing

### Security
- security(input): sanitise file paths before read to prevent path traversal

## [1.2.2] — 2026-04-01

...

[Unreleased]: https://github.com/{org}/{project-name}/compare/v1.2.3...HEAD
[1.2.3]: https://github.com/{org}/{project-name}/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/{org}/{project-name}/compare/v1.2.1...v1.2.2
```

---

## 8. What Claude Must Do With This Skill

When co-piloting a release:

- Always use Sonnet 4.6
- Always present the pre-release checklist and get confirmation on every item
  before the developer invokes `release.sh`
- Always present and explain the version bump options — never choose silently
- Watch the output of every step and flag anything unexpected before the
  developer confirms the next step
- If any step fails, explain what failed, why it likely failed, and the
  recommended remediation before asking the developer how to proceed
- Never encourage skipping a step — every step exists for a reason
- If brew audit fails, do not proceed — help the developer fix the formula first
- If the Homebrew installation verification fails, the release is not complete —
  flag this clearly and help diagnose
- Record the release in the session — the retrospective should note
  the release version and any issues encountered
