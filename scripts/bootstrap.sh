#!/usr/bin/env bash
# scripts/bootstrap.sh — Initialise a new project from claude-sdlc-template
#
# Usage (interview mode — recommended):
#   ./scripts/bootstrap.sh
#
# Usage (argument mode — for automation):
#   ./scripts/bootstrap.sh \
#     --project-name my-tool \
#     --package-name mytool \
#     --author-name "Jane Smith" \
#     --author-email "jane@example.com" \
#     --org "jane-org" \
#     --sql-dialect postgres \
#     --tap-repo-path ~/homebrew-tools \
#     --tap-name "jane-org/tools" \
#     --version 0.1.0 \
#     --description "A Python CLI tool" \
#     --github-remote "https://github.com/jane-org/my-tool.git"
#
# What this script does:
#   1.  Checks prerequisites
#   2.  Interviews the developer (or reads arguments)
#   3.  Shows a confirmation summary
#   4.  Renames the package directory
#   5.  Replaces all template placeholders throughout the repo
#   6.  Sets the initial version
#   7.  Configures SQL dialect in pyproject.toml
#   8.  Configures Homebrew tap path in release.sh
#   9.  Creates the full directory structure
#   10. Installs dependencies via uv
#   11. Makes scripts and hooks executable
#   12. Installs pre-commit hooks
#   13. Reinitialises git with a clean initial commit
#   14. Optionally sets up GitHub remote and pushes
#   15. Optionally clones the Homebrew tap repo

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Colours and formatting
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
# Input helpers
# ─────────────────────────────────────────────────────────────────────────────

ask() {
    # ask "Question" "default" VAR_NAME
    local question="$1"
    local default="$2"
    local var_name="$3"
    local prompt user_input

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
    # ask_choice "Question" "opt1|opt2|opt3" "default" VAR_NAME
    local question="$1"
    local options_str="$2"
    local default="$3"
    local var_name="$4"

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
    local prompt="${1:-Continue?}"
    local default="${2:-n}"
    local response

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
    log_error "Project name must be lowercase, start with a letter, and use only letters, numbers, hyphens. Got: $1"
    return 1
}

validate_package_name() {
    [[ "$1" =~ ^[a-z][a-z0-9_]*$ ]] && return 0
    log_error "Package name must be lowercase, start with a letter, and use only letters, numbers, underscores. Got: $1"
    return 1
}

validate_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 0
    log_error "Version must be MAJOR.MINOR.PATCH format (e.g. 0.1.0). Got: $1"
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

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
INTERVIEW_MODE=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-name)   ARG_PROJECT_NAME="$2";    shift 2 ;;
        --package-name)   ARG_PACKAGE_NAME="$2";    shift 2 ;;
        --author-name)    ARG_AUTHOR_NAME="$2";     shift 2 ;;
        --author-email)   ARG_AUTHOR_EMAIL="$2";    shift 2 ;;
        --org)            ARG_ORG="$2";             shift 2 ;;
        --sql-dialect)    ARG_SQL_DIALECT="$2";     shift 2 ;;
        --tap-repo-path)  ARG_TAP_REPO_PATH="$2";  shift 2 ;;
        --tap-name)       ARG_TAP_NAME="$2";        shift 2 ;;
        --version)        ARG_INITIAL_VERSION="$2"; shift 2 ;;
        --description)    ARG_DESCRIPTION="$2";     shift 2 ;;
        --github-remote)  ARG_GITHUB_REMOTE="$2";   shift 2 ;;
        --no-interview)   INTERVIEW_MODE=false;      shift ;;
        --help|-h)
            echo "Usage: ./scripts/bootstrap.sh [options]"
            echo ""
            echo "Run without options for interactive interview mode (recommended)."
            echo ""
            echo "Options:"
            echo "  --project-name   Kebab-case project name (e.g. my-tool)"
            echo "  --package-name   Snake_case Python package name (e.g. mytool)"
            echo "  --author-name    Your full name"
            echo "  --author-email   Your email address"
            echo "  --org            GitHub organisation or username"
            echo "  --sql-dialect    SQL dialect: ansi|sqlite|postgres|mysql|bigquery|none"
            echo "  --tap-repo-path  Path to Homebrew tap repo (default: ~/homebrew-tools)"
            echo "  --tap-name       Homebrew tap name (e.g. myorg/tools)"
            echo "  --version        Initial version (default: 0.1.0)"
            echo "  --description    One-line project description"
            echo "  --github-remote  GitHub remote URL"
            echo "  --no-interview   Skip interview — use argument values only"
            echo "  --help           Show this help"
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1. Run --help for usage."
            exit 1
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Header
# ─────────────────────────────────────────────────────────────────────────────

