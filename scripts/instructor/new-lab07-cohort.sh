#!/usr/bin/env bash
# new-lab07-cohort.sh — generate a cohort's shared lab 07 repo from the
# monorepo template in labs/07-multi-gateway-deploy/.
#
# What it does, in order:
#   1. pre-flight: tools, gh login, the repo must NOT exist yet, the org plan
#      must support rulesets for the chosen visibility
#   2. builds a fresh single-commit repo from labs/07-multi-gateway-deploy/
#      at the monorepo's HEAD (no monorepo history), fills in the cohort name
#      and tags every pin in release.yaml (e.g. oatmakers@v4.4.4)
#   3. creates Mustry-Academy/cicd-lab-07-<cohort>, pushes main + tags with
#      Actions disabled (so the first push deploys nothing)
#   4. applies the settings copied from the original shared repo: merge
#      settings, topics, team access, rulesets, Actions permissions, secrets
#   5. re-enables Actions, invites the collaborators, checks the production
#      runner is visible to the new repo
#
# Usage:
#   scripts/instructor/new-lab07-cohort.sh <cohort-slug> [options]
#
# Options:
#   --collaborators FILE   one GitHub username per line (# comments allowed)
#   --public               create a public repo (see README: Free-plan orgs
#                          only get rulesets on public repos)
#   --allow-dirty          ship HEAD even if labs/07 has uncommitted changes
#   --dry-run              build the tree locally, print every gh / git push
#                          call instead of running it
#
# Secrets come from the environment (never from arguments, never echoed):
#   LAB07_IGNITION_API_KEY     optional; normally minted afterwards with
#                              scripts/mint-api-key.sh on the capstone box
#   LAB07_POSTGRES_USERNAME    prompted for when unset and stdin is a TTY
#   LAB07_POSTGRES_PASSWORD    prompted for when unset and stdin is a TTY
# Optional repo variables (unset = the workflow's built-in default):
#   LAB07_IGNITION_CONTAINER, LAB07_IGNITION_URL,
#   LAB07_POSTGRES_CONTAINER, LAB07_POSTGRES_DB
#
# See scripts/instructor/README.md for the manual steps around this script.
set -euo pipefail

ORG="Mustry-Academy"
TEMPLATE_DIR="labs/07-multi-gateway-deploy"
TEAM_SLUG="mustry-solutions"        # admin on the original repo
TEAM_PERMISSION="admin"
PARTICIPANT_PERMISSION="push"       # API name for the "write" role participants had
PROD_RUNNER_LABEL="cicd-capstone"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_DIR="$SCRIPT_DIR/lab07"

# ---- output helpers ---------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
else
  BOLD=''; RED=''; GREEN=''; YELLOW=''; NC=''
fi
step() { echo; echo "${BOLD}==> $*${NC}"; }
ok()   { echo "  ${GREEN}ok${NC} $*"; }
warn() { echo "  ${YELLOW}warning:${NC} $*" >&2; }
die()  { echo "${RED}error:${NC} $*" >&2; exit 1; }

usage() { sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//'; }

# ---- arguments --------------------------------------------------------------
COHORT=""
COLLABORATORS_FILE=""
VISIBILITY="private"
ALLOW_DIRTY=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --collaborators) [ $# -ge 2 ] || die "--collaborators needs a file"; COLLABORATORS_FILE="$2"; shift 2 ;;
    --collaborators=*) COLLABORATORS_FILE="${1#*=}"; shift ;;
    --public) VISIBILITY="public"; shift ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) [ -z "$COHORT" ] || die "only one cohort slug, got '$COHORT' and '$1'"; COHORT="$1"; shift ;;
  esac
done

[ -n "$COHORT" ] || { usage; exit 1; }
[[ "$COHORT" =~ ^[a-z0-9][a-z0-9-]{0,40}$ ]] \
  || die "cohort slug '$COHORT' must be lowercase letters, digits and dashes (e.g. 2026-10)"
REPO_NAME="cicd-lab-07-$COHORT"
REPO="$ORG/$REPO_NAME"

if [ -n "$COLLABORATORS_FILE" ] && [ ! -r "$COLLABORATORS_FILE" ]; then
  die "cannot read collaborators file: $COLLABORATORS_FILE"
fi

# run: every call that changes something on GitHub goes through here.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run]'; printf ' %q' "$@"; echo
  else
    "$@"
  fi
}

