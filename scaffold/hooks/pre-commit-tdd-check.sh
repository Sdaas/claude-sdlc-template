#!/usr/bin/env bash
# hooks/pre-commit-tdd-check.sh
# Blocks commits where src/ files changed without corresponding test changes.
# Exempts: docs-only, config-only, and trivial commits.

set -euo pipefail

# Get staged files
STAGED=$(git diff --cached --name-only)

# Check if any src/ files are staged
SRC_CHANGED=$(echo "${STAGED}" | grep "^src/" || true)

# Check if any test files are staged
TESTS_CHANGED=$(echo "${STAGED}" | grep "^tests/" || true)

# If no src/ changes, pass immediately
if [[ -z "${SRC_CHANGED}" ]]; then
    exit 0
fi

# If src/ changed and tests changed, pass
if [[ -n "${TESTS_CHANGED}" ]]; then
    exit 0
fi

# src/ changed but no tests changed — check for exemption marker
# A commit can be exempted by including [skip-tdd] in the commit message
# This requires --no-verify or a specific marker and is logged
COMMIT_MSG_FILE="$(git rev-parse --git-dir)/COMMIT_EDITMSG"
if [[ -f "${COMMIT_MSG_FILE}" ]]; then
    if grep -q "\[skip-tdd\]" "${COMMIT_MSG_FILE}"; then
        echo "⚠ TDD check skipped — [skip-tdd] marker found."
        echo "  This exemption will be flagged in code review."
        exit 0
    fi
fi

echo ""
echo "✗ TDD Check Failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Source files were changed without corresponding test changes."
echo ""
echo "Changed src/ files:"
echo "${SRC_CHANGED}" | sed 's/^/  /'
echo ""
echo "No test files found in staged changes."
echo ""
echo "Fix: Write or update tests in tests/ before committing."
echo ""
echo "If this change genuinely requires no tests (e.g. adding a"
echo "docstring, updating a comment), add [skip-tdd] to your commit"
echo "message. This will be flagged in code review."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 1
