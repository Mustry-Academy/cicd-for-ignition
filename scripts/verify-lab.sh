#!/usr/bin/env bash
# Sanity-check the lab's spelunking + focused-commit step (You-do Phase 1).
#
# Verifies (best-effort):
#   - Phase 1's focused commit is in place, with no uncommitted changes.
#   - sample-app/README.md contains a "lab participant" line added in You-do Phase 1 step 5.
#   - HEAD's commit touched only sample-app/README.md (no incidental changes).
#
# Exit codes: 0 = all green, 1 = something to fix.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

fail=0
say_pass() { echo "✅ $1"; }
say_fail() { echo "❌ $1"; fail=1; }

# 1. Working tree should be clean.
if git diff --quiet && git diff --cached --quiet; then
  say_pass "working tree is clean"
else
  say_fail "working tree has uncommitted changes — commit them before verifying"
fi

# 2. README.md should mention "lab participant".
if grep -qi "lab participant" sample-app/README.md; then
  say_pass "sample-app/README.md mentions a lab participant"
else
  say_fail "sample-app/README.md is missing a 'lab participant' line — see You-do Phase 1 step 5"
fi

# 3. HEAD should touch only sample-app/README.md.
changed_files=$(git diff --name-only HEAD~1 HEAD | sort -u)
expected="sample-app/README.md"
if [ "$changed_files" = "$expected" ]; then
  say_pass "HEAD changes only sample-app/README.md"
else
  say_fail "HEAD touched more than expected — got:"
  printf '   %s\n' $changed_files
  echo "   expected only: $expected"
fi

if [ $fail -eq 0 ]; then
  echo
  echo "All checks passed."
  exit 0
else
  echo
  echo "Some checks failed. Revisit the You-do Phase 1 steps in exercises/lab.md."
  exit 1
fi
