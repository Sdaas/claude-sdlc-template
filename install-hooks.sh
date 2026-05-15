#!/usr/bin/env bash
# hooks/install-hooks.sh
# One-time setup: symlinks the pre-commit hook and checks prerequisites.
# Run from the repo root: bash hooks/install-hooks.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installing pre-commit hook"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

FAIL=0

# ─────────────────────────────────────────────────────────────────────────────
# Check prerequisites
# ─────────────────────────────────────────────────────────────────────────────

echo "Checking prerequisites..."
echo ""

# Required tool: shellcheck
if command -v shellcheck &>/dev/null; then
	echo "  OK  shellcheck $(shellcheck --version | grep version: | awk '{print $2}')"
else
	echo "  FAIL shellcheck not found (required)"
	echo "       Install: brew install shellcheck"
	((FAIL++))
fi

# shfmt — recommended
if command -v shfmt &>/dev/null; then
	echo "  OK  shfmt $(shfmt --version)"
else
	echo "  WARN shfmt not found (recommended)"
	echo "       Install: brew install shfmt"
	echo "       The pre-commit hook will skip formatting checks without it."
fi

echo ""

if [[ ${FAIL} -gt 0 ]]; then
	echo "Install missing required tools and re-run this script."
	echo ""
	exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Install the hook
# ─────────────────────────────────────────────────────────────────────────────

HOOK_SOURCE="${REPO_ROOT}/hooks/pre-commit.sh"
HOOK_DEST="${REPO_ROOT}/.git/hooks/pre-commit"

chmod +x "${HOOK_SOURCE}"

if [[ -L "${HOOK_DEST}" ]]; then
	echo "Removing existing symlink at .git/hooks/pre-commit"
	rm "${HOOK_DEST}"
elif [[ -f "${HOOK_DEST}" ]]; then
	echo "Backing up existing hook to .git/hooks/pre-commit.bak"
	mv "${HOOK_DEST}" "${HOOK_DEST}.bak"
fi

ln -sf "${HOOK_SOURCE}" "${HOOK_DEST}"

echo "Installed: .git/hooks/pre-commit → hooks/pre-commit.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setup complete. The pre-commit hook will"
echo "run on every git commit and block if:"
echo "  - shellcheck finds warnings"
echo "  - tests/test_bootstrap.sh has failures"
echo "  - referential integrity checks fail"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
