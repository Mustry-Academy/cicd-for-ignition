#!/usr/bin/env bash
# One-time git config for this clone. Every lab's setup.sh calls this, and so
# does course-setup.sh; running it again is harmless.
#
#   core.hooksPath          -> scripts/git-hooks (the dispatchers that run each
#                              lab's own hooks, scoped to that lab)
#   diff.ignition-resource  -> textconv normalizer, so Designer metadata churn in
#                              resource.json stays out of `git diff` in every lab
set -euo pipefail

top="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"

# Relative hooksPath resolves against the top of the working tree.
git -C "$top" config core.hooksPath scripts/git-hooks
git -C "$top" config diff.ignition-resource.textconv \
    "$top/scripts/git-diff/normalize-ignition-resource-json.py"

# Hooks from the old per-lab setup (symlinks in .git/hooks) are ignored once
# core.hooksPath is set, so there is nothing to clean up.
