# Instructor scripts

Tools for running the course. Students never need anything in this folder.

## `new-lab07-cohort.sh` — a fresh shared repo for lab 07

Labs 01–06 run in each student's fork of this repo. Lab 07 cannot: the whole
cohort works as contributors on **one shared, locked-down repo**, pushes to
`main` deploy to everyone's own test gateway, and `release.yaml` deploys to
the production gateway at https://cloud.mustrysolutions.com.

So `labs/07-multi-gateway-deploy/` is a **template**. It never runs here (its
`.github/` sits inside the lab folder, and GitHub only reads workflows at the
repo root). For every cohort, this script turns it into
`Mustry-Academy/cicd-lab-07-<cohort>`, with the lab folder as the repo root.

```bash
# 1. commit whatever you changed in labs/07 — the script ships HEAD, not your working tree
# 2. look first
scripts/instructor/new-lab07-cohort.sh 2026-10 --collaborators cohort-2026-10.txt --dry-run
# 3. then for real (prompts for the production Postgres login)
scripts/instructor/new-lab07-cohort.sh 2026-10 --collaborators cohort-2026-10.txt
```

`cohort-2026-10.txt` is one GitHub username per line; blank lines, `@` and
`# comments` are fine. Keep it out of git (it is personal data).

| Option | Effect |
|---|---|
| `--collaborators FILE` | invite everyone in FILE with the **write** role (what participants had on the original repo) |
| `--public` | create a public repo instead of private (see [Visibility](#visibility-and-the-org-plan)) |
| `--allow-dirty` | don't stop when `labs/07` has uncommitted changes (they are still not shipped) |
| `--dry-run` | build the tree locally and keep it for inspection; print every `gh` call and the `git push` instead of running them |

Secrets are read from the environment, never from arguments:
`LAB07_POSTGRES_USERNAME`, `LAB07_POSTGRES_PASSWORD` (prompted for when unset)
and `LAB07_IGNITION_API_KEY` (usually left unset, see below). Optional repo
variables `LAB07_IGNITION_CONTAINER`, `LAB07_IGNITION_URL`,
`LAB07_POSTGRES_CONTAINER`, `LAB07_POSTGRES_DB` are only needed if the
production stack stops using the defaults baked into `deploy.yml`.

You need `gh` logged in as an **org owner**. The runner check at the end also
needs the `admin:org` scope: `gh auth refresh -s admin:org`.

### What the script does

1. **Pre-flight.** Refuses if the repo already exists, if `labs/07` is dirty,
   or if the repo would be private on a Free-plan org.
2. **Builds the tree** from `git archive HEAD:labs/07-multi-gateway-deploy`
   into a temp dir: no monorepo history, one commit
   (`Lab 07 for cohort <slug>`, the source SHA in the body).
   - strips the README's "this folder is the template" note (between the
     `<!-- template-only:start/end -->` markers)
   - replaces every `cicd-lab-07-<cohort>` (and `cicd-lab-07-&lt;cohort&gt;`
     in the slides) with the real repo name: the clone commands in the docs,
     the test runner's `REPO_URL` default in `docker-compose.yaml` and
     `.env.example`, and `REPO` in `scripts/mint-api-key.sh`
   - creates an annotated tag for **every pin in `release.yaml`**
     (`oatmakers: v4.4.4` → `oatmakers@v4.4.4`), so CI's "a pin may only
     point at a tag that exists" holds from the first PR
3. **Creates the repo and pushes** `main` + tags with Actions **disabled**,
   so the initial push (which contains `deploy.yml` and `release.yaml`)
   deploys nothing.
4. **Applies the settings** in [`lab07/`](./lab07/) (table below), the team,
   the rulesets and the secrets, then **re-enables Actions**.
5. **Invites the collaborators** and checks that the production runner is
   visible to the new repo.

### Settings copied from the original repo

Read with `gh api` from `Mustry-Academy/cicd-lab-07-multi-gateway-deploy` on
2026-09-24. To refresh a file after changing the original's settings, re-run
the matching `GET` and strip the fields that are ids or history, e.g.
`gh api repos/<repo>/rulesets/<id> | jq '{name,target,enforcement,conditions,rules,bypass_actors}'`.

| Setting | Value | Where |
|---|---|---|
| Ruleset `protect-main` | default branch: no deletion, no force push, PR required (**0 approvals**, squash only), required check **`CI OK`**; repo **admins bypass** | `lab07/ruleset-protect-main.json` |
| Ruleset `protect-release-tags` | all tags: no deletion, no update, no force push; no bypass (creating tags is allowed) | `lab07/ruleset-protect-release-tags.json` |
| Merge settings | merge/squash/rebase all enabled at repo level (the ruleset narrows `main` to squash), auto-merge off, delete-branch-on-merge off, update-branch off | `lab07/repo-settings.json` |
| Features | issues on; wiki, projects, discussions off; homepage mustrysolutions.com | `lab07/repo-settings.json` |
| Topics | `ci-cd`, `cicd-masterclass`, `lab`, `mustry-academy` | `lab07/topics.json` |
| Actions | enabled, all actions allowed, `GITHUB_TOKEN` read-only, Actions may not approve PRs | `lab07/actions-workflow-permissions.json` + script |
| Fork PRs | public: approval for first-time contributors (as the original); private: fork PR workflows off | script |
| Dependabot alerts | on | script |
| Team | `mustry-solutions`: admin | script |
| Participants | role `write` (API: `push`) | script |
| Secrets | `IGNITION_API_KEY`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD` (repo level) | script, values from env/prompt |
| Variables | none set on the original (the workflow defaults apply) | script, optional |

**Bypass actors.** `protect-main` lets `actor_type: RepositoryRole`,
`actor_id: 5` bypass. That is GitHub's **built-in admin role**, whose id is
the same in every repo, so the JSON works unchanged. It is how the instructors
(org owners and the `mustry-solutions` team) can repair `main` in an
emergency. If you ever add a team or app as a bypass actor, its id is
org-specific: look it up (`gh api orgs/Mustry-Academy/teams/<slug> --jq .id`)
rather than copying an id from another org.

**Deliberately not copied:**

- The `test` **environment** and its `IGNITION_API_KEY` environment secret:
  no workflow in lab 07 references an environment, so it is dead config.
- The `API_KEY_TOM` repo secret: a previous participant's leftover.
- The original's contributors, self-hosted runners and tags other than the
  release pins (`oatmakers@v2.0.0` … `v4.4.3` stay in the old repo's history).

### Visibility and the org plan

The original lab 07 repo is **public**, and `Mustry-Academy` is on the
**Free** plan. On Free, rulesets and branch protection only work on public
repos. A private cohort repo on Free would have an unprotected `main` and
unprotected release tags, which is the opposite of what the lab teaches. The
script therefore refuses `private` on a Free org. Two ways out:

- upgrade the org to **Team** (private cohort repos, rulesets, and real
  runner groups — see below), or
- pass `--public`, which is how the lab ran until now.

### One-time: move the production runner to the org

The production runner (`cicd-capstone-runner`, labels
`self-hosted, cicd-capstone`) is registered **to the old repo only**, so a new
cohort repo cannot use it. Move it to the organisation once; after that every
cohort repo just needs access to its runner group.

1. **Create a runner group** (Team plan): Org settings → Actions → Runner
   groups → New group `cicd-capstone`, repository access **Selected
   repositories**, add the current `cicd-lab-07-*` repos. Tick *Allow public
   repositories* if the cohort repos are public. Or with the API:

   ```bash
   gh api -X POST orgs/Mustry-Academy/actions/runner-groups \
     -f name=cicd-capstone -f visibility=selected -F allows_public_repositories=true
   ```

   On the **Free** plan only the *Default* group exists, and it covers every
   repo in the org. Then any org repo whose workflow asks for
   `runs-on: [self-hosted, cicd-capstone]` gets a root-equivalent shell on the
   production server. That includes pull requests from forks of this course
   repo, if fork PR workflows are ever approved. Treat that as a reason to
   upgrade.
2. **Re-register the runner at org scope** in `cicd-capstone-infra`: switch the
   runner container from repo scope to org scope (for the
   `myoung34/github-runner` image: `RUNNER_SCOPE=org`,
   `ORG_NAME=Mustry-Academy`, `RUNNER_GROUP=cicd-capstone`, keep
   `LABELS=cicd-capstone`), with a token from
   `gh api -X POST orgs/Mustry-Academy/actions/runners/registration-token -q .token`.
   Clear the persisted runner state first, or it keeps its old repo
   registration.
3. **Remove the old repo-level registration** once the org runner is online:
   `gh api repos/Mustry-Academy/cicd-lab-07-multi-gateway-deploy/actions/runners`
   gives the id, then `gh api -X DELETE …/actions/runners/<id>`.
4. From then on, the script's last check tells you whether the new repo can
   see the runner; if the group is *Selected*, add the repo:
   `gh api -X PUT orgs/Mustry-Academy/actions/runner-groups/<group-id>/repositories/<repo-id>`.

### Before the cohort: the manual steps

The script prints these at the end as well.

1. **Production API key.** The key's hash lives on the production gateway, the
   key itself only in the repo's `IGNITION_API_KEY` secret, and it cannot be
   read back. On the capstone box, in a clone of the new cohort repo:
   `REPO=Mustry-Academy/cicd-lab-07-<cohort> scripts/mint-api-key.sh`
   (the default `REPO` in the generated repo is already the right one). This
   **rotates** the key: the previous cohort's repo can no longer deploy, which
   is what you want. One cohort on production at a time.
2. **Postgres secrets**, if you skipped the prompt:
   `gh secret set POSTGRES_USERNAME --repo …` / `POSTGRES_PASSWORD`.
3. **Runner access** (see the one-time move above).
4. **Reset production to the cohort baseline:** the first push ran with
   Actions off, so nothing has deployed yet. When secrets and runner are in
   place: `gh workflow run deploy.yml --repo Mustry-Academy/cicd-lab-07-<cohort>`.
   Production then runs exactly this cohort's `release.yaml` (only
   `oatmakers`); the previous cohort's projects disappear from it.
5. **Send the link** `https://github.com/Mustry-Academy/cicd-lab-07-<cohort>` to
   the participants and have them accept their invitation before the day.
   Late additions: `gh api -X PUT repos/Mustry-Academy/cicd-lab-07-<cohort>/collaborators/<user> -f permission=push`.

On the day, for Part 0 (valid one hour; post it in the chat):

```bash
gh api -X POST repos/Mustry-Academy/cicd-lab-07-<cohort>/actions/runners/registration-token -q .token
```

### After the cohort: teardown

Keep the repo as the cohort's record; archive it rather than delete it.

```bash
R=Mustry-Academy/cicd-lab-07-<cohort>

# 1. deregister the participants' laptop runners (repo-level, *-local labels)
gh api "repos/$R/actions/runners" --jq '.runners[] | "\(.id) \(.name)"'
gh api -X DELETE "repos/$R/actions/runners/<id>"        # per runner

# 2. take the repo out of the production runner group (Team plan)
gh api -X DELETE "orgs/Mustry-Academy/actions/runner-groups/<group-id>/repositories/$(gh api repos/$R --jq .id)"

# 3. archive: read-only, and scheduled workflows (deploy.yml's readiness check) stop
gh repo archive "$R" --yes
```

Collaborators keep read access to an archived repo. Remove them
(`gh api -X DELETE repos/$R/collaborators/<user>`) if the cohort should lose
access.

**Production database: roll it back before you archive.** The next cohort's
first deploy resets the gateway (projects and config are wiped and re-copied
from its `release.yaml`), and minting its key revokes this cohort's. The
database is not reset. If this cohort merged migrations (Part 2, challenge 3),
production's `schema_migrations` sits at a version the template does not
have, and golang-migrate stops the next cohort's first deploy with
`no migration found for version N`. On the capstone box, with this cohort's
repo checked out (its `.down.sql` files), go back to the template's highest
migration (`000006` today):

```bash
docker run --rm --network <capstone network> -v "$PWD/db-migration/migrate:/m" \
  migrate/migrate -path /m -database "postgres://<user>:<pw>@cicd-capstone-postgres:5432/ignition?sslmode=disable" goto 6
```

Tables that no migration owns (a historian provider's tables from challenge 5)
survive that; drop them by hand if they get in the way.