separator
echo -e "${BOLD}  claude-sdlc-template — Project Bootstrap${RESET}"
separator
echo ""
echo -e "  Answer the questions below. Press Enter to accept the default shown in [brackets]."
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Interview
# ─────────────────────────────────────────────────────────────────────────────

if [[ "${INTERVIEW_MODE}" == "true" ]]; then

    # ── Section 1: Project Identity ──────────────────────────────────────────

    thin_sep
    echo -e "\n  ${CYAN}${BOLD}1 / 4 — Project Identity${RESET}"
    thin_sep

    while true; do
        PREFILL="${ARG_PROJECT_NAME}"
        ask "Project name (kebab-case, e.g. my-tool)" "${PREFILL}" PROJECT_NAME
        validate_project_name "${PROJECT_NAME}" && break
    done

    SUGGESTED_PACKAGE=$(echo "${PROJECT_NAME}" | tr '-' '_')
    while true; do
        PREFILL="${ARG_PACKAGE_NAME:-${SUGGESTED_PACKAGE}}"
        ask "Python package name (snake_case)" "${PREFILL}" PACKAGE_NAME
        validate_package_name "${PACKAGE_NAME}" && break
    done

    ask "One-line description" "${ARG_DESCRIPTION:-A Python CLI tool}" DESCRIPTION

    while true; do
        ask "Initial version" "${ARG_INITIAL_VERSION:-0.1.0}" INITIAL_VERSION
        validate_semver "${INITIAL_VERSION}" && break
    done

    # ── Section 2: Author and Organisation ───────────────────────────────────

    thin_sep
    echo -e "\n  ${CYAN}${BOLD}2 / 4 — Author and Organisation${RESET}"
    thin_sep

    ask "Your full name" "${ARG_AUTHOR_NAME:-}" AUTHOR_NAME
    ask "Your email address" "${ARG_AUTHOR_EMAIL:-}" AUTHOR_EMAIL
    ask "GitHub organisation or username" "${ARG_ORG:-}" ORG_NAME

    SUGGESTED_REMOTE=""
    [[ -n "${ORG_NAME}" ]] && SUGGESTED_REMOTE="https://github.com/${ORG_NAME}/${PROJECT_NAME}.git"
    ask "GitHub remote URL (leave blank to set up later)" \
        "${ARG_GITHUB_REMOTE:-${SUGGESTED_REMOTE}}" GITHUB_REMOTE

    # ── Section 3: SQL ───────────────────────────────────────────────────────

    thin_sep
    echo -e "\n  ${CYAN}${BOLD}3 / 4 — SQL Configuration${RESET}"
    thin_sep
    echo -e "\n  ${DIM}If your project uses SQL, select the dialect for sqlfluff.${RESET}"
    echo -e "  ${DIM}Choose 'none' if the project has no SQL. Choose 'ansi' if unsure.${RESET}"

    ask_choice "SQL dialect" \
        "ansi|sqlite|postgres|mysql|bigquery|none" \
        "${ARG_SQL_DIALECT:-ansi}" \
        SQL_DIALECT

    # ── Section 4: Homebrew ──────────────────────────────────────────────────

    thin_sep
    echo -e "\n  ${CYAN}${BOLD}4 / 4 — Homebrew Tap Repository${RESET}"
    thin_sep
    echo -e "\n  ${DIM}The tap repo is where your Homebrew formula lives.${RESET}"
    echo -e "  ${DIM}It is a separate GitHub repo, usually named homebrew-tools.${RESET}"
    echo -e "  ${DIM}See DEVELOPER_GUIDE.md — 'Homebrew Tap Setup' for full instructions.${RESET}"

    ask "Local path to Homebrew tap repo" \
        "${ARG_TAP_REPO_PATH:-${HOME}/homebrew-tools}" TAP_REPO_PATH
    TAP_REPO_PATH="${TAP_REPO_PATH/#\~/${HOME}}"

    SUGGESTED_TAP_NAME="${ORG_NAME:+${ORG_NAME}/tools}"
    ask "Homebrew tap name (used in 'brew tap')" \
        "${ARG_TAP_NAME:-${SUGGESTED_TAP_NAME}}" TAP_NAME

