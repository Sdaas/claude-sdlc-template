---
name: github-actions
description: >
  Load this skill for any task involving GitHub Actions workflows, CI/CD
  pipeline configuration, workflow security, job structure, or automated
  gates. Applies to all projects built from claude-sdlc-template.
---

# GitHub Actions Conventions

This skill defines the CI/CD pipeline structure, workflow conventions, security
standards, and job organisation for all projects built from claude-sdlc-template.
GitHub Actions is the automated gate enforcer — it runs the checks that pre-commit
and pre-push hooks run locally, plus additional checks that only make sense in CI.

---

## 1. Workflow Overview

Three workflows cover the full lifecycle. All three are in `.github/workflows/`:

```
ci.yml          Runs on every push to feature branches and every PR to main
release.yml     Runs when release.sh pushes a v*.*.* tag to main
security.yml    Runs weekly (Monday 09:00 UTC) and on every PR to main
```

### When Each Workflow Triggers

| Event                          | ci.yml | release.yml | security.yml |
|-------------------------------|--------|-------------|--------------|
| Push to feature branch        | ✓      |             |              |
| Pull request to main          | ✓      |             | ✓            |
| Push of v*.*.* tag            |        | ✓           |              |
| Weekly schedule (Mon 09 UTC)  |        |             | ✓            |
| Manual trigger                |        |             | ✓            |

---

## 2. CI Workflow (`ci.yml`)

Runs on every push to a feature branch and every PR targeting `main`.
This is the primary quality gate.

```yaml
name: CI

on:
  push:
    branches-ignore:
      - main          # main is only updated via squash merge from PRs
  pull_request:
    branches:
      - main

permissions:
  contents: read      # minimum required — read only

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4 pinned to SHA
        with:
          persist-credentials: false

      - name: Install uv
        uses: astral-sh/setup-uv@f0ec1fc3b38f5e7cd731bb6ce540c88dd8fabb67  # pinned
        with:
          version: "latest"
          enable-cache: true

      - name: Set up Python
        run: uv python install 3.11

      - name: Install dependencies
        run: uv sync --frozen

      - name: Ruff lint
        run: uv run ruff check .

      - name: Ruff format check
        run: uv run ruff format --check .

      - name: Mypy
        run: uv run mypy src/

      - name: Shellcheck
        run: |
          if find scripts/ -name "*.sh" | grep -q .; then
            shellcheck scripts/*.sh
          else
            echo "No shell scripts found — skipping shellcheck"
          fi

      - name: Sqlfluff
        run: |
          if [ -d "sql/" ] && find sql/ -name "*.sql" | grep -q .; then
            uv run sqlfluff lint sql/
          else
            echo "No SQL files found — skipping sqlfluff"
          fi

  test:
    name: Test
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.11", "3.12", "3.13"]
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          persist-credentials: false

      - name: Install uv
        uses: astral-sh/setup-uv@f0ec1fc3b38f5e7cd731bb6ce540c88dd8fabb67
        with:
          version: "latest"
          enable-cache: true

      - name: Set up Python ${{ matrix.python-version }}
        run: uv python install ${{ matrix.python-version }}

      - name: Install dependencies
        run: uv sync --frozen

      - name: Run unit tests
        run: uv run pytest -m unit --cov --cov-report=xml

      - name: Run integration tests
        run: uv run pytest -m integration

      - name: Run shell tests
        run: |
          if [ -d "tests/shell/" ] && find tests/shell/ -name "*.bats" | grep -q .; then
            bats tests/shell/
          else
            echo "No bats tests found — skipping"
          fi

      - name: Upload coverage report
        uses: codecov/codecov-action@v4
        with:
          file: ./coverage.xml
          fail_ci_if_error: false

  audit:
    name: Dependency Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          persist-credentials: false

      - name: Install uv
        uses: astral-sh/setup-uv@f0ec1fc3b38f5e7cd731bb6ce540c88dd8fabb67
        with:
          version: "latest"
          enable-cache: true

      - name: Install dependencies
        run: uv sync --frozen

      - name: pip-audit
        run: uv run pip-audit

  formula-audit:
    name: Homebrew Formula Audit
    runs-on: macos-latest
    if: hashFiles('Formula/*.rb') != ''
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          persist-credentials: false

      - name: Audit Homebrew formula
        run: brew audit --strict Formula/*.rb
```

