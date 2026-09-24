#!/usr/bin/env bash
# Pull fixes from the original per-lab repos into this monorepo.
#
# While the separate repos (Mustry-Academy/cicd-lab-0X-…, cicd-preflight,
# cicd-welcome-package) stay the place where fixes land, run this to merge
# them in. Each folder was imported with `git subtree add`, so `subtree pull`
# merges upstream changes on top of the monorepo's own edits.
#
#   scripts/instructor/sync-from-upstream.sh            # every folder
#   scripts/instructor/sync-from-upstream.sh labs/04-ignition-file-based-deploy
#
# Needs a clean working tree. Stops at the first conflict. Expect these:
#   - upstream edited a file the monorepo deleted (instructor-notes/, the MQTT
#     Engine module and its config, lab 07's capstone/): keep it deleted with
#     `git rm <path>`, then `git commit`.
#   - upstream edited a workflow: the monorepo moved workflows to the root as
#     .github/workflows/labNN-*.yml, so the change reappears under
#     labs/<lab>/.github/workflows/. Port it to the root file by hand, then
#     delete the lab copy. The script lists any such files at the end.
# When the separate repos are retired, stop running this and delete it.
set -euo pipefail

top="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$top"

# prefix | upstream repo | squash (lab 01 keeps full history: its exercises
# run git blame / git log -L against it)
FOLDERS="
preflight|cicd-preflight|squash
labs/01-git-fundamentals|cicd-lab-01-git-fundamentals|history
labs/02-branching-and-prs|cicd-lab-02-branching-and-prs|squash
labs/03-github-actions|cicd-lab-03-github-actions|squash
labs/04-ignition-file-based-deploy|cicd-lab-04-ignition-file-based-deploy|squash
labs/05-ignition-image-based-deploy|cicd-lab-05-ignition-image-based-deploy|squash
labs/06-secrets-db-and-modules|cicd-lab-06-secrets-db-and-modules|squash
labs/07-multi-gateway-deploy|cicd-lab-07-multi-gateway-deploy|squash
welcome-package|cicd-welcome-package|squash
"

if [ -n "$(git status --porcelain)" ]; then
    echo "Working tree is not clean. Commit or stash first." >&2
    exit 1
fi

only="${1:-}"
while IFS='|' read -r prefix repo mode; do
    [ -n "$prefix" ] || continue
    [ -z "$only" ] || [ "$only" = "$prefix" ] || continue
    echo "── $prefix ← Mustry-Academy/$repo"
    flags=()
    [ "$mode" = "squash" ] && flags=(--squash)
    if ! git subtree pull "${flags[@]}" --prefix="$prefix" \
            "git@github.com:Mustry-Academy/$repo.git" main \
            -m "Sync $prefix from Mustry-Academy/$repo"; then
        echo
        echo "Conflict in $prefix. Resolve it (see the notes at the top of this script)," >&2
        echo "commit, then re-run for the remaining folders." >&2
        exit 1
    fi
done <<<"$FOLDERS"

stray="$(git ls-files 'labs/*/.github/workflows/*' 'preflight/.github/workflows/*' | grep -v '^labs/07-multi-gateway-deploy/' || true)"
if [ -n "$stray" ]; then
    echo
    echo "Upstream workflow changes to port to the root .github/workflows/ by hand:"
    printf '%s\n' "$stray" | sed 's/^/  /'
fi
