#!/usr/bin/env bash
# scripts/release.sh — Interactive release script for {project-name}
#
# Usage: ./scripts/release.sh [--dry-run]
#
# Drives the full release process interactively, pausing for developer
# confirmation at each step. Safe to re-run if interrupted.
#
# Prerequisites (see DEVELOPER_GUIDE.md for setup instructions):
#   - GitHub CLI (gh) authenticated
#   - Homebrew tap repo cloned and configured (TAP_REPO_PATH)
#   - Push access to both project repo and tap repo
#   - macOS for Homebrew verification step

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration — override via environment variables
# ─────────────────────────────────────────────────────────────────────────────

PROJECT_NAME="${PROJECT_NAME:-{project-name}}"
ORG_NAME="${ORG_NAME:-{org}}"
TAP_REPO_PATH="${TAP_REPO_PATH:-${HOME}/homebrew-tools}"
TAP_NAME="${TAP_NAME:-${ORG_NAME}/tools}"
STATE_FILE="/tmp/.release-state-${PROJECT_NAME}"
DRY_RUN=false

# ─────────────────────────────────────────────────────────────────────────────
# Colours and formatting
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────────────────────

log_step() {
    echo -e "\n${BLUE}${BOLD}▶ $1${RESET}"
}

log_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

log_warn() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

log_error() {
    echo -e "${RED}✗ $1${RESET}" >&2
}

log_info() {
    echo -e "  $1"
}

separator() {
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

confirm() {
    # Usage: confirm "Proceed with this step?" || exit 1
    local prompt="${1:-Continue?}"
    local response
    echo -e "\n${BOLD}${prompt} [y/N]${RESET} " >&2
    read -r response
    [[ "${response}" =~ ^[Yy]$ ]]
}

confirm_or_abort() {
    local prompt="${1:-Proceed?}"
    if ! confirm "${prompt}"; then
        log_error "Aborted by developer."
        save_state "${CURRENT_STEP}"
        exit 1
    fi
}

abort_with_message() {
    log_error "$1"
    save_state "${CURRENT_STEP}"
    exit 1
}

dry_run_notice() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY RUN — skipping execution: $1"
        return 0
    fi
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# State management — enables safe re-run after interruption
# ─────────────────────────────────────────────────────────────────────────────

CURRENT_STEP=1

save_state() {
    local step="$1"
    echo "STEP=${step}" > "${STATE_FILE}"
    echo "VERSION=${NEW_VERSION:-}" >> "${STATE_FILE}"
    echo "SHA256=${SHA256:-}" >> "${STATE_FILE}"
}

load_state() {
    if [[ -f "${STATE_FILE}" ]]; then
        # shellcheck source=/dev/null
        source "${STATE_FILE}"
        CURRENT_STEP="${STEP:-1}"
        NEW_VERSION="${VERSION:-}"
        SHA256="${SHA256:-}"
        log_warn "Resuming interrupted release from step ${CURRENT_STEP}."
        if [[ -n "${NEW_VERSION}" ]]; then
            log_info "Version in progress: ${NEW_VERSION}"
        fi
        confirm "Resume from step ${CURRENT_STEP}?" || {
            log_info "Starting fresh. Clearing state."
            rm -f "${STATE_FILE}"
            CURRENT_STEP=1
            NEW_VERSION=""
            SHA256=""
        }
    fi
}

clear_state() {
    rm -f "${STATE_FILE}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────────────────────────────────────

for arg in "$@"; do
    case "${arg}" in
        --dry-run)
            DRY_RUN=true
            log_warn "Running in DRY RUN mode — no changes will be committed or pushed."
            ;;
        --help|-h)
            echo "Usage: ./scripts/release.sh [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Simulate the release without executing git operations"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown argument: ${arg}"
            exit 1
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — Verify prerequisites
# ─────────────────────────────────────────────────────────────────────────────