---

## 3. Release Workflow (`release.yml`)

Triggered exclusively when `release.sh` pushes a version tag to `main`.
Never triggered manually or by a branch push.

```yaml
name: Release

on:
  push:
    tags:
      - "v*.*.*"       # matches v1.2.3, v0.1.0, etc.

permissions:
  contents: write      # needed to create GitHub Release
  id-token: write      # needed for PyPI trusted publishing if used

jobs:
  validate-tag:
    name: Validate Tag
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          persist-credentials: false

      - name: Validate tag matches pyproject.toml version
        run: |
          TAG_VERSION="${GITHUB_REF_NAME#v}"   # strip leading 'v'
          TOML_VERSION=$(grep '^version' pyproject.toml | sed 's/version = "\(.*\)"/\1/')
          if [ "$TAG_VERSION" != "$TOML_VERSION" ]; then
            echo "ERROR: Tag version ${TAG_VERSION} does not match pyproject.toml version ${TOML_VERSION}"
            exit 1
          fi
          echo "Version validated: ${TAG_VERSION}"

  build:
    name: Build
    runs-on: ubuntu-latest
    needs: validate-tag
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          persist-credentials: false

      - name: Install uv
        uses: astral-sh/setup-uv@f0ec1fc3b38f5e7cd731bb6ce540c88dd8fabb67
        with:
          version: "latest"
          enable-cache: true

      - name: Build wheel and sdist
        run: uv build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/
          retention-days: 7

  release:
    name: Create GitHub Release
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          persist-credentials: false

      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: dist
          path: dist/

      - name: Create GitHub Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create "${GITHUB_REF_NAME}" \
            --title "Release ${GITHUB_REF_NAME}" \
            --generate-notes \
            dist/*.whl \
            dist/*.tar.gz

  verify:
    name: Post-Release Verification
    runs-on: macos-latest
    needs: release
    steps:
      - name: Tap and install via Homebrew
        run: |
          brew tap {org}/tools
          brew install {project-name}
          {project-name} --version
          {project-name} --help
          brew test {project-name}
          brew uninstall {project-name}
```

---

## 4. Security Workflow (`security.yml`)

Runs on a weekly schedule and on every PR. Catches vulnerabilities that may
appear between releases due to newly disclosed CVEs.

```yaml
name: Security

on:
  schedule:
    - cron: "0 9 * * 1"    # every Monday at 09:00 UTC
  pull_request:
    branches:
      - main

permissions:
  contents: read
  security-events: write    # needed to upload SARIF results

jobs:
  dependency-audit:
    name: Dependency Vulnerability Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          persist-credentials: false

      - name: Install uv
        uses: astral-sh/setup-uv@f0ec1fc3b38f5e7cd731bb6ce540c88dd8fabb67
        with:
          version: "latest"
          enable-cache: true

      - name: Install dependencies
        run: uv sync --frozen

      - name: pip-audit with SARIF output
        run: |
          uv run pip-audit --format sarif --output pip-audit.sarif || true

      - name: Upload pip-audit SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: pip-audit.sarif
        if: always()

  secret-scan:
    name: Secret Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          fetch-depth: 0      # full history for secret scanning
          persist-credentials: false

      - name: Scan for secrets with gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  codeql:
    name: CodeQL Analysis
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          persist-credentials: false

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: python

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
```

---

## 5. Workflow Security Standards

These apply to every workflow file. Violations are BLOCKING in security review.

### Action Pinning

All third-party actions must be pinned to a full commit SHA.
Mutable tags like `@v4` are a supply chain attack vector.