else
    # Non-interview: use arguments directly
    PROJECT_NAME="${ARG_PROJECT_NAME}"
    PACKAGE_NAME="${ARG_PACKAGE_NAME:-$(echo "${PROJECT_NAME}" | tr '-' '_')}"
    DESCRIPTION="${ARG_DESCRIPTION:-A Python CLI tool}"
    INITIAL_VERSION="${ARG_INITIAL_VERSION:-0.1.0}"
    AUTHOR_NAME="${ARG_AUTHOR_NAME:-}"
    AUTHOR_EMAIL="${ARG_AUTHOR_EMAIL:-}"
    ORG_NAME="${ARG_ORG:-}"
    GITHUB_REMOTE="${ARG_GITHUB_REMOTE:-}"
    SQL_DIALECT="${ARG_SQL_DIALECT:-ansi}"
    TAP_REPO_PATH="${ARG_TAP_REPO_PATH:-${HOME}/homebrew-tools}"
    TAP_REPO_PATH="${TAP_REPO_PATH/#\~/${HOME}}"
    TAP_NAME="${ARG_TAP_NAME:-${ORG_NAME:+${ORG_NAME}/tools}}"

    validate_project_name "${PROJECT_NAME}" || exit 1
    validate_package_name "${PACKAGE_NAME}" || exit 1
    validate_semver "${INITIAL_VERSION}"     || exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Confirmation summary
# ─────────────────────────────────────────────────────────────────────────────

echo ""
separator
echo -e "${BOLD}  Review your answers${RESET}"
separator
echo ""
echo -e "  ${BOLD}Project name:${RESET}       ${PROJECT_NAME}"
echo -e "  ${BOLD}Package name:${RESET}       ${PACKAGE_NAME}"
echo -e "  ${BOLD}Description:${RESET}        ${DESCRIPTION}"
echo -e "  ${BOLD}Initial version:${RESET}    ${INITIAL_VERSION}"
echo -e "  ${BOLD}Author name:${RESET}        ${AUTHOR_NAME:-'(not provided)'}"
echo -e "  ${BOLD}Author email:${RESET}       ${AUTHOR_EMAIL:-'(not provided)'}"
echo -e "  ${BOLD}GitHub org/user:${RESET}    ${ORG_NAME:-'(not provided)'}"
echo -e "  ${BOLD}GitHub remote:${RESET}      ${GITHUB_REMOTE:-'(set up later)'}"
echo -e "  ${BOLD}SQL dialect:${RESET}        ${SQL_DIALECT}"
echo -e "  ${BOLD}Tap repo path:${RESET}      ${TAP_REPO_PATH}"
echo -e "  ${BOLD}Tap name:${RESET}           ${TAP_NAME:-'(not provided)'}"
echo ""
echo -e "  ${DIM}This will rename the package dir, replace all placeholders, install${RESET}"
echo -e "  ${DIM}dependencies, set up hooks, and reinitialise git history.${RESET}"
echo ""

confirm_or_abort "Everything correct? Proceed with bootstrap?"

# ─────────────────────────────────────────────────────────────────────────────
# Execution steps
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 1/15 — Checking prerequisites"

FAILED=false
command -v uv  &>/dev/null && log_success "uv: $(uv --version)"  || { log_error "uv not found. Install: curl -LsSf https://astral.sh/uv/install.sh | sh"; FAILED=true; }
command -v git &>/dev/null && log_success "git: $(git --version)" || { log_error "git not found."; FAILED=true; }
[[ "${FAILED}" == "true" ]] && { log_error "Fix prerequisites and re-run."; exit 1; }

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 2/15 — Renaming package directory"

if [[ -d "src/{package}" ]]; then
    mv "src/{package}" "src/${PACKAGE_NAME}"
    log_success "Renamed src/{package}/ → src/${PACKAGE_NAME}/"
elif [[ -d "src/${PACKAGE_NAME}" ]]; then
    log_info "src/${PACKAGE_NAME}/ already exists — skipping"
else
    log_warn "src/{package}/ not found — creating src/${PACKAGE_NAME}/"
    mkdir -p "src/${PACKAGE_NAME}"
fi
touch "src/${PACKAGE_NAME}/__init__.py" "src/${PACKAGE_NAME}/cli.py"
log_success "Package directory ready"

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 3/15 — Replacing template placeholders"

FILES=$(find . \
    -not -path "./.git/*" -not -path "./.venv/*" \
    -not -path "./__pycache__/*" -not -path "./dist/*" \
    -not -path "./build/*" -not -name "bootstrap.sh" \
    -type f \
    \( -name "*.py" -o -name "*.md" -o -name "*.toml" \
       -o -name "*.yaml" -o -name "*.yml" -o -name "*.sh" \
       -o -name "*.rb"  -o -name "*.txt" -o -name ".gitignore" \
       -o -name "*.bats" \) 2>/dev/null)

