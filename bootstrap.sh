#!/usr/bin/env bash
# bootstrap.sh — Create a new project from claude-sdlc-template
#
# Usage (interview mode — recommended):
#   ./bootstrap.sh
#
# Usage (non-interactive — for automation/testing):
#   ./bootstrap.sh \
#     --dest ~/projects/my-tool \
#     --project-name my-tool \
#     --package-name mytool \
#     --author-name "Jane Smith" \
#     --author-email "jane@example.com" \
#     --org jane-org \
#     --description "A Python CLI tool" \
#     --sql-dialect none \
#     --tap-repo-path ~/homebrew-tools \
#     --tap-name "jane-org/tools" \
#     --initial-version 0.1.0
#
# Steps:
#   1.  Check prerequisites (uv, git)
#   2.  Validate destination directory (must not exist or be empty)
#   3.  Copy scaffold to destination
#   4.  Rename *.template files to their real names
#   5.  Rename src/{package}/ → src/{PACKAGE_NAME}/
#   6.  Replace all placeholders in all text files
#   7.  Set initial version in pyproject.toml
#   8.  Configure SQL dialect in pyproject.toml
#   9.  Write tap path/name defaults into release.sh
#   10. Create missing directories
#   11. Install dependencies via uv sync
#   12. Make scripts and hooks executable
#   13. Install pre-commit hooks
#   14. git init + initial commit
#   15. Optionally add GitHub remote and push

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Colours
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