```yaml
# WRONG — mutable tag
uses: actions/checkout@v4

# CORRECT — pinned to commit SHA with tag as comment
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4
```

To find the SHA for a tag:

```bash
gh api repos/actions/checkout/git/refs/tags/v4 \
  --jq '.object.sha'
```

### Permissions

Every workflow declares minimum permissions at the top level.
Never rely on default permissions — always be explicit.

```yaml
permissions:
  contents: read    # default for most workflows
```

Override at the job level only when a specific job needs more:

```yaml
jobs:
  release:
    permissions:
      contents: write   # only this job needs write access
```

### Secret Handling

- Never `echo` a secret — it appears in logs
- Pass secrets via environment variables, not command-line arguments
- Use `${{ secrets.SECRET_NAME }}` syntax — never hardcode values
- Prefer `GITHUB_TOKEN` over personal access tokens where possible

```yaml
# WRONG — secret exposed in log
- run: curl -H "Authorization: ${{ secrets.API_TOKEN }}" ...

# CORRECT — pass via environment variable
- name: Call API
  env:
    API_TOKEN: ${{ secrets.API_TOKEN }}
  run: curl -H "Authorization: ${API_TOKEN}" ...
```

### User Input in Workflow Steps

Never interpolate GitHub context values directly into `run:` steps.
They can contain injection payloads.

```yaml
# WRONG — injection risk if PR title contains shell metacharacters
- run: echo "PR title: ${{ github.event.pull_request.title }}"

# CORRECT — pass via environment variable
- name: Echo PR title
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: echo "PR title: ${PR_TITLE}"
```

---

## 6. Job Conventions

- Every job has a `name:` field — makes the Actions UI readable
- Jobs that can run in parallel do — don't chain unnecessarily with `needs:`
- Jobs that must be sequential use `needs:` explicitly
- Every job specifies `runs-on:` explicitly — never rely on defaults
- Use `ubuntu-latest` for Linux jobs, `macos-latest` only when macOS-specific
  behaviour is needed (e.g. Homebrew verification)
- Use `if: always()` on cleanup or reporting steps that must run even on failure
- Matrix builds run across Python 3.11, 3.12, 3.13

---

## 7. Caching

Cache `uv` and the virtualenv to speed up CI runs.

```yaml
- name: Install uv
  uses: astral-sh/setup-uv@f0ec1fc3b38f5e7cd731bb6ce540c88dd8fabb67
  with:
    version: "latest"
    enable-cache: true    # caches uv download cache between runs
```

The `--frozen` flag on `uv sync` ensures the lockfile is respected exactly —
no implicit updates happen in CI.

---

## 8. Branch Protection Rules

Configure these on `main` via GitHub repository settings.
These are not in the workflow files — they are repository configuration.

```
Require a pull request before merging:        YES
  Required approvals:                         0 (solo dev) or 1 (team)
  Dismiss stale reviews on new commits:       YES

Require status checks to pass before merging: YES
  Required checks:
    - Lint
    - Test (3.11)
    - Test (3.12)
    - Test (3.13)
    - Dependency Audit
    - Secret Scan

Require branches to be up to date:           YES
Do not allow bypassing the above settings:   YES
Allow force pushes:                           NO
Allow deletions:                              NO
```

---

## 10. Reading and Diagnosing CI Failures

When a GitHub Actions run fails, Claude reads the failure output using the
GitHub CLI and diagnoses the root cause before proposing any fix.

### Commands for Reading Failure Output

```bash
# List recent runs for current branch
gh run list --branch $(git rev-parse --abbrev-ref HEAD) --limit 5

# View a specific run — summary and job status
gh run view {run-id}

# Read only the failed steps — most useful for diagnosis
gh run view {run-id} --log-failed

# Watch a run in progress until it completes
gh run watch {run-id}

# Get the run ID of the most recent run on current branch
gh run list --branch $(git rev-parse --abbrev-ref HEAD) --limit 1 --json databaseId \
  --jq '.[0].databaseId'
```

### Monitoring Loop Implementation

