#!/usr/bin/env bash
# One-time setup for the CI/CD for Ignition course. Run it from your fork's
# clone at least two days before Day 1, and again whenever preflight tells you to.
#
#   1. preflight        tools, Docker, WSL location, course images (preflight/)
#   2. git config       shared hook dispatchers + resource.json diff driver
#   3. your fork        origin is your fork, gh talks to it, Actions are enabled
#   4. lab .env files   labs 04 and 06: runner URL + the one PAT both labs share
#
# Safe to re-run: every step checks before it changes anything. Options are
# passed through to preflight (e.g. --no-pull --skip-smoke for a fast re-run).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT" || exit 1

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo -e "${RED}✗${NC} $*"; FAILURES=$((FAILURES + 1)); }
WARNINGS=0; FAILURES=0

step() { echo; echo "── $* ──────────────────────────────────────────"; }

# ---- 1. Preflight -------------------------------------------------------------
step "1/4 Preflight"
if ./preflight/scripts/preflight.sh "$@"; then
    ok "Preflight passed (report: preflight/preflight-report.txt)"
else
    fail "Preflight found problems — fix those first (report: preflight/preflight-report.txt)"
fi

# ---- 2. Git config ------------------------------------------------------------
step "2/4 Git hooks and diff driver"
if ./scripts/install-git-config.sh; then
    ok "core.hooksPath=scripts/git-hooks, resource.json diff driver registered"
else
    fail "Could not write git config for this clone"
fi

# ---- 3. Your fork -------------------------------------------------------------
step "3/4 Your fork"
origin_url="$(git remote get-url origin 2>/dev/null || true)"
# git@github.com:owner/repo.git | https://github.com/owner/repo(.git)
fork_slug="$(printf '%s' "$origin_url" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"
fork_owner="${fork_slug%%/*}"

if [ -z "$origin_url" ]; then
    fail "No 'origin' remote. Clone your fork: gh repo fork Mustry-Academy/cicd-for-ignition --clone"
elif [ "$(printf '%s' "$fork_owner" | tr '[:upper:]' '[:lower:]')" = "mustry-academy" ]; then
    fail "origin is the course repo itself ($fork_slug), not your fork. Fork it: gh repo fork Mustry-Academy/cicd-for-ignition --remote"
else
    ok "origin is your fork: $fork_slug"
fi

if ! command -v gh >/dev/null 2>&1; then
    fail "GitHub CLI (gh) not found — preflight explains how to install it"
elif ! gh auth status >/dev/null 2>&1; then
    fail "gh is not logged in. Run: gh auth login"
elif [ -n "$fork_slug" ] && [ "$fork_owner" != "Mustry-Academy" ]; then
    default_repo="$(gh repo set-default --view 2>/dev/null || true)"
    if [ "$default_repo" = "$fork_slug" ]; then
        ok "gh default repo is your fork"
    else
        if gh repo set-default "$fork_slug" >/dev/null 2>&1; then
            ok "gh default repo set to your fork ($fork_slug)"
        else
            warn "Could not set the gh default repo. Run: gh repo set-default $fork_slug"
        fi
    fi

    # A fresh fork ships with workflows switched off. GitHub reports that as
    # state "disabled_fork"; only the button in the Actions tab turns it on.
    states="$(gh api "repos/$fork_slug/actions/workflows" --jq '.workflows[].state' 2>/dev/null || true)"
    if [ -z "$states" ]; then
        warn "Could not read your fork's workflows. Check the Actions tab of https://github.com/$fork_slug"
    elif printf '%s\n' "$states" | grep -q '^disabled_fork$'; then
        fail "Actions are not enabled on your fork yet. Open https://github.com/$fork_slug/actions and click \"I understand my workflows, go ahead and enable them\""
    else
        ok "Actions are enabled on your fork"
    fi
fi

# ---- 4. Lab .env files --------------------------------------------------------
step "4/4 Lab .env files"
# Labs 04 and 06 bundle a self-hosted runner that registers against your fork
# with a classic PAT (repo scope). One token serves both labs.
RUNNER_LABS="labs/04-ignition-file-based-deploy labs/06-secrets-db-and-modules"
PLACEHOLDER_PAT="ghp_replace-me-with-a-pat-that-has-repo-scope"

set_env_var() {  # file key value
    local file="$1" key="$2" value="$3" tmp
    tmp="$(mktemp)"
    awk -v k="$key" -v v="$value" 'BEGIN{done=0} $0 ~ "^"k"=" {print k"="v; done=1; next} {print} END{if(!done) print k"="v}' "$file" >"$tmp" \
        && cat "$tmp" >"$file"
    rm -f "$tmp"
}

pat=""
for lab in $RUNNER_LABS; do
    env_file="$lab/.env"
    if [ ! -f "$env_file" ]; then
        cp "$lab/.env.example" "$env_file"
        ok "Created $env_file from .env.example"
    fi
    if [ -n "$fork_slug" ] && [ "$fork_owner" != "Mustry-Academy" ]; then
        set_env_var "$env_file" RUNNER_REPO_URL "https://github.com/$fork_slug"
    fi
    current_pat="$(sed -n 's/^RUNNER_GITHUB_PAT=//p' "$env_file")"
    if [ -n "$current_pat" ] && [ "$current_pat" != "$PLACEHOLDER_PAT" ]; then
        [ -z "$pat" ] && pat="$current_pat"
    fi
done

if [ -z "$pat" ] && [ -t 0 ]; then
    echo
    echo "Labs 04 and 06 need a GitHub Personal Access Token (classic, 'repo' scope)"
    echo "so their bundled runner can register against your fork."
    echo "Create one at https://github.com/settings/tokens → Generate new token (classic)."
    read -r -s -p "Paste it now, or press Enter to skip: " pat
    echo
fi

for lab in $RUNNER_LABS; do
    if [ -n "$pat" ]; then
        set_env_var "$lab/.env" RUNNER_GITHUB_PAT "$pat"
    fi
done
if [ -n "$pat" ]; then
    ok "Runner URL and PAT set in labs 04 and 06 (.env is git-ignored)"
else
    warn "No PAT yet — set RUNNER_GITHUB_PAT in labs/04-*/.env and labs/06-*/.env before Lab 04"
fi

# ---- Summary ------------------------------------------------------------------
echo
if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}$FAILURES problem(s) to fix${NC}, $WARNINGS warning(s). Fix, then re-run ./course-setup.sh"
    echo "Stuck? Paste preflight/preflight-report.txt and this output in Discord #preflight-help."
    exit 1
fi
echo -e "${GREEN}Ready for the course.${NC} $WARNINGS warning(s)."
echo "Paste preflight/preflight-report.txt in Discord #preflight-help so the TA can confirm."