log_step()    { echo -e "\n${BLUE}${BOLD}▶ $1${RESET}"; }
log_success() { echo -e "${GREEN}✓ $1${RESET}"; }
log_warn()    { echo -e "${YELLOW}⚠ $1${RESET}"; }
log_error()   { echo -e "${RED}✗ $1${RESET}" >&2; }
log_info()    { echo -e "  $1"; }
log_dim()     { echo -e "${DIM}  $1${RESET}"; }
separator()   { echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }
thin_sep()    { echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${RESET}"; }

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

ask() {
    local question="$1" default="$2" var_name="$3" prompt user_input
    if [[ -n "${default}" ]]; then
        prompt="\n${BOLD}${question}${RESET} ${DIM}[${default}]${RESET}: "
    else
        prompt="\n${BOLD}${question}${RESET}: "
    fi
    echo -en "${prompt}" >&2
    read -r user_input
    if [[ -z "${user_input}" && -n "${default}" ]]; then
        printf -v "${var_name}" '%s' "${default}"
    else
        printf -v "${var_name}" '%s' "${user_input}"
    fi
}

ask_choice() {
    local question="$1" options_str="$2" default="$3" var_name="$4"
    IFS='|' read -ra options <<< "${options_str}"
    echo -e "\n${BOLD}${question}${RESET}" >&2
    local i=1
    for opt in "${options[@]}"; do
        if [[ "${opt}" == "${default}" ]]; then
            echo -e "  ${BOLD}${i})${RESET} ${opt} ${DIM}(default)${RESET}" >&2
        else
            echo -e "  ${i}) ${opt}" >&2
        fi
        ((i++))
    done
    local selection
    echo -en "\n${BOLD}Select [1-${#options[@]}]${RESET} ${DIM}(Enter for default)${RESET}: " >&2
    read -r selection
    if [[ -z "${selection}" ]]; then
        printf -v "${var_name}" '%s' "${default}"
    elif [[ "${selection}" =~ ^[0-9]+$ ]] && \
         [[ "${selection}" -ge 1 ]] && \
         [[ "${selection}" -le "${#options[@]}" ]]; then
        printf -v "${var_name}" '%s' "${options[$((selection - 1))]}"
    else
        log_warn "Invalid selection — using default: ${default}" >&2
        printf -v "${var_name}" '%s' "${default}"
    fi
}

confirm() {
    local prompt="${1:-Continue?}" default="${2:-n}" response
    if [[ "${default}" == "y" ]]; then
        echo -en "\n${BOLD}${prompt}${RESET} ${DIM}[Y/n]${RESET}: " >&2
    else
        echo -en "\n${BOLD}${prompt}${RESET} ${DIM}[y/N]${RESET}: " >&2
    fi
    read -r response
    [[ -z "${response}" ]] && response="${default}"
    [[ "${response}" =~ ^[Yy]$ ]]
}

confirm_or_abort() {
    if ! confirm "${1:-Proceed?}"; then
        echo -e "\n${RED}Aborted.${RESET}"
        exit 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Validation
# ─────────────────────────────────────────────────────────────────────────────

validate_project_name() {
    [[ "$1" =~ ^[a-z][a-z0-9-]*$ ]] && return 0
    log_error "Project name must be lowercase, start with a letter, use only letters/numbers/hyphens. Got: $1"
    return 1
}

validate_package_name() {
    [[ "$1" =~ ^[a-z][a-z0-9_]*$ ]] && return 0
    log_error "Package name must be lowercase, start with a letter, use only letters/numbers/underscores. Got: $1"
    return 1
}

validate_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 0
    log_error "Version must be MAJOR.MINOR.PATCH (e.g. 0.1.0). Got: $1"
    return 1
}

# Derive snake_case package name from kebab-case project name
derive_package_name() {
    echo "${1//-/_}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

ARG_DEST=""
ARG_PROJECT_NAME=""
ARG_PACKAGE_NAME=""
ARG_AUTHOR_NAME=""
ARG_AUTHOR_EMAIL=""
ARG_ORG=""
ARG_SQL_DIALECT=""
ARG_TAP_REPO_PATH=""
ARG_TAP_NAME=""
ARG_INITIAL_VERSION=""
ARG_DESCRIPTION=""
ARG_GITHUB_REMOTE=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dest)           ARG_DEST="$2";            shift 2 ;;
        --project-name)   ARG_PROJECT_NAME="$2";    shift 2 ;;
        --package-name)   ARG_PACKAGE_NAME="$2";    shift 2 ;;
        --author-name)    ARG_AUTHOR_NAME="$2";     shift 2 ;;
        --author-email)   ARG_AUTHOR_EMAIL="$2";    shift 2 ;;
        --org)            ARG_ORG="$2";             shift 2 ;;
        --sql-dialect)    ARG_SQL_DIALECT="$2";     shift 2 ;;
        --tap-repo-path)  ARG_TAP_REPO_PATH="$2";  shift 2 ;;
        --tap-name)       ARG_TAP_NAME="$2";        shift 2 ;;
        --initial-version) ARG_INITIAL_VERSION="$2"; shift 2 ;;
        --version)        echo "bootstrap.sh (claude-sdlc-template)"; exit 0 ;;
        --description)    ARG_DESCRIPTION="$2";     shift 2 ;;
        --github-remote)  ARG_GITHUB_REMOTE="$2";   shift 2 ;;
        --force)          FORCE=true;               shift ;;
        -h|--help)
            sed -n '2,20p' "$0" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        *) log_error "Unknown argument: $1"; exit 1 ;;
    esac
done

# Determine if we're in full non-interactive mode (all required args supplied)
NON_INTERACTIVE=false
if [[ -n "${ARG_DEST}" && -n "${ARG_PROJECT_NAME}" && -n "${ARG_AUTHOR_NAME}" && \
      -n "${ARG_AUTHOR_EMAIL}" && -n "${ARG_ORG}" && -n "${ARG_DESCRIPTION}" ]]; then
    NON_INTERACTIVE=true
fi

# ─────────────────────────────────────────────────────────────────────────────
# Template root (where scaffold/ lives — same dir as this script)
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAFFOLD_DIR="${SCRIPT_DIR}/scaffold"

if [[ ! -d "${SCAFFOLD_DIR}" ]]; then
    log_error "scaffold/ directory not found at ${SCAFFOLD_DIR}"
    log_error "Run bootstrap.sh from the claude-sdlc-template repo root."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────────────────────