step_1_verify_prerequisites() {
    log_step "Step 1/17 — Verifying prerequisites"

    local failed=false

    # Check we are in a git repository
    if ! git rev-parse --git-dir &>/dev/null; then
        log_error "Not a git repository. Run from the project root."
        failed=true
    fi

    # Check we are on main
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "${current_branch}" != "main" ]]; then
        log_error "Must be on main branch. Currently on: ${current_branch}"
        failed=true
    else
        log_success "On main branch"
    fi

    # Check main is clean
    if ! git diff --quiet || ! git diff --cached --quiet; then
        log_error "Working directory is not clean. Commit or stash changes first."
        git status --short
        failed=true
    else
        log_success "Working directory is clean"
    fi

    # Check main is up to date
    git fetch origin main --quiet
    local behind
    behind=$(git rev-list HEAD..origin/main --count)
    if [[ "${behind}" -gt 0 ]]; then
        log_error "main is ${behind} commit(s) behind origin/main. Pull first."
        failed=true
    else
        log_success "main is up to date with origin"
    fi

    # Check GitHub CLI
    if ! command -v gh &>/dev/null; then
        log_error "GitHub CLI (gh) not found. Install: brew install gh"
        failed=true
    elif ! gh auth status &>/dev/null; then
        log_error "GitHub CLI not authenticated. Run: gh auth login"
        failed=true
    else
        log_success "GitHub CLI authenticated"
    fi

    # Check uv
    if ! command -v uv &>/dev/null; then
        log_error "uv not found. Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
        failed=true
    else
        log_success "uv available: $(uv --version)"
    fi

    # Check brew (macOS only)
    if [[ "$(uname)" == "Darwin" ]]; then
        if ! command -v brew &>/dev/null; then
            log_error "Homebrew not found. Install from https://brew.sh"
            failed=true
        else
            log_success "Homebrew available: $(brew --version | head -1)"
        fi

        # Check tap repo
        if [[ ! -d "${TAP_REPO_PATH}" ]]; then
            log_error "Tap repo not found at ${TAP_REPO_PATH}"
            log_info "See DEVELOPER_GUIDE.md — 'Homebrew Tap Setup' for instructions."
            failed=true
        else
            log_success "Tap repo found at ${TAP_REPO_PATH}"
        fi
    else
        log_warn "Not on macOS — Homebrew verification step will be skipped"
    fi

    # Check poet
    if ! command -v poet &>/dev/null; then
        log_warn "poet not found — resource blocks will need manual generation"
        log_info "Install: brew install poet"
    else
        log_success "poet available"
    fi

    if [[ "${failed}" == "true" ]]; then
        abort_with_message "Prerequisites not met. Fix the above issues and re-run."
    fi

    log_success "All prerequisites verified"
    confirm_or_abort "Proceed to Step 2?"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 2 — Show changes since last release
# ─────────────────────────────────────────────────────────────────────────────

