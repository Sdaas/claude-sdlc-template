---
name: homebrew
description: >
  Load this skill for any task involving Homebrew formula creation, updating,
  auditing, versioning, bottle builds, or distributing a Python CLI tool via
  Homebrew. Applies to this project.
---

# Homebrew Formula Conventions

This skill defines how Python CLI tools using this SDLC are
packaged and distributed via Homebrew. Homebrew is the primary distribution
channel for these tools.

---

## 1. Distribution Model

There are two Homebrew distribution paths. Know which one you are on:

**Homebrew Core**
The official tap maintained by the Homebrew project. High bar for acceptance —
tools must be notable, widely useful, and pass strict audit. Not the starting point
for new tools.

**Custom Tap** (`homebrew-{tap-name}`)
A separate GitHub repository that acts as a personal or organisation tap. This is
the standard starting point for all tools built from this template.

Convention: the tap repository is named `homebrew-tools` and lives at
`github.com/{org}/homebrew-tools`. Users install via:

```bash
brew tap {org}/tools
brew install {project-name}
```

---

## 2. Formula File Structure

Formula lives in the tap repository at:

```
homebrew-tools/
└── Formula/
    └── {project-name}.rb
```

### Canonical Formula Template

```ruby
class {ProjectName} < Formula
  desc "{One-line description of what the tool does}"
  homepage "https://github.com/{org}/{project-name}"
  url "https://github.com/{org}/{project-name}/archive/refs/tags/v#{version}.tar.gz"
  sha256 "{sha256-of-release-tarball}"
  license "MIT"

  head "https://github.com/{org}/{project-name}.git", branch: "main"

  depends_on "python@3.11"

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/{project-name} --version")
    assert_match "Usage:", shell_output("#{bin}/{project-name} --help")
  end
end
```

### Key Rules

- `desc` must be a single sentence, no trailing period, under 80 characters.
- `homepage` must be the GitHub repository URL.
- `url` must point to a versioned release tarball — never a branch or commit SHA.
- `sha256` must be computed fresh for every release — never reused.
- `license` must match the `LICENSE` file in the repository.
- `depends_on "python@3.11"` — explicit minimum version, matches `pyproject.toml`.
- `test` block is mandatory — `brew audit --strict` will fail without it.
- `test` block must exercise the actual binary — at minimum `--version` and `--help`.

---

## 3. Generating the Formula

The `release.sh` script handles formula generation as part of the release sequence.
Do not manually edit the `sha256` field — always compute it:

```bash
# After creating the GitHub release and downloading the tarball
curl -sL https://github.com/{org}/{project-name}/archive/refs/tags/v{version}.tar.gz \
  | shasum -a 256
```

Or using the Homebrew helper:

```bash
brew fetch --build-from-source Formula/{project-name}.rb
```

---

## 4. Dependencies

### Python Dependencies

`virtualenv_install_with_resources` automatically installs all dependencies
declared as `resource` blocks. These must be generated from the lockfile:

```bash
# Generate resource blocks from uv.lock
# Run from the formula tap repository
poet -f {project-name}
```

`poet` is a Homebrew tool that generates resource blocks from pip-compatible
lockfiles. The output is pasted into the formula before the `def install` block.

Example resource block:

```ruby
resource "click" do
  url "https://files.pythonhosted.org/packages/.../click-8.1.7.tar.gz"
  sha256 "..."
end
```

### Rules for Dependencies

- Every runtime dependency in `pyproject.toml` must have a corresponding resource block.
- Dev dependencies are never included in the formula — Homebrew installs runtime only.
- Do not use `depends_on` for Python packages — use resource blocks exclusively.
- Resource block sha256 values must match the release tarball, not the git repo.

---

## 5. Versioning

Homebrew formulas are versioned by the release tag. Version strategy:

- Semantic versioning: `MAJOR.MINOR.PATCH` — e.g. `1.2.3`
- Git tag format: `v{version}` — e.g. `v1.2.3`
- Formula `version` is inferred automatically from the URL tag — do not hardcode it
  unless the URL format does not follow convention.
- Version in `pyproject.toml` must match the git tag exactly (without the `v` prefix).

### Version Bump Sequence (handled by `release.sh`)

```
1. Update version in pyproject.toml
2. Commit: chore(release): bump version to {version}
3. Create and push git tag: v{version}
4. Create GitHub release — tarball is generated automatically
5. Compute sha256 of release tarball
6. Update formula url and sha256 in homebrew-tools repo
7. Commit formula update: feat({project-name}): release v{version}
8. Push formula update
```

---

## 6. Homebrew Audit

Before any formula is committed to the tap, it must pass audit:

```bash
# Lint the formula
brew audit Formula/{project-name}.rb

# Strict audit (catches more issues)
brew audit --strict Formula/{project-name}.rb

# Full audit including online checks
brew audit --strict --online Formula/{project-name}.rb
```

All audit findings are BLOCKING — the formula is not committed until audit passes
with zero warnings and zero errors.

### Common Audit Failures and Fixes

- Missing or weak `test` block → add meaningful test assertions
- `desc` starts with article ("A", "An", "The") → remove it
- `desc` ends with period → remove the period
- `desc` too long → shorten to under 80 characters
- `url` points to branch not tag → fix to use versioned tag
- `sha256` missing or wrong → recompute from release tarball
- Dependency not declared → add resource block

---

## 7. Installation Testing

After publishing a formula update, verify the install:

```bash
# Install from tap
brew tap {org}/tools
brew install {project-name}

# Verify
{project-name} --version
{project-name} --help

# Run brew's own test
brew test {project-name}

# Uninstall
brew uninstall {project-name}
brew untap {org}/tools
```

This sequence is part of the release process and is run by `release.sh` as a
post-release verification step.

---

## 8. Tap Repository Structure

```
homebrew-tools/
├── Formula/
│   ├── {project-name}.rb
│   └── {other-tool}.rb         # multiple tools can live in one tap
├── README.md                   # documents available tools and install instructions
└── .github/
    └── workflows/
        └── audit.yml           # runs brew audit on every PR to the tap
```

### Tap Audit CI

Every PR to `homebrew-tools` runs `brew audit --strict` on changed formulas.
This is the same check run locally before committing.

```yaml
# .github/workflows/audit.yml
name: Audit Formula
on: [pull_request]
jobs:
  audit:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run brew audit
        run: brew audit --strict Formula/*.rb
```

---

## 9. Head Installs (Development)

The `head` stanza allows installing directly from the main branch for development:

```bash
brew install --HEAD {org}/tools/{project-name}
```

This is useful for testing unreleased changes. The `head` stanza in the formula:

```ruby
head "https://github.com/{org}/{project-name}.git", branch: "main"
```

Head installs are for development only — never recommend them to end users.

---

## 10. What Claude Must Do With This Skill

When working on Homebrew-related tasks:

- Never hardcode `version` in the formula URL — let Homebrew infer it from the tag
- Always recompute `sha256` for every release — never reuse a previous value
- Always run `brew audit --strict` before committing a formula — flag failures as BLOCKING
- Ensure `test` block exercises the actual binary with meaningful assertions
- Ensure resource blocks are generated from the lockfile, not hand-written
- Ensure version in `pyproject.toml` matches the git tag (without `v` prefix)
- Flag any `depends_on` for Python packages as BLOCKING — use resource blocks instead
- Remind the developer to run post-release installation verification