COUNT=0
for f in ${FILES}; do
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

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 4/15 — Setting initial version"
[[ "${INITIAL_VERSION}" != "0.1.0" ]] && \
    sed -i '' "s/^version = \"0.1.0\"/version = \"${INITIAL_VERSION}\"/" pyproject.toml
log_success "Version: ${INITIAL_VERSION}"

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 5/15 — Configuring SQL dialect"
if [[ "${SQL_DIALECT}" == "none" ]]; then
    log_info "SQL dialect: none — sqlfluff left as ansi default"
    log_dim "Remove [tool.sqlfluff.core] from pyproject.toml and sqlfluff from dev-deps if unused"
else
    sed -i '' "s/^dialect = \"ansi\"/dialect = \"${SQL_DIALECT}\"/" pyproject.toml
    log_success "SQL dialect: ${SQL_DIALECT}"
fi

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 6/15 — Configuring Homebrew tap path in release.sh"
if [[ -f "scripts/release.sh" ]]; then
    sed -i '' \
        -e "s|TAP_REPO_PATH=\"\${TAP_REPO_PATH:-\${HOME}/homebrew-tools}\"|TAP_REPO_PATH=\"\${TAP_REPO_PATH:-${TAP_REPO_PATH}}\"|g" \
        scripts/release.sh
    [[ -n "${TAP_NAME}" ]] && sed -i '' \
        -e "s|TAP_NAME=\"\${TAP_NAME:-\${ORG_NAME}/tools}\"|TAP_NAME=\"\${TAP_NAME:-${TAP_NAME}}\"|g" \
        scripts/release.sh
    log_success "release.sh configured"
else
    log_warn "scripts/release.sh not found — configure TAP_REPO_PATH manually"
fi

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 7/15 — Creating directory structure"
mkdir -p \
    "src/${PACKAGE_NAME}/commands" \
    "src/${PACKAGE_NAME}/core" \
    tests/unit tests/integration tests/shell \
    docs/decisions docs/retrospectives \
    sql/migrations sql/queries sql/seeds \
    scripts \
    .claude/hooks

touch \
    "src/${PACKAGE_NAME}/commands/__init__.py" \
    "src/${PACKAGE_NAME}/core/__init__.py" \
    tests/__init__.py tests/conftest.py \
    sql/migrations/.gitkeep \
    sql/queries/.gitkeep \
    sql/seeds/.gitkeep

# Copy .claude/ settings and hook from scaffold
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$(dirname "${SCRIPT_DIR}")"
SCAFFOLD_CLAUDE="${TEMPLATE_ROOT}/scaffold/.claude"

if [[ -d "${SCAFFOLD_CLAUDE}" ]]; then
    if [[ ! -f ".claude/settings.json" ]]; then
        cp "${SCAFFOLD_CLAUDE}/settings.json" ".claude/settings.json"
        log_success ".claude/settings.json installed"
    else
        log_dim ".claude/settings.json already exists — skipping"
    fi
    if [[ ! -f ".claude/hooks/pre_tool_use.py" ]]; then
        cp "${SCAFFOLD_CLAUDE}/hooks/pre_tool_use.py" ".claude/hooks/pre_tool_use.py"
        chmod +x ".claude/hooks/pre_tool_use.py"
        log_success ".claude/hooks/pre_tool_use.py installed"
    else
        log_dim ".claude/hooks/pre_tool_use.py already exists — skipping"
    fi
else
    log_warn "scaffold/.claude/ not found — install .claude/settings.json and"
    log_warn ".claude/hooks/pre_tool_use.py manually (see DEVELOPER_GUIDE.md)"
fi