# gh_api_json METHOD PATH BODY — BODY is a JSON file, or inline JSON.
gh_api_json() {
  local method="$1" path="$2" body="$3"
  if [ "${body:0:1}" = "{" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  [dry-run] gh api --method $method $path --input - <<< '$body'"
    else
      printf '%s' "$body" | gh api --method "$method" "$path" --input - --silent
    fi
  else
    run gh api --method "$method" "$path" --input "$body" --silent
  fi
}

# ---- 1. pre-flight ----------------------------------------------------------
step "Pre-flight"
for tool in git gh jq perl tar; do
  command -v "$tool" > /dev/null || die "$tool is required"
done
gh auth status > /dev/null 2>&1 || die "gh is not logged in (gh auth login)"
ok "tools present, gh logged in as $(gh api user --jq .login)"

MONOREPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
git -C "$MONOREPO" cat-file -e "HEAD:$TEMPLATE_DIR/release.yaml" 2>/dev/null \
  || die "HEAD of $MONOREPO has no $TEMPLATE_DIR/ — run this from the cicd-for-ignition repo"
SOURCE_SHA="$(git -C "$MONOREPO" rev-parse --short HEAD)"

dirty="$(git -C "$MONOREPO" status --porcelain -- "$TEMPLATE_DIR")"
if [ -n "$dirty" ]; then
  if [ "$ALLOW_DIRTY" -eq 1 ]; then
    warn "$TEMPLATE_DIR has uncommitted changes; they are NOT shipped (HEAD is)"
  else
    printf '    %s\n' "${dirty//$'\n'/$'\n'    }" >&2
    die "$TEMPLATE_DIR has uncommitted changes. The cohort repo is built from HEAD: commit first, or pass --allow-dirty"
  fi
fi
ok "template: $TEMPLATE_DIR at $SOURCE_SHA"

if gh api "repos/$REPO" --silent 2> /dev/null; then
  die "$REPO already exists. Pick another slug, or archive/delete it first (see README, teardown)"
fi
ok "$REPO does not exist yet"

# Rulesets (the whole 'locked-down repo' premise) need a paid plan on
# private repos. The plan field is only visible to org owners.
plan="$(gh api "orgs/$ORG" --jq '.plan.name // ""' 2> /dev/null || true)"
if [ "$VISIBILITY" = "private" ]; then
  case "$plan" in
    free)
      die "$ORG is on the Free plan: a PRIVATE repo gets no rulesets, so main and the release tags would be unprotected.
       Either upgrade the org to Team, or re-run with --public (the original lab 07 repo is public). See README." ;;
    "")
      warn "could not read $ORG's plan (org owners only). If it is Free, the ruleset step will fail with HTTP 403" ;;
    *) ok "org plan '$plan' supports rulesets on private repos" ;;
  esac
fi

# ---- 2. build the tree ------------------------------------------------------
step "Building the cohort tree from $TEMPLATE_DIR@$SOURCE_SHA"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/lab07-$COHORT.XXXXXX")"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "  (dry-run: the tree is kept for inspection in $WORK/repo)"
else
  trap 'rm -rf "$WORK"' EXIT
fi
TREE="$WORK/repo"
mkdir -p "$TREE"
git -C "$MONOREPO" archive --format=tar "HEAD:$TEMPLATE_DIR" | tar -x -C "$TREE"

# The README's "you are browsing the template" note makes no sense in the
# cohort repo itself.
perl -0pi -e 's/<!-- template-only:start.*?<!-- template-only:end -->\n\n?//s' "$TREE/README.md"

# Fill in the cohort name wherever the template says cicd-lab-07-<cohort>
# (docs, slides, the runner's REPO_URL default, mint-api-key.sh's REPO).
count=0
while IFS= read -r -d '' f; do
  perl -pi -e "s/cicd-lab-07-<cohort>/$REPO_NAME/g; s/cicd-lab-07-&lt;cohort&gt;/$REPO_NAME/g" "$f"
  count=$((count + 1))
done < <(grep -rlI --null -e 'cicd-lab-07-<cohort>' -e 'cicd-lab-07-&lt;cohort&gt;' "$TREE" || true)
ok "cohort name filled in across $count file(s)"
if grep -rqI -e 'cicd-lab-07-<cohort>' -e 'cicd-lab-07-&lt;cohort&gt;' "$TREE"; then
  die "placeholder left behind after substitution — check the template"
fi

# Tags to recreate: every pin in release.yaml (oatmakers: v4.4.4 → oatmakers@v4.4.4).
TAGS=()
while IFS= read -r tag; do
  [ -n "$tag" ] && TAGS+=("$tag")
