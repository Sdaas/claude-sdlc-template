#!/usr/bin/env bash
# hooks/pre-commit.sh
# Runs on every git commit. Blocks if any check fails.
# Install via: bash install-hooks.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

PASS=0
FAIL=0

_pass() {
	echo "  PASS $1"
	PASS=$((PASS + 1))
}
_fail() {
	echo "  FAIL $1"
	FAIL=$((FAIL + 1))
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Pre-commit checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─────────────────────────────────────────────────────────────────────────────
# 1. shellcheck
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "shellcheck"

SHELL_FILES=()
for f in bootstrap.sh tests/test_bootstrap.sh hooks/pre-commit.sh install-hooks.sh; do
	[[ -f "${f}" ]] && SHELL_FILES+=("${f}")
done

if [[ ${#SHELL_FILES[@]} -gt 0 ]]; then
	if shellcheck "${SHELL_FILES[@]}" 2>&1; then
		_pass "shellcheck ${SHELL_FILES[*]}"
	else
		_fail "shellcheck ${SHELL_FILES[*]}"
	fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. shfmt (optional — warn if not installed)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "shfmt"

if command -v shfmt &>/dev/null; then
	if shfmt -d "${SHELL_FILES[@]}" 2>&1; then
		_pass "shfmt (no formatting differences)"
	else
		_fail "shfmt (formatting differences found — run: shfmt -w ${SHELL_FILES[*]})"
	fi
else
	echo "  WARN shfmt not installed — formatting check skipped"
	echo "       Install: brew install shfmt"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. Full test suite
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "bash tests/test_bootstrap.sh"

if bash tests/test_bootstrap.sh; then
	_pass "test suite (0 failures)"
else
	_fail "test suite (failures detected — see output above)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. Referential integrity — every path mentioned in .md files must exist
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "Referential integrity"

REF_FAIL=0

# Collect all .md files in .claude/, hooks/, and README.md
MD_FILES=()
while IFS= read -r -d '' f; do
	MD_FILES+=("${f}")
done < <(find .claude hooks -name "*.md" -print0 2>/dev/null)
[[ -f README.md ]] && MD_FILES+=("README.md")

# Extract only markdown links [text](path) and check the paths exist.
# We only flag paths that start with known local prefixes to avoid
# false positives from code examples referencing scaffolded projects.
for md in "${MD_FILES[@]}"; do
	while IFS= read -r path; do
		# Skip http links and template placeholders
		[[ "${path}" == http* ]] && continue
		[[ "${path}" == *'{'* ]] && continue
		[[ "${path}" == *'#'* ]] && continue
		# Strip leading ./
		path="${path#./}"
		# Only check paths in this repo's own directories
		if [[ "${path}" == .claude/* ]] ||
			[[ "${path}" == hooks/* ]] ||
			[[ "${path}" == tests/* ]] ||
			[[ "${path}" == docs/* ]] ||
			[[ "${path}" == scaffold/* ]]; then
			if [[ ! -e "${path}" ]]; then
				echo "  BROKEN REF in ${md}: '${path}' does not exist"
				REF_FAIL=$((REF_FAIL + 1))
			fi
		fi
	done < <(grep -oE '\]\([^)]+\)' "${md}" 2>/dev/null | sed 's/^](\(.*\))$/\1/' || true)
done

# Every file in .claude/commands/, .claude/skills/*, and hooks/ must appear in README.md
if [[ -f README.md ]]; then
	for dir in .claude/commands .claude/skills hooks; do
		while IFS= read -r -d '' f; do
			# Get the basename and partial path for lookup
			rel="${f#./}"
			base="$(basename "${f}")"
			# Check README.md mentions either the relative path or the filename
			if ! grep -qF "${base}" README.md && ! grep -qF "${rel}" README.md; then
				echo "  UNDOCUMENTED in README.md: '${rel}'"
				REF_FAIL=$((REF_FAIL + 1))
			fi
		done < <(find "${dir}" -type f -print0 2>/dev/null)
	done
fi

if [[ ${REF_FAIL} -eq 0 ]]; then
	_pass "referential integrity"
else
	_fail "referential integrity (${REF_FAIL} issue(s) — see above)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ${FAIL} -gt 0 ]]; then
	exit 1
fi