```bash
# Poll until run completes — used after every push
RUN_ID=$(gh run list --branch $(git rev-parse --abbrev-ref HEAD) \
  --limit 1 --json databaseId --jq '.[0].databaseId')

echo "Monitoring run ${RUN_ID}..."
gh run watch "${RUN_ID}" --exit-status
STATUS=$?

if [ $STATUS -eq 0 ]; then
    echo "CI passed ✓"
else
    echo "CI failed — reading failure log..."
    gh run view "${RUN_ID}" --log-failed
fi
```

### Diagnosing Common Failure Patterns

Claude reads the failure log and matches against these patterns:

**Lint / Format failures** (TRIVIAL fix)
```
ruff check: Found N errors
ruff format: Would reformat {file}
mypy: error: {file}:{line}: {message}
shellcheck: {file}: line {N}: {message}
sqlfluff: FAIL {file}
```
Fix: run the formatter/linter locally, commit the fix.

**Test failures** (STANDARD fix — requires TDD)
```
FAILED tests/{path}::{test_name} - {error}
AssertionError: {message}
{ExceptionType}: {message}
```
Fix: read the failing test, understand why it fails, follow TDD cycle.

**Dependency / environment failures** (TRIVIAL or STANDARD)
```
ModuleNotFoundError: No module named '{name}'
uv sync failed
pip-audit: found N vulnerabilities
```
Fix: update `pyproject.toml` and `uv.lock`, run `pip-audit` locally.

**Infrastructure failures** (escalate — not a code fix)
```
Error: Rate limit exceeded
Error: Network timeout
Runner: Job cancelled
```
These are transient — retry the run via `gh run rerun {run-id}` without
a code change. If persistent, escalate to developer.

### Diagnosis Output Format

When presenting a diagnosis to the developer:

```
CI Failure Diagnosis
────────────────────
Run ID:     {run-id}
Run URL:    {url}
Failed job: {job-name}
Failed step: {step-name}

Root cause:
{Plain language explanation of what failed and why}

Relevant log excerpt:
{5-15 most relevant lines from gh run view --log-failed}

Fix classification: TRIVIAL | STANDARD

Proposed fix:
{Specific description of what Claude will change}

Shall I implement this fix? [y/N]
```

Claude does not implement any fix until the developer responds YES.

---

## 11. What Claude Must Do With This Skill

When writing or reviewing GitHub Actions workflows:

- Always pin third-party actions to full commit SHA — flag mutable tags as BLOCKING
- Always declare `permissions:` at the top level of every workflow — flag missing
  permissions as BLOCKING
- Never interpolate GitHub context values directly into `run:` steps —
  always use environment variables — flag violations as BLOCKING
- Never echo secrets — flag as CRITICAL
- Always use `--frozen` with `uv sync` in CI — flag missing flag as BLOCKING
- Always conditionally skip shellcheck and sqlfluff when no relevant files exist —
  avoids false failures on projects that don't use shell or SQL
- Always run tests across the full Python version matrix (3.11, 3.12, 3.13)
- Flag any workflow that commits to `main` directly as BLOCKING
- Flag any workflow triggered by `pull_request_target` without careful review
  as HIGH security concern — this trigger has elevated permissions
- Remind developer to update pinned SHA comments when upgrading action versions

When monitoring CI after a push:

- Always use `gh run watch {run-id} --exit-status` to monitor until completion
- Always read `gh run view {run-id} --log-failed` before diagnosing — never guess
- Always classify the fix (TRIVIAL or STANDARD) before proposing it
- Always present the structured diagnosis format before implementing anything
- Never implement a fix without explicit developer approval
- Never repeat the same fix for the same failure — produce a different diagnosis
- After 3 failed attempts, stop and present full diagnosis history to developer
- Log all attempts in CODE_REVIEW.md (feature branch) or CI_REMEDIATION.md (main)
- For transient infrastructure failures, retry via `gh run rerun` without
  a code change — do not write code to fix a network timeout