done < <(awk '
  /^projects:[[:space:]]*$/ { inproj = 1; next }
  /^[^[:space:]#]/          { inproj = 0 }
  inproj && match($0, /^[[:space:]]+[A-Za-z][A-Za-z0-9_-]*:[[:space:]]*v[0-9]+\.[0-9]+\.[0-9]+/) {
    line = substr($0, RSTART, RLENGTH); gsub(/[[:space:]]/, "", line)
    split(line, kv, ":"); print kv[1] "@" kv[2]
  }' "$TREE/release.yaml")
[ "${#TAGS[@]}" -gt 0 ] || die "no project pins found in release.yaml"
for tag in "${TAGS[@]}"; do
  [ -d "$TREE/projects/${tag%@*}" ] || die "release.yaml pins ${tag%@*} but projects/${tag%@*}/ is not in the template"
done

git -C "$TREE" init -q -b main
git -C "$TREE" add -A
git -C "$TREE" -c core.hooksPath=/dev/null commit -q \
  -m "Lab 07 for cohort $COHORT" \
  -m "Generated from Mustry-Academy/cicd-for-ignition@$SOURCE_SHA ($TEMPLATE_DIR/) by scripts/instructor/new-lab07-cohort.sh."
for tag in "${TAGS[@]}"; do
  git -C "$TREE" -c core.hooksPath=/dev/null tag -a "$tag" -m "$tag (cohort $COHORT baseline)"
done
ok "1 commit ($(git -C "$TREE" rev-parse --short HEAD)), tags: ${TAGS[*]}"

# ---- 3. create + push -------------------------------------------------------
step "Creating $REPO ($VISIBILITY)"
run gh repo create "$REPO" "--$VISIBILITY" \
  --description "CI/CD for Ignition, lab 07: shared multi-gateway deploy repo for cohort $COHORT" \
  --homepage "https://mustrysolutions.com" --disable-wiki

# Actions off during the push: main already carries deploy.yml + release.yaml,
# and the cohort's first production deploy should be a deliberate one.
gh_api_json PUT "repos/$REPO/actions/permissions" '{"enabled": false}'

run git -C "$TREE" -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
  push -q "https://github.com/$REPO.git" main --tags
ok "pushed main + ${#TAGS[@]} tag(s)"

# ---- 4. settings ------------------------------------------------------------
step "Repo settings (merge, topics, security, team)"
gh_api_json PATCH "repos/$REPO" "$SETTINGS_DIR/repo-settings.json"
gh_api_json PUT "repos/$REPO/topics" "$SETTINGS_DIR/topics.json"
run gh api --method PUT "repos/$REPO/vulnerability-alerts" --silent
run gh api --method PUT "orgs/$ORG/teams/$TEAM_SLUG/repos/$REPO" -f "permission=$TEAM_PERMISSION" --silent
ok "merge settings, topics, Dependabot alerts, team $TEAM_SLUG=$TEAM_PERMISSION"

step "Rulesets"
for f in "$SETTINGS_DIR"/ruleset-*.json; do
  gh_api_json POST "repos/$REPO/rulesets" "$f"
  ok "$(jq -r .name "$f")"
done

step "Actions secrets and variables"
set_secret() {  # set_secret NAME ENVVAR PROMPT
  local name="$1" var="$2" prompt="$3" value="${!2:-}"
  if [ -z "$value" ] && [ "$DRY_RUN" -eq 0 ] && [ -t 0 ] && [ -n "$prompt" ]; then
    read -rsp "  $prompt (empty = skip): " value; echo
  fi
  if [ -z "$value" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  [dry-run] gh secret set $name --repo $REPO   # value from \$$var or a prompt"
    else
      warn "$name not set — set it later: gh secret set $name --repo $REPO"
      MISSING_SECRETS+=("$name")
    fi
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] gh secret set $name --repo $REPO   # value from \$$var"
  else
    printf '%s' "$value" | gh secret set "$name" --repo "$REPO"
    ok "$name"
  fi
}
MISSING_SECRETS=()
set_secret POSTGRES_USERNAME LAB07_POSTGRES_USERNAME "production POSTGRES_USERNAME"
set_secret POSTGRES_PASSWORD LAB07_POSTGRES_PASSWORD "production POSTGRES_PASSWORD"
# No prompt for the API key: the normal path is mint-api-key.sh (see README).
set_secret IGNITION_API_KEY LAB07_IGNITION_API_KEY ""

for v in IGNITION_CONTAINER IGNITION_URL POSTGRES_CONTAINER POSTGRES_DB; do
  envvar="LAB07_$v"
  if [ -n "${!envvar:-}" ]; then
    run gh variable set "$v" --repo "$REPO" --body "${!envvar}"
    ok "variable $v"
  fi
done

step "Actions permissions (re-enabling)"
gh_api_json PUT "repos/$REPO/actions/permissions" '{"enabled": true, "allowed_actions": "all"}'
gh_api_json PUT "repos/$REPO/actions/permissions/workflow" "$SETTINGS_DIR/actions-workflow-permissions.json"
if [ "$VISIBILITY" = "public" ]; then
  gh_api_json PUT "repos/$REPO/actions/permissions/fork-pr-contributor-approval" \
    '{"approval_policy": "first_time_contributors"}'
else
  gh_api_json PUT "repos/$REPO/actions/permissions/fork-pr-workflows-private-repos" \
    '{"run_workflows_from_fork_pull_requests": false}'
fi
ok "Actions on, GITHUB_TOKEN read-only, no fork-PR workflows without approval"

# ---- 5. people + runner -----------------------------------------------------
step "Collaborators ($PARTICIPANT_PERMISSION)"
if [ -z "$COLLABORATORS_FILE" ]; then
  echo "  none given — invite later with --collaborators, or:"
  echo "    gh api -X PUT repos/$REPO/collaborators/<user> -f permission=$PARTICIPANT_PERMISSION"
else
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    user="$(printf '%s' "${line%%#*}" | tr -d '[:space:]')"
    user="${user#@}"
    [ -n "$user" ] || continue
    [[ "$user" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,38})$ ]] || { warn "skipping '$user': not a GitHub username"; continue; }
    run gh api --method PUT "repos/$REPO/collaborators/$user" -f "permission=$PARTICIPANT_PERMISSION" --silent
    ok "invited $user"
    n=$((n + 1))
  done < "$COLLABORATORS_FILE"
  echo "  $n invitation(s). Each person must accept theirs (GitHub notifications / email)."
fi

step "Production runner ($PROD_RUNNER_LABEL)"
# Needs admin:org scope (gh auth refresh -s admin:org). Read-only.
runner_ok=""
if groups="$(gh api "orgs/$ORG/actions/runner-groups" --jq '.runner_groups[] | "\(.id) \(.visibility) \(.allows_public_repositories)"' 2> /dev/null)"; then
  while read -r gid gvis gpublic; do
    [ -n "$gid" ] || continue
    labels="$(gh api "orgs/$ORG/actions/runner-groups/$gid/runners" --jq '[.runners[].labels[].name] | join(" ")' 2> /dev/null || true)"
    case " $labels " in *" $PROD_RUNNER_LABEL "*) ;; *) continue ;; esac
    if [ "$VISIBILITY" = "public" ] && [ "$gpublic" != "true" ]; then
      runner_ok="no (runner group $gid does not allow public repositories)"
    elif [ "$gvis" = "all" ]; then
      runner_ok="yes (runner group $gid is open to all org repos)"
    elif [ "$DRY_RUN" -eq 1 ]; then
      runner_ok="unknown in dry-run (group $gid is 'selected'; the repo does not exist yet)"
    elif gh api "orgs/$ORG/actions/runner-groups/$gid/repositories" --paginate --jq '.repositories[].full_name' 2> /dev/null | grep -qx "$REPO"; then
      runner_ok="yes (runner group $gid)"
    else
      runner_ok="no — add it: gh api -X PUT orgs/$ORG/actions/runner-groups/$gid/repositories/\$(gh api repos/$REPO --jq .id)"
    fi
    break
  done <<< "$groups"
  [ -n "$runner_ok" ] || runner_ok="no org-level runner with label $PROD_RUNNER_LABEL found — it is probably still registered to one repo (see README, one-time move)"