step_2_show_changes() {
    log_step "Step 2/17 — Changes since last release"

    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")

    if [[ "${LAST_TAG}" == "none" ]]; then
        log_info "No previous release tag found — this is the first release."
        log_info "All commits will be included:"
        git log --oneline --no-merges | head -30
    else
        log_info "Last release: ${LAST_TAG}"
        echo ""
        log_info "Commits since ${LAST_TAG}:"
        git log "${LAST_TAG}..HEAD" --oneline --no-merges
        echo ""
        log_info "Files changed since ${LAST_TAG}:"
        git diff "${LAST_TAG}..HEAD" --stat
    fi

    confirm_or_abort "These changes look correct for this release?"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Determine version bump
# ─────────────────────────────────────────────────────────────────────────────

step_3_determine_version() {
    log_step "Step 3/17 — Determine version bump"

    CURRENT_VERSION=$(grep '^version' pyproject.toml | sed 's/version = "\(.*\)"/\1/')
    log_info "Current version: ${CURRENT_VERSION}"

    # Parse current version
    IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"

    # Analyse commits for recommendation
    local has_breaking=false
    local has_feat=false
    local has_fix=false

    if [[ "${LAST_TAG}" != "none" ]]; then
        if git log "${LAST_TAG}..HEAD" --oneline | grep -qE "BREAKING CHANGE|!:"; then
            has_breaking=true
        fi
        if git log "${LAST_TAG}..HEAD" --oneline | grep -qE "^[a-f0-9]+ feat"; then
            has_feat=true
        fi
        if git log "${LAST_TAG}..HEAD" --oneline | grep -qE "^[a-f0-9]+ fix|^[a-f0-9]+ security"; then
            has_fix=true
        fi
    fi

    # Compute options
    MAJOR_VERSION="$((MAJOR + 1)).0.0"
    MINOR_VERSION="${MAJOR}.$((MINOR + 1)).0"
    PATCH_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"

    # Recommend
    local recommendation
    if [[ "${has_breaking}" == "true" ]]; then
        recommendation="MAJOR (${MAJOR_VERSION}) — breaking changes detected"
    elif [[ "${has_feat}" == "true" ]]; then
        recommendation="MINOR (${MINOR_VERSION}) — new features detected"
    else
        recommendation="PATCH (${PATCH_VERSION}) — fixes only"
    fi

    echo ""
    log_info "Recommendation: ${recommendation}"
    echo ""
    echo -e "  ${BOLD}1)${RESET} MAJOR — ${MAJOR_VERSION}  (breaking changes)"
    echo -e "  ${BOLD}2)${RESET} MINOR — ${MINOR_VERSION}  (new features, backward compatible)"
    echo -e "  ${BOLD}3)${RESET} PATCH — ${PATCH_VERSION}  (bug fixes, security fixes)"
    echo -e "  ${BOLD}4)${RESET} Custom version"
    echo ""
    echo -n "Select version bump [1/2/3/4]: "
    read -r choice

    case "${choice}" in
        1) NEW_VERSION="${MAJOR_VERSION}" ;;
        2) NEW_VERSION="${MINOR_VERSION}" ;;
        3) NEW_VERSION="${PATCH_VERSION}" ;;
        4)
            echo -n "Enter custom version (e.g. 1.2.3): "
            read -r NEW_VERSION
            if ! [[ "${NEW_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                abort_with_message "Invalid version format: ${NEW_VERSION}. Must be MAJOR.MINOR.PATCH"
            fi
            ;;
        *)
            abort_with_message "Invalid choice: ${choice}"
            ;;
    esac

    log_info "Selected version: ${NEW_VERSION}"
    confirm_or_abort "Proceed with version ${NEW_VERSION}?"

    save_state 4
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 4 — Run full test suite
# ─────────────────────────────────────────────────────────────────────────────

step_4_run_tests() {
    log_step "Step 4/17 — Running full test suite"
    log_info "This must pass completely before proceeding."

    echo ""
    uv sync --frozen

    local failed=false

    echo ""
    log_info "Running pytest..."
    if ! uv run pytest; then
        log_error "Tests failed."
        failed=true
    else
        log_success "Tests passed"
    fi

    echo ""
    log_info "Running ruff lint..."
    if ! uv run ruff check .; then
        log_error "Ruff lint failed."
        failed=true
    else
        log_success "Ruff lint passed"
    fi

    echo ""
    log_info "Running ruff format check..."
    if ! uv run ruff format --check .; then
        log_error "Ruff format check failed."
        failed=true
    else
        log_success "Ruff format check passed"
    fi

    echo ""
    log_info "Running mypy..."
    if ! uv run mypy src/; then
        log_error "Mypy failed."
        failed=true
    else
        log_success "Mypy passed"
    fi

    # Shellcheck — conditional
    if find scripts/ -name "*.sh" 2>/dev/null | grep -q .; then
        echo ""
        log_info "Running shellcheck..."
        if ! shellcheck scripts/*.sh; then
            log_error "Shellcheck failed."
            failed=true
        else
            log_success "Shellcheck passed"
        fi
    fi

    # Sqlfluff — conditional
    if [[ -d "sql/" ]] && find sql/ -name "*.sql" 2>/dev/null | grep -q .; then
        echo ""
        log_info "Running sqlfluff..."
        if ! uv run sqlfluff lint sql/; then
            log_error "Sqlfluff failed."
            failed=true
        else
            log_success "Sqlfluff passed"
        fi
    fi

    # Dependency audit
    echo ""
    log_info "Running pip-audit..."
    if ! uv run pip-audit; then
        log_error "pip-audit found vulnerabilities."
        failed=true
    else
        log_success "pip-audit passed"
    fi

    if [[ "${failed}" == "true" ]]; then
        abort_with_message "Test suite failed. Fix all issues before releasing."
    fi

    log_success "Full test suite passed"
    confirm_or_abort "Proceed to version bump?"

    save_state 5
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 5 — Update version in pyproject.toml
# ─────────────────────────────────────────────────────────────────────────────

step_5_update_version() {
    log_step "Step 5/17 — Updating version in pyproject.toml"

    log_info "Changing version: ${CURRENT_VERSION} → ${NEW_VERSION}"

    if ! dry_run_notice "sed -i pyproject.toml version to ${NEW_VERSION}"; then
        sed -i '' "s/^version = \"${CURRENT_VERSION}\"/version = \"${NEW_VERSION}\"/" pyproject.toml
    fi

    log_info "Updated pyproject.toml:"
    grep "^version" pyproject.toml

    confirm_or_abort "Version update looks correct?"
    save_state 6
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 6 — Update CHANGELOG.md
# ─────────────────────────────────────────────────────────────────────────────

step_6_update_changelog() {
    log_step "Step 6/17 — Updating CHANGELOG.md"

    local date_today
    date_today=$(date +"%Y-%m-%d")

    # Build commit lists by type
    local feats fixes security others
    if [[ "${LAST_TAG}" != "none" ]]; then
        feats=$(git log "${LAST_TAG}..HEAD" --oneline --no-merges | grep "^[a-f0-9]* feat" | sed 's/^[a-f0-9]* /- /' || true)
        fixes=$(git log "${LAST_TAG}..HEAD" --oneline --no-merges | grep "^[a-f0-9]* fix" | sed 's/^[a-f0-9]* /- /' || true)
        security=$(git log "${LAST_TAG}..HEAD" --oneline --no-merges | grep "^[a-f0-9]* security" | sed 's/^[a-f0-9]* /- /' || true)
        others=$(git log "${LAST_TAG}..HEAD" --oneline --no-merges | grep -vE "^[a-f0-9]* (feat|fix|security|release)" | sed 's/^[a-f0-9]* /- /' || true)
    else
        feats="- Initial release"
        fixes=""
        security=""
        others=""
    fi

    # Prepare changelog entry
    local entry="## [${NEW_VERSION}] — ${date_today}"
    [[ -n "${feats}" ]]    && entry+=$'\n\n### Added\n'"${feats}"
    [[ -n "${fixes}" ]]    && entry+=$'\n\n### Fixed\n'"${fixes}"
    [[ -n "${security}" ]] && entry+=$'\n\n### Security\n'"${security}"
    [[ -n "${others}" ]]   && entry+=$'\n\n### Changed\n'"${others}"

    log_info "Proposed changelog entry:"
    echo ""
    echo "${entry}"
    echo ""

    log_info "Opening CHANGELOG.md in \$EDITOR for review and editing..."
    confirm_or_abort "Open editor?"

    # Inject entry after the [Unreleased] section
    if ! dry_run_notice "inject changelog entry"; then
        # Create temp file with new entry inserted
        local tmp_changelog
        tmp_changelog=$(mktemp)
        awk -v entry="${entry}" '
            /^## \[Unreleased\]/ { print; print ""; print entry; next }
            { print }
        ' CHANGELOG.md > "${tmp_changelog}"
        mv "${tmp_changelog}" CHANGELOG.md

        # Open in editor for developer to review and adjust
        "${EDITOR:-vi}" CHANGELOG.md
    fi

    log_info "CHANGELOG.md diff:"
    git diff CHANGELOG.md

    confirm_or_abort "Changelog looks correct?"
    save_state 7
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 7 — Commit version bump and changelog
# ─────────────────────────────────────────────────────────────────────────────

step_7_commit_release() {
    log_step "Step 7/17 — Committing version bump and changelog"

    log_info "Files to commit:"
    git diff --name-only

    confirm_or_abort "Commit these files with message: 'release: bump version to ${NEW_VERSION}'?"

    if ! dry_run_notice "git commit release bump"; then
        git add pyproject.toml CHANGELOG.md
        git commit -m "release: bump version to ${NEW_VERSION}"
    fi

    confirm_or_abort "Push commit to origin/main?"

    if ! dry_run_notice "git push origin main"; then
        git push origin main
    fi

    log_success "Release commit pushed to main"
    save_state 8
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 8 — Create and push annotated tag
# ─────────────────────────────────────────────────────────────────────────────

step_8_create_tag() {
    log_step "Step 8/17 — Creating and pushing release tag"

    local tag="v${NEW_VERSION}"
    log_info "Tag: ${tag}"

    confirm_or_abort "Create and push annotated tag ${tag}?"

    if ! dry_run_notice "git tag and push ${tag}"; then
        git tag -a "${tag}" -m "Release ${tag}"
        git push origin "${tag}"
    fi

    log_success "Tag ${tag} created and pushed"
    save_state 9
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 9 — Trigger GitHub Actions release workflow
# ─────────────────────────────────────────────────────────────────────────────

step_9_trigger_release_workflow() {
    log_step "Step 9/17 — GitHub Actions release workflow triggered"

    log_info "Pushing tag v${NEW_VERSION} triggered the release workflow automatically."
    log_info "Opening Actions page..."

    if ! dry_run_notice "open GitHub Actions URL"; then
        local actions_url="https://github.com/${ORG_NAME}/${PROJECT_NAME}/actions/workflows/release.yml"
        if command -v open &>/dev/null; then
            open "${actions_url}"
        else
            log_info "Visit: ${actions_url}"
        fi
    fi

    save_state 10
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 10 — Wait for GitHub release to be created
# ─────────────────────────────────────────────────────────────────────────────

step_10_wait_for_release() {
    log_step "Step 10/17 — Waiting for GitHub release to be created"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY RUN — skipping wait for GitHub release"
        save_state 11
        return
    fi

    local tag="v${NEW_VERSION}"
    local timeout=600  # 10 minutes
    local elapsed=0
    local interval=15

    log_info "Polling for GitHub release ${tag}..."

    while ! gh release view "${tag}" &>/dev/null; do
        if [[ "${elapsed}" -ge "${timeout}" ]]; then
            abort_with_message "Timed out waiting for GitHub release. Check Actions: https://github.com/${ORG_NAME}/${PROJECT_NAME}/actions"
        fi
        echo -n "."
        sleep "${interval}"
        elapsed=$((elapsed + interval))
    done

    echo ""
    log_success "GitHub release ${tag} is live"
    gh release view "${tag}" --json tagName,name,publishedAt,url \
        --jq '"Tag: \(.tagName)\nName: \(.name)\nPublished: \(.publishedAt)\nURL: \(.url)"'

    save_state 11
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 11 — Compute sha256 of release tarball
# ─────────────────────────────────────────────────────────────────────────────

step_11_compute_sha256() {
    log_step "Step 11/17 — Computing sha256 of release tarball"

    local tarball_url="https://github.com/${ORG_NAME}/${PROJECT_NAME}/archive/refs/tags/v${NEW_VERSION}.tar.gz"
    log_info "Tarball URL: ${tarball_url}"

    if ! dry_run_notice "compute sha256"; then
        SHA256=$(curl -sL "${tarball_url}" | shasum -a 256 | cut -d' ' -f1)
    else
        SHA256="dry-run-sha256-placeholder"
    fi

    # Validate it looks like a sha256
    if ! [[ "${SHA256}" =~ ^[a-f0-9]{64}$ ]] && [[ "${DRY_RUN}" == "false" ]]; then
        abort_with_message "sha256 does not look valid: ${SHA256}"
    fi

    log_success "sha256: ${SHA256}"
    save_state 12
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 12 — Generate Homebrew resource blocks
# ─────────────────────────────────────────────────────────────────────────────

step_12_generate_resources() {
    log_step "Step 12/17 — Generating Homebrew resource blocks"

    if [[ "$(uname)" != "Darwin" ]]; then
        log_warn "Not on macOS — skipping resource block generation"
        log_info "Generate resource blocks manually on macOS and update the formula."
        save_state 13
        return
    fi

    local tmp_requirements
    tmp_requirements=$(mktemp)

    log_info "Exporting runtime dependencies..."
    uv export --no-dev --format requirements-txt > "${tmp_requirements}"

    if command -v poet &>/dev/null; then
        echo ""
        log_info "Generated resource blocks:"
        poet -r "${tmp_requirements}"
        echo ""
        log_info "Copy these resource blocks into the formula before the 'def install' block."
    else
        log_warn "poet not installed — showing requirements for manual resource block creation"
        cat "${tmp_requirements}"
        log_info "Install poet: brew install poet"
        log_info "Then run: poet -r requirements.txt"
    fi

    rm -f "${tmp_requirements}"

    confirm_or_abort "Resource blocks ready to be inserted into formula?"
    save_state 13
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 13 — Update Homebrew formula
# ─────────────────────────────────────────────────────────────────────────────

step_13_update_formula() {
    log_step "Step 13/17 — Updating Homebrew formula"

    if [[ "$(uname)" != "Darwin" ]]; then
        log_warn "Not on macOS — update formula manually in ${TAP_REPO_PATH}"
        save_state 14
        return
    fi

    local formula="${TAP_REPO_PATH}/Formula/${PROJECT_NAME}.rb"

    if [[ ! -f "${formula}" ]]; then
        abort_with_message "Formula not found: ${formula}\nSee DEVELOPER_GUIDE.md for formula creation instructions."
    fi

    # Pull latest tap
    log_info "Pulling latest tap repo..."
    (cd "${TAP_REPO_PATH}" && git checkout main && git pull origin main)

    # Update sha256
    log_info "Updating sha256 in formula..."
    if ! dry_run_notice "sed sha256 in formula"; then
        sed -i '' "s/sha256 \"[a-f0-9]*\"/sha256 \"${SHA256}\"/" "${formula}"
    fi

    # Update version in URL (if hardcoded — normally inferred from tag)
    log_info "Updating version reference in formula URL..."
    if ! dry_run_notice "sed version in formula URL"; then
        sed -i '' "s|/v[0-9]*\.[0-9]*\.[0-9]*.tar.gz|/v${NEW_VERSION}.tar.gz|" "${formula}"
    fi

    log_info "Formula diff:"
    (cd "${TAP_REPO_PATH}" && git diff "Formula/${PROJECT_NAME}.rb")

    log_info "Open the formula to insert updated resource blocks:"
    confirm_or_abort "Open formula in \$EDITOR to update resource blocks?"

    if ! dry_run_notice "open formula in editor"; then
        "${EDITOR:-vi}" "${formula}"
    fi

    log_info "Formula after edits:"
    cat "${formula}"

    confirm_or_abort "Formula looks correct?"
    save_state 14
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 14 — Run brew audit
# ─────────────────────────────────────────────────────────────────────────────

step_14_brew_audit() {
    log_step "Step 14/17 — Running brew audit on updated formula"

    if [[ "$(uname)" != "Darwin" ]]; then
        log_warn "Not on macOS — skipping brew audit"
        save_state 15
        return
    fi

    local formula="${TAP_REPO_PATH}/Formula/${PROJECT_NAME}.rb"

    if ! dry_run_notice "brew audit"; then
        if ! brew audit --strict "${formula}"; then
            abort_with_message "brew audit failed. Fix the formula (Step 13) and re-run."
        fi
    fi

    log_success "brew audit passed"
    save_state 15
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 15 — Commit and push formula update
# ─────────────────────────────────────────────────────────────────────────────

step_15_commit_formula() {
    log_step "Step 15/17 — Committing and pushing formula update to tap repo"

    if [[ "$(uname)" != "Darwin" ]]; then
        log_warn "Not on macOS — commit formula update manually in ${TAP_REPO_PATH}"
        save_state 16
        return
    fi

    local formula_path="Formula/${PROJECT_NAME}.rb"

    log_info "Committing formula update..."
    confirm_or_abort "Commit formula with message: 'feat(${PROJECT_NAME}): release v${NEW_VERSION}'?"

    if ! dry_run_notice "git commit and push formula"; then
        (
            cd "${TAP_REPO_PATH}"
            git add "${formula_path}"
            git commit -m "feat(${PROJECT_NAME}): release v${NEW_VERSION}"
        )

        confirm_or_abort "Push formula update to origin/main?"

        (
            cd "${TAP_REPO_PATH}"
            git push origin main
        )
    fi

    log_success "Formula update committed and pushed"
    save_state 16
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 16 — Verify Homebrew installation
# ─────────────────────────────────────────────────────────────────────────────

step_16_verify_installation() {
    log_step "Step 16/17 — Verifying Homebrew installation"

    if [[ "$(uname)" != "Darwin" ]]; then
        log_warn "Not on macOS — skipping Homebrew verification"
        log_info "Verify manually on macOS:"
        log_info "  brew tap ${TAP_NAME}"
        log_info "  brew install ${PROJECT_NAME}"
        log_info "  ${PROJECT_NAME} --version"
        log_info "  brew test ${PROJECT_NAME}"
        save_state 17
        return
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY RUN — skipping Homebrew installation verification"
        save_state 17
        return
    fi

    log_info "Running: brew update"
    brew update

    log_info "Running: brew tap ${TAP_NAME}"
    brew tap "${TAP_NAME}" || true  # may already be tapped

    log_info "Running: brew install ${PROJECT_NAME}"
    brew install "${PROJECT_NAME}"

    # Verify version
    local installed_version
    installed_version=$("${PROJECT_NAME}" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    if [[ "${installed_version}" != "${NEW_VERSION}" ]]; then
        abort_with_message "Version mismatch: installed ${installed_version}, expected ${NEW_VERSION}"
    fi

    log_success "Version verified: ${installed_version}"

    log_info "Running: brew test ${PROJECT_NAME}"
    brew test "${PROJECT_NAME}"
    log_success "brew test passed"

    log_info "Uninstalling test installation..."
    brew uninstall "${PROJECT_NAME}"

    log_success "Homebrew installation verified"
    save_state 17
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 17 — Post-release summary
# ─────────────────────────────────────────────────────────────────────────────

step_17_summary() {
    log_step "Step 17/17 — Release complete"

    separator
    echo -e "${GREEN}${BOLD}Release v${NEW_VERSION} complete ✓${RESET}"
    separator
    echo ""
    log_info "GitHub release:   https://github.com/${ORG_NAME}/${PROJECT_NAME}/releases/tag/v${NEW_VERSION}"
    log_info "Homebrew install: brew tap ${TAP_NAME} && brew install ${PROJECT_NAME}"
    log_info "sha256:           ${SHA256}"
    log_info "Tag:              v${NEW_VERSION}"
    log_info "Released at:      $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    log_info "Next steps:"
    log_info "  - Announce the release if applicable"
    log_info "  - Close the milestone on GitHub"
    log_info "  - Update any related documentation"
    echo ""
    separator

    clear_state
}

# ─────────────────────────────────────────────────────────────────────────────
# Main — run steps in sequence, skipping completed ones on resume
# ─────────────────────────────────────────────────────────────────────────────

main() {
    separator
    echo -e "${BOLD}  Release Script — ${PROJECT_NAME}${RESET}"
    separator

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo -e "  ${YELLOW}Mode: DRY RUN — no changes will be committed or pushed${RESET}"
        separator
    fi

    echo ""

    load_state

    # Declare NEW_VERSION and SHA256 early — may be loaded from state
    NEW_VERSION="${NEW_VERSION:-}"
    SHA256="${SHA256:-}"
    LAST_TAG=""
    CURRENT_VERSION=""

    [[ "${CURRENT_STEP}" -le 1  ]] && step_1_verify_prerequisites
    [[ "${CURRENT_STEP}" -le 2  ]] && step_2_show_changes
    [[ "${CURRENT_STEP}" -le 3  ]] && step_3_determine_version
    [[ "${CURRENT_STEP}" -le 4  ]] && step_4_run_tests
    [[ "${CURRENT_STEP}" -le 5  ]] && step_5_update_version
    [[ "${CURRENT_STEP}" -le 6  ]] && step_6_update_changelog
    [[ "${CURRENT_STEP}" -le 7  ]] && step_7_commit_release
    [[ "${CURRENT_STEP}" -le 8  ]] && step_8_create_tag
    [[ "${CURRENT_STEP}" -le 9  ]] && step_9_trigger_release_workflow
    [[ "${CURRENT_STEP}" -le 10 ]] && step_10_wait_for_release
    [[ "${CURRENT_STEP}" -le 11 ]] && step_11_compute_sha256
    [[ "${CURRENT_STEP}" -le 12 ]] && step_12_generate_resources
    [[ "${CURRENT_STEP}" -le 13 ]] && step_13_update_formula
    [[ "${CURRENT_STEP}" -le 14 ]] && step_14_brew_audit
    [[ "${CURRENT_STEP}" -le 15 ]] && step_15_commit_formula
    [[ "${CURRENT_STEP}" -le 16 ]] && step_16_verify_installation
    step_17_summary
}

main "$@"
