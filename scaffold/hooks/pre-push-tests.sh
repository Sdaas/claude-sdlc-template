#!/usr/bin/env bash
# hooks/pre-push-tests.sh
# Runs the full test suite before any push.
# Coverage must not regress. All tests must pass.

set -euo pipefail

echo ""
echo "▶ Pre-push: Running full test suite..."
echo ""

# Run pytest with coverage
if ! uv run pytest; then
    echo ""
    echo "✗ Pre-push check failed — tests did not pass."
    echo "  Fix all failing tests before pushing."
    echo ""
    exit 1
fi

echo ""
echo "✓ Pre-push check passed — all tests passing, coverage OK."
echo ""

exit 0