else
  runner_ok="could not check (needs an org owner with the admin:org scope: gh auth refresh -s admin:org)"
fi
echo "  visible to $REPO: $runner_ok"

# ---- summary ----------------------------------------------------------------
step "Done"
[ "$DRY_RUN" -eq 1 ] && echo "  DRY RUN: nothing was created. Inspect the tree in $TREE"
cat <<EOF

  Repo:     https://github.com/$REPO
  Clone:    git clone git@github.com:$REPO.git   (students: in ~/mustry-academy/)

  Still to do by hand (scripts/instructor/README.md has the details):
EOF
if [ "${#MISSING_SECRETS[@]}" -gt 0 ]; then
  echo "    - set the missing secret(s): ${MISSING_SECRETS[*]}"
fi
if [ -z "${LAB07_IGNITION_API_KEY:-}" ]; then
  echo "    - on the capstone box: REPO=$REPO scripts/mint-api-key.sh"
  echo "      (rotates the production key; the previous cohort's repo stops deploying)"
fi
cat <<EOF
    - make sure the $PROD_RUNNER_LABEL runner can serve this repo (status above)
    - check the production database is back at the template baseline (000006)
      before the first deploy; see "Before the cohort" in the README
    - reset production to this cohort's baseline: gh workflow run deploy.yml --repo $REPO
    - on the day: post a runner registration token for Part 0:
        gh api -X POST repos/$REPO/actions/runners/registration-token -q .token
EOF