log_success "Directory structure created"

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 8/15 — Installing dependencies via uv"
uv sync
log_success "Dependencies installed (.venv/)"

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 9/15 — Making scripts executable"
[[ -d "hooks/" ]] && chmod +x hooks/*.sh && log_success "hooks/*.sh"
find scripts/ -name "*.sh" -exec chmod +x {} \;
log_success "scripts/*.sh"

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 10/15 — Installing pre-commit hooks"
uv run pre-commit install
uv run pre-commit install --hook-type pre-push
log_success "Pre-commit hooks installed (commit + push)"

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 11/15 — Reinitialising git history"
log_info "Removes template history and starts fresh with one clean commit."
confirm_or_abort "Reinitialise git?"

rm -rf .git
git init
git checkout -b main
git add -A
git commit -m "chore: initialise ${PROJECT_NAME} from claude-sdlc-template"
log_success "Clean initial commit on main"

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 12/15 — GitHub remote setup"
if [[ -n "${GITHUB_REMOTE}" ]]; then
    git remote add origin "${GITHUB_REMOTE}"
    log_success "Remote added: ${GITHUB_REMOTE}"
    if confirm "Push initial commit to origin/main now?" "n"; then
        git push -u origin main
        log_success "Pushed to origin/main"
    else
        log_dim "Run when ready: git push -u origin main"
    fi
else
    log_dim "No remote configured — add later:"
    log_dim "  git remote add origin https://github.com/${ORG_NAME:-{org}}/${PROJECT_NAME}.git"
    log_dim "  git push -u origin main"
fi

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 13/15 — Homebrew tap repo"
if [[ -d "${TAP_REPO_PATH}" ]]; then
    log_success "Tap repo found at ${TAP_REPO_PATH}"
else
    log_warn "Tap repo not found at ${TAP_REPO_PATH}"
    if [[ -n "${ORG_NAME}" ]]; then
        SUGGESTED_TAP_URL="https://github.com/${ORG_NAME}/homebrew-tools.git"
        log_info "Expected: ${SUGGESTED_TAP_URL}"
        if confirm "Clone tap repo to ${TAP_REPO_PATH}?" "n"; then
            git clone "${SUGGESTED_TAP_URL}" "${TAP_REPO_PATH}"
            log_success "Cloned to ${TAP_REPO_PATH}"
        else
            log_dim "Set up tap manually — see DEVELOPER_GUIDE.md"
        fi
    else
        log_dim "Set up tap manually — see DEVELOPER_GUIDE.md"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 14/15 — Verifying configuration"
log_info "Entry point:"
grep -A1 "\[project.scripts\]" pyproject.toml | tail -1
log_info "Package:"
grep "^name" pyproject.toml
log_info "Version:"
grep "^version" pyproject.toml
log_info "SQL dialect:"
grep "^dialect" pyproject.toml || echo "  (not configured)"

log_info "Claude Code environment:"
if [[ -f ".claude/settings.json" ]]; then
    log_success ".claude/settings.json present"
else
    log_warn ".claude/settings.json MISSING — Claude Code will not have venv injection"
fi
if [[ -f ".claude/hooks/pre_tool_use.py" ]]; then
    log_success ".claude/hooks/pre_tool_use.py present"
else
    log_warn ".claude/hooks/pre_tool_use.py MISSING — bare python/pip will not be blocked"
fi

# ──────────────────────────────────────────────────────────────────────────────

log_step "Step 15/15 — Running pre-commit on initial files"
log_info "This may auto-fix some formatting issues and re-commit."
if uv run pre-commit run --all-files; then
    log_success "Pre-commit passed"
else
    log_warn "Pre-commit made fixes — committing auto-fixed files"
    git add -A
    git commit -m "style: apply pre-commit auto-fixes on initial bootstrap"
    log_success "Auto-fixes committed"
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
echo -e "  ${BOLD}Package:${RESET}     ${PACKAGE_NAME}"
echo -e "  ${BOLD}Version:${RESET}     ${INITIAL_VERSION}"
echo -e "  ${BOLD}SQL:${RESET}         ${SQL_DIALECT}"
echo -e "  ${BOLD}Tap path:${RESET}    ${TAP_REPO_PATH}"
echo ""
thin_sep
echo -e "\n  ${BOLD}Next steps:${RESET}"
echo ""
N=1

[[ -z "${GITHUB_REMOTE}" ]] && {
    echo -e "  ${N}) Add GitHub remote and push:"
    echo -e "     ${DIM}git remote add origin https://github.com/${ORG_NAME:-{org}}/${PROJECT_NAME}.git${RESET}"
    echo -e "     ${DIM}git push -u origin main${RESET}"
    ((N++))
}

[[ ! -d "${TAP_REPO_PATH}" ]] && {
    echo -e "  ${N}) Set up Homebrew tap repo — see DEVELOPER_GUIDE.md"
    ((N++))
}

echo -e "  ${N}) Set up GitHub Actions secrets in repo settings — see DEVELOPER_GUIDE.md"
((N++))
echo -e "  ${N}) Open Claude Code: ${DIM}claude${RESET}"
((N++))
echo -e "  ${N}) Run: ${DIM}/standup${RESET}"
((N++))
echo -e "  ${N}) Start your first feature: ${DIM}/feature \"your feature description\"${RESET}"
echo ""
thin_sep
echo -e "\n  ${DIM}Full docs:  DEVELOPER_GUIDE.md${RESET}"
echo -e "  ${DIM}Overview:   OVERVIEW.md${RESET}"
echo ""
separator