if [[ "${NON_INTERACTIVE}" == "false" ]]; then
    separator
    echo -e "\n  ${BOLD}claude-sdlc-template — Project Bootstrap${RESET}\n"
    echo -e "  This script creates a new Python CLI project from the template."
    echo -e "  Answer the questions below to configure your project.\n"
    separator
fi

# ─────────────────────────────────────────────────────────────────────────────
# Interview
# ─────────────────────────────────────────────────────────────────────────────

DEFAULT_AUTHOR_NAME="$(git config user.name 2>/dev/null || echo "")"
DEFAULT_AUTHOR_EMAIL="$(git config user.email 2>/dev/null || echo "")"

# 1. Destination
if [[ -n "${ARG_DEST}" ]]; then
    DEST_DIR="${ARG_DEST}"
else
    ask "Where should the new project be created? (absolute or ~/... path)" "" DEST_DIR
    [[ -z "${DEST_DIR}" ]] && { log_error "Destination is required."; exit 1; }
fi
# Expand ~ and resolve to absolute path (realpath -m not available on macOS)
DEST_DIR="${DEST_DIR/#\~/${HOME}}"
if [[ "${DEST_DIR}" != /* ]]; then
    DEST_DIR="$(pwd)/${DEST_DIR}"
fi

# 2. Project name
if [[ -n "${ARG_PROJECT_NAME}" ]]; then
    PROJECT_NAME="${ARG_PROJECT_NAME}"
else
    ask "Project name (kebab-case, e.g. my-tool)" "" PROJECT_NAME
fi
[[ -z "${PROJECT_NAME}" ]] && { log_error "Project name is required."; exit 1; }
validate_project_name "${PROJECT_NAME}" || exit 1

# 3. Package name
DEFAULT_PACKAGE="$(derive_package_name "${PROJECT_NAME}")"
if [[ -n "${ARG_PACKAGE_NAME}" ]]; then
    PACKAGE_NAME="${ARG_PACKAGE_NAME}"
else
    ask "Python package name (snake_case)" "${DEFAULT_PACKAGE}" PACKAGE_NAME
fi
[[ -z "${PACKAGE_NAME}" ]] && PACKAGE_NAME="${DEFAULT_PACKAGE}"
validate_package_name "${PACKAGE_NAME}" || exit 1

# 4. Author name
if [[ -n "${ARG_AUTHOR_NAME}" ]]; then
    AUTHOR_NAME="${ARG_AUTHOR_NAME}"
else
    ask "Author name" "${DEFAULT_AUTHOR_NAME}" AUTHOR_NAME
fi
[[ -z "${AUTHOR_NAME}" ]] && { log_error "Author name is required."; exit 1; }

# 5. Author email
if [[ -n "${ARG_AUTHOR_EMAIL}" ]]; then
    AUTHOR_EMAIL="${ARG_AUTHOR_EMAIL}"
else
    ask "Author email" "${DEFAULT_AUTHOR_EMAIL}" AUTHOR_EMAIL
fi
[[ -z "${AUTHOR_EMAIL}" ]] && { log_error "Author email is required."; exit 1; }

# 6. GitHub org
if [[ -n "${ARG_ORG}" ]]; then
    ORG_NAME="${ARG_ORG}"
else
    ask "GitHub org or username" "" ORG_NAME
fi
[[ -z "${ORG_NAME}" ]] && { log_error "GitHub org is required."; exit 1; }

# 7. Description
if [[ -n "${ARG_DESCRIPTION}" ]]; then
    DESCRIPTION="${ARG_DESCRIPTION}"
else
    ask "One-line project description" "" DESCRIPTION
fi
[[ -z "${DESCRIPTION}" ]] && { log_error "Description is required."; exit 1; }

# 8. Initial version
if [[ -n "${ARG_INITIAL_VERSION}" ]]; then
    INITIAL_VERSION="${ARG_INITIAL_VERSION}"
else
    ask "Initial version" "0.1.0" INITIAL_VERSION
fi
[[ -z "${INITIAL_VERSION}" ]] && INITIAL_VERSION="0.1.0"
validate_semver "${INITIAL_VERSION}" || exit 1

# 9. SQL dialect
if [[ -n "${ARG_SQL_DIALECT}" ]]; then
    SQL_DIALECT="${ARG_SQL_DIALECT}"
else
    ask_choice "SQL dialect" "none|sqlite|postgres|mysql" "none" SQL_DIALECT
fi

# 10. Homebrew tap repo path
DEFAULT_TAP_PATH="${HOME}/homebrew-tools"
if [[ -n "${ARG_TAP_REPO_PATH}" ]]; then
    TAP_REPO_PATH="${ARG_TAP_REPO_PATH}"
else
    ask "Homebrew tap local path" "${DEFAULT_TAP_PATH}" TAP_REPO_PATH
fi
[[ -z "${TAP_REPO_PATH}" ]] && TAP_REPO_PATH="${DEFAULT_TAP_PATH}"
TAP_REPO_PATH="${TAP_REPO_PATH/#\~/${HOME}}"

# 11. Homebrew tap name
DEFAULT_TAP_NAME="${ORG_NAME}/tools"
if [[ -n "${ARG_TAP_NAME}" ]]; then
    TAP_NAME="${ARG_TAP_NAME}"
else
    ask "Homebrew tap name (org/repo)" "${DEFAULT_TAP_NAME}" TAP_NAME
fi
[[ -z "${TAP_NAME}" ]] && TAP_NAME="${DEFAULT_TAP_NAME}"

# 12. GitHub remote (optional)
if [[ -n "${ARG_GITHUB_REMOTE}" ]]; then
    GITHUB_REMOTE="${ARG_GITHUB_REMOTE}"
elif [[ "${NON_INTERACTIVE}" == "false" ]]; then
    GITHUB_REMOTE=""
    if confirm "Add a GitHub remote?" "n"; then
        DEFAULT_REMOTE="https://github.com/${ORG_NAME}/${PROJECT_NAME}.git"
        ask "GitHub remote URL" "${DEFAULT_REMOTE}" GITHUB_REMOTE
    fi
else
    GITHUB_REMOTE=""
fi

# ─────────────────────────────────────────────────────────────────────────────
# Confirmation summary
# ─────────────────────────────────────────────────────────────────────────────

if [[ "${NON_INTERACTIVE}" == "false" ]]; then
    echo ""
    separator
    echo -e "\n  ${BOLD}Summary${RESET}\n"
    echo -e "  ${BOLD}Destination:${RESET}        ${DEST_DIR}"
    echo -e "  ${BOLD}Project name:${RESET}       ${PROJECT_NAME}"
    echo -e "  ${BOLD}Package name:${RESET}       ${PACKAGE_NAME}"
    echo -e "  ${BOLD}Author:${RESET}             ${AUTHOR_NAME} <${AUTHOR_EMAIL}>"
    echo -e "  ${BOLD}GitHub org:${RESET}         ${ORG_NAME}"
    echo -e "  ${BOLD}Description:${RESET}        ${DESCRIPTION}"
    echo -e "  ${BOLD}Version:${RESET}            ${INITIAL_VERSION}"
    echo -e "  ${BOLD}SQL dialect:${RESET}        ${SQL_DIALECT}"
    echo -e "  ${BOLD}Tap path:${RESET}           ${TAP_REPO_PATH}"
    echo -e "  ${BOLD}Tap name:${RESET}           ${TAP_NAME}"
    echo -e "  ${BOLD}GitHub remote:${RESET}      ${GITHUB_REMOTE:-'(none)'}"
    echo ""
    confirm_or_abort "Everything correct? Proceed with bootstrap?"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — Prerequisites
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 1/15 — Checking prerequisites"
FAILED=false
if uv --version &>/dev/null; then
    log_success "uv: $(uv --version)"
else
    log_error "uv not found or not executable. Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
    FAILED=true
fi
if git --version &>/dev/null; then
    log_success "git: $(git --version)"
else
    log_error "git not found or not executable."
    FAILED=true
fi
[[ "${FAILED}" == "true" ]] && { log_error "Fix prerequisites and re-run."; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# Step 2 — Validate destination
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 2/15 — Validating destination"

if [[ -d "${DEST_DIR}" ]]; then
    # Check if non-empty (ignore . and ..)
    if [[ -n "$(ls -A "${DEST_DIR}" 2>/dev/null)" ]]; then
        if [[ "${FORCE}" == "true" ]]; then
            log_warn "Destination exists and is non-empty — proceeding because --force was given"
        else
            log_error "Destination already exists and is non-empty: ${DEST_DIR}"
            log_error "Use --force to overwrite, or choose a different destination."
            exit 1
        fi
    else
        log_info "Destination exists but is empty — using it"
    fi
else
    mkdir -p "${DEST_DIR}"
    log_success "Created ${DEST_DIR}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Copy scaffold to destination
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 3/15 — Copying scaffold to destination"

# cp -r scaffold/. copies everything including hidden dirs (.claude.template, .github)
cp -r "${SCAFFOLD_DIR}/." "${DEST_DIR}/"
log_success "Scaffold copied to ${DEST_DIR}"

# ─────────────────────────────────────────────────────────────────────────────
# Step 4 — Rename *.template files
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 4/15 — Renaming template files"

cd "${DEST_DIR}"

if [[ -f "pyproject.toml.template" ]]; then
    mv "pyproject.toml.template" "pyproject.toml"
    log_success "pyproject.toml.template → pyproject.toml"
fi

if [[ -f "pre-commit-config.yaml.template" ]]; then
    mv "pre-commit-config.yaml.template" ".pre-commit-config.yaml"
    log_success "pre-commit-config.yaml.template → .pre-commit-config.yaml"
fi

if [[ -f "gitignore.template" ]]; then
    mv "gitignore.template" ".gitignore"
    log_success "gitignore.template → .gitignore"
fi

if [[ -f "CLAUDE.md.template" ]]; then
    mv "CLAUDE.md.template" "CLAUDE.md"
    log_success "CLAUDE.md.template → CLAUDE.md"
fi

if [[ -d ".claude.template" ]]; then
    mv ".claude.template" ".claude"
    log_success ".claude.template/ → .claude/"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 5 — Rename src/{package}/ → src/{PACKAGE_NAME}/
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 5/15 — Renaming package directory"

if [[ -d "src/{package}" ]]; then
    mv "src/{package}" "src/${PACKAGE_NAME}"
    log_success "src/{package}/ → src/${PACKAGE_NAME}/"
elif [[ -d "src/${PACKAGE_NAME}" ]]; then
    log_info "src/${PACKAGE_NAME}/ already exists — skipping rename"
else
    log_warn "src/{package}/ not found — creating src/${PACKAGE_NAME}/"
    mkdir -p "src/${PACKAGE_NAME}"
    touch "src/${PACKAGE_NAME}/__init__.py" "src/${PACKAGE_NAME}/cli.py"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 6 — Replace all placeholders
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 6/15 — Replacing template placeholders"

PLACEHOLDER_FILES=$(find . \
    -not -path "./.git/*" \
    -not -path "./.venv/*" \
    -not -path "./__pycache__/*" \
    -not -path "./dist/*" \
    -not -path "./build/*" \
    -type f \
    \( -name "*.py" -o -name "*.md" -o -name "*.toml" \
       -o -name "*.yaml" -o -name "*.yml" -o -name "*.sh" \
       -o -name "*.rb"  -o -name "*.txt" -o -name ".gitignore" \
       -o -name "*.bats" -o -name "*.json" \) 2>/dev/null)

COUNT=0
for f in ${PLACEHOLDER_FILES}; do
    if grep -q "{project-name}\|{package}\|{author-name}\|{author-email}\|{org}\|{project-description}" "${f}" 2>/dev/null; then
        sed -i '' \
            -e "s|{project-name}|${PROJECT_NAME}|g" \
            -e "s|{package}|${PACKAGE_NAME}|g" \
            -e "s|{author-name}|${AUTHOR_NAME}|g" \
            -e "s|{author-email}|${AUTHOR_EMAIL}|g" \
            -e "s|{org}|${ORG_NAME}|g" \
            -e "s|{project-description}|${DESCRIPTION}|g" \
            "${f}"
        COUNT=$((COUNT + 1))
        log_dim "Updated: ${f}"
    fi
done
log_success "Replaced placeholders in ${COUNT} files"

# ─────────────────────────────────────────────────────────────────────────────
# Step 7 — Set initial version
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 7/15 — Setting initial version"
if [[ "${INITIAL_VERSION}" != "0.1.0" ]]; then
    sed -i '' "s/^version = \"0.1.0\"/version = \"${INITIAL_VERSION}\"/" pyproject.toml
fi
log_success "Version: ${INITIAL_VERSION}"

# ─────────────────────────────────────────────────────────────────────────────
# Step 8 — SQL dialect
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 8/15 — Configuring SQL dialect"
if [[ "${SQL_DIALECT}" == "none" ]]; then
    log_info "SQL dialect: none — sqlfluff left at ansi default"
else
    sed -i '' "s/^dialect = \"ansi\"/dialect = \"${SQL_DIALECT}\"/" pyproject.toml
    log_success "SQL dialect: ${SQL_DIALECT}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 9 — Homebrew tap defaults in release.sh
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 9/15 — Configuring Homebrew tap path in release.sh"
if [[ -f "scripts/release.sh" ]]; then
    sed -i '' \
        -e "s|TAP_REPO_PATH=\"\${TAP_REPO_PATH:-\${HOME}/homebrew-tools}\"|TAP_REPO_PATH=\"\${TAP_REPO_PATH:-${TAP_REPO_PATH}}\"|g" \
        scripts/release.sh
    if [[ -n "${TAP_NAME}" ]]; then
        sed -i '' \
            -e "s|TAP_NAME=\"\${TAP_NAME:-\${ORG_NAME}/tools}\"|TAP_NAME=\"\${TAP_NAME:-${TAP_NAME}}\"|g" \
            scripts/release.sh
    fi
    log_success "release.sh configured with tap path: ${TAP_REPO_PATH}"
else
    log_warn "scripts/release.sh not found — configure TAP_REPO_PATH manually"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 10 — Create missing directories
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 10/15 — Ensuring directory structure"
mkdir -p \
    "src/${PACKAGE_NAME}/commands" \
    "src/${PACKAGE_NAME}/core" \
    tests/unit tests/integration tests/shell \
    docs/decisions docs/retrospectives \
    sql/migrations sql/queries sql/seeds \
    scripts

touch \
    "src/${PACKAGE_NAME}/commands/__init__.py" \
    "src/${PACKAGE_NAME}/core/__init__.py" \
    tests/__init__.py \
    tests/unit/__init__.py \
    tests/integration/__init__.py

log_success "Directory structure ready"

# ─────────────────────────────────────────────────────────────────────────────
# Step 11 — Install dependencies
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 11/15 — Installing dependencies via uv sync"
uv sync
log_success "Dependencies installed (.venv/)"

# ─────────────────────────────────────────────────────────────────────────────
# Step 12 — Make scripts executable
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 12/15 — Making scripts executable"
[[ -d "hooks/" ]] && find hooks/ -name "*.sh" -exec chmod +x {} \; && log_success "hooks/*.sh"
find scripts/ -name "*.sh" -exec chmod +x {} \;
log_success "scripts/*.sh"
[[ -f ".claude/hooks/pre_tool_use.py" ]] && chmod +x ".claude/hooks/pre_tool_use.py" && log_success ".claude/hooks/pre_tool_use.py"

# ─────────────────────────────────────────────────────────────────────────────
# Step 13 — git init (pre-commit install requires a git repo)
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 13/15 — Initialising git repository"

if [[ -d ".git" ]]; then
    log_warn ".git already exists — removing and reinitialising"
    rm -rf .git
fi

git init
git checkout -b main
log_success "Git repository initialised on branch main"

# ─────────────────────────────────────────────────────────────────────────────
# Step 14 — Install pre-commit hooks + initial commit
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 14/15 — Installing pre-commit hooks and making initial commit"
uv run pre-commit install
uv run pre-commit install --hook-type pre-push
log_success "Pre-commit hooks installed (commit + push)"

git add -A
# Skip pre-commit on the initial commit — the hook chain downloads tool binaries
# on first run and may modify files, causing an unexpected double-commit.
git commit --no-verify -m "chore: initialise ${PROJECT_NAME} from claude-sdlc-template"
log_success "Clean initial commit on main"

# ─────────────────────────────────────────────────────────────────────────────
# Step 15 — GitHub remote (optional)
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 15/15 — GitHub remote setup"
if [[ -n "${GITHUB_REMOTE}" ]]; then
    git remote add origin "${GITHUB_REMOTE}"
    log_success "Remote added: ${GITHUB_REMOTE}"
    if [[ "${NON_INTERACTIVE}" == "false" ]] && confirm "Push initial commit to origin/main now?" "n"; then
        if git ls-remote "${GITHUB_REMOTE}" &>/dev/null; then
            git push -u origin main
            log_success "Pushed to origin/main"
        else
            log_error "Cannot reach ${GITHUB_REMOTE}"
            log_error "Verify the repo exists on GitHub and you have push access, then run:"
            log_dim "  git push -u origin main"
        fi
    else
        log_dim "Run when ready: git push -u origin main"
    fi
else
    log_dim "No remote configured. Add later:"
    log_dim "  git remote add origin https://github.com/${ORG_NAME}/${PROJECT_NAME}.git"
    log_dim "  git push -u origin main"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────

echo ""
separator
echo -e "${GREEN}${BOLD}  Bootstrap complete ✓${RESET}"
separator
echo ""
echo -e "  ${BOLD}Project:${RESET}     ${PROJECT_NAME}"
echo -e "  ${BOLD}Location:${RESET}    ${DEST_DIR}"
echo -e "  ${BOLD}Package:${RESET}     ${PACKAGE_NAME}"
echo -e "  ${BOLD}Version:${RESET}     ${INITIAL_VERSION}"
echo ""
thin_sep
echo -e "\n  ${BOLD}Next steps:${RESET}\n"
N=1

[[ -z "${GITHUB_REMOTE}" ]] && {
    echo -e "  ${N}) Create the GitHub repo and push:"
    echo -e "     ${DIM}git remote add origin https://github.com/${ORG_NAME}/${PROJECT_NAME}.git${RESET}"
    echo -e "     ${DIM}git push -u origin main${RESET}"
    ((N++))
}

echo -e "  ${N}) Set up GitHub Actions secrets — see docs/DEVELOPER_GUIDE.md"
((N++))
echo -e "  ${N}) Open Claude Code: ${DIM}cd ${DEST_DIR} && claude${RESET}"
((N++))
echo -e "  ${N}) Run: ${DIM}/standup${RESET}"
((N++))
echo -e "  ${N}) Start your first feature: ${DIM}/feature \"your feature description\"${RESET}"
echo ""
thin_sep
echo -e "\n  ${DIM}Docs: ${DEST_DIR}/docs/DEVELOPER_GUIDE.md${RESET}"
echo -e "  ${DIM}Overview: ${DEST_DIR}/OVERVIEW.md${RESET}"
echo ""
separator
