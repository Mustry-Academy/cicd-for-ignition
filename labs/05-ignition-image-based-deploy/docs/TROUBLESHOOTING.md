# Troubleshooting

Quick fixes for the things that bite people during the lab. Work top to bottom; most issues
are one of the first three.

## The stack won't start / `scripts/setup.sh` fails

- **Docker isn't running or isn't Compose v2.** `docker compose version` must work (note the space —
  not `docker-compose`). Start Docker Desktop and re-run `scripts/setup.sh` (it's idempotent).
- **Not enough RAM.** Three gateways (1 GB heap, 1.5 GB cap each) + TimescaleDB need **≥ 8 GB free**.
  Raise Docker's memory or bump the per-gateway limit in [`docker-compose.yaml`](../docker-compose.yaml).
- **Port already in use.** 8088/8089/8090 (gateway web UIs), 8060/8061/8062 (gateway network) or
  5432 (TimescaleDB). Stop the other process, or move this lab: set the matching variable in `.env`
  and re-run `scripts/setup.sh`:

  | Default | `.env` variable |
  |---|---|
  | 8088 | `GATEWAY_PORT` (local) |
  | 8089 | `TEST_GATEWAY_PORT` |
  | 8090 | `PRODUCTION_GATEWAY_PORT` |
  | 5432 | `POSTGRES_PORT` |
  | 8060 / 8061 / 8062 | `GATEWAY_GAN_PORT` / `TEST_GATEWAY_GAN_PORT` / `PRODUCTION_GATEWAY_GAN_PORT` |

  `docker-compose.yaml` and the scripts follow your values; the URLs in the lab instructions
  assume the defaults, so swap in your port when you open or `curl` one.

## Every tag reads null on the local gateway

The views load, but every tag-bound value shows `null` and *Connections → OPC Connections*
lists **Ignition OPC UA Server** as **FAULTED**. The gateway log says why:

```bash
docker logs lab05-ignition-local 2>&1 | grep 'opcua-module'
# Authentication failed: User Source "opcua-module" not found.
```

Every tag reads through that loopback connection, and it logs in against the
`opcua-module` user source. That user source holds a password hash, so it is gitignored and
never in a fresh clone; `scripts/setup.sh` has the OPC UA module create it on the next boot.
Re-run `scripts/setup.sh`: it prints `opcua-module user source created` and the connection
turns CONNECTED within a minute. (Re-running it is safe for test/production too: it keeps them
on the image they run.)

**Same error on test, production or the stand-alone `demo` container?** The image never carries
that user source either. The `Dockerfile` re-arms the OPC UA module's one-time flag (the `sed`
`RUN` after the config `COPY`) so each image gateway creates its own at first boot. If you see the
error there, the image was built without that `RUN`: put it back and rebuild.

## A gateway never reaches RUNNING

- Give it time — a cold JVM start is 60–120 s per gateway, and an **image-based** boot re-commissions
  the gateway, so test/production can take a little longer than `local`.
- Check logs (use `docker logs` with the container name, not `docker compose logs`):
  ```bash
  docker logs --tail 200 lab05-ignition-test     # or -local / -production
  ```
- **Trial expired.** Each gateway runs in 2-hour trial mode. Reset via *Platform → Licensing →
  Reset Trial*. Note: recreating test/production from a fresh image resets their trial clock too.
- **Stuck commissioning.** `curl -s localhost:8089/StatusPing` keeps answering
  `{"state":"RUNNING","details":"COMMISSIONING"}`. Despite the `RUNNING`, that gateway is not up:
  it waits for something to be accepted, usually a module certificate or licence. `setup.sh` and
  `scripts/deploy-image.sh` wait for it and say "still commissioning" when they give up. Open the
  gateway in your browser to see what it asks for. Running the image with plain `docker run`? See
  [Gateway stuck in `RUNNING / COMMISSIONING`](#gateway-stuck-in-running--commissioning-stand-alone-run).

## Designer save fails: `PushException: I/O error during prepare: ... .tmp` (Linux / WSL)

Your local gateway still runs as the image's own user (uid 2003), which cannot write folders git
created as `755` (a pull or branch switch that brings in a new project or view). Run
`scripts/setup.sh` again: it records your user id as `LAB_UID` in `.env` and recreates the local
gateway as you, so it can write everything in your working tree. Then save again.

## `docker build` / `scripts/build-image.sh` fails

- **`invalid reference format` with `ghcr.io/<your-github-user>/…` in the tag.** A stale `.env` still
  has the `.env.example` placeholder `IGNITION_IMAGE_REPO=ghcr.io/<your-github-user>/…`; the literal
  `<`/`>` are illegal in a Docker tag. `scripts/lib.sh` now ignores that placeholder and falls back to
  the registry-free local name `cicd-lab-05-ignition`, so a fresh `.env` builds fine. If you hit this on
  an old `.env`, just **comment out the `IGNITION_IMAGE_REPO=` line** — the local scripts need no registry.
- **"… not found in build context."** A `COPY` source path is wrong, or the path is excluded by
  [`.dockerignore`](../.dockerignore). Check the four `COPY` lines in the [`Dockerfile`](../Dockerfile)
  against what's actually on disk.
- **Context is huge / build is slow.** Something big is in the context. In a stand-alone repo `.git`
  is the usual culprit (confirm `.git/` is in `.dockerignore`); in the course monorepo it sits outside
  this lab's folder. Look for large files in the lab folder (`du -sh *`) and add what the gateway
  doesn't need to `.dockerignore`.
- **Image builds but is missing a file.** It's almost always `.dockerignore` excluding something you
  meant to put in the image. Verify with `docker run --rm --entrypoint find <image> /usr/local/bin/ignition/data/projects`
  (the `--entrypoint` is required — the IA image otherwise treats trailing args as gateway arguments).

## Gateway FAULTs: "unable to create resource dir … /.resources"

The files in the image are owned by a user the gateway cannot write as. The gateway runs as its own
`ignition` user (uid 2003) and must create runtime directories under `data/config/` at boot; a
plain `COPY` in a Dockerfile writes files as **root**, so that fails.

The fix belongs in the build, not the run: every `COPY` in this lab's `Dockerfile` uses
`--chown=2003:0`. If you hit this after editing the Dockerfile, check you did not drop a `--chown`.
It's a useful reminder that **file ownership is part of what an image carries** — get it right at
build time and the container needs no special privileges at run time.

Do **not** work around it with `--user root`. That reintroduces the problem this course spent Lab 02
onwards avoiding: a root gateway writes root-owned files into your bind mounts, and you end up
needing `sudo` to edit your own project files. Full working stand-alone command is in
[`exercises/lab.md`](../exercises/lab.md) and printed by `scripts/build-image.sh`.

## Gateway stuck in `RUNNING / COMMISSIONING` (stand-alone run)

A bare `docker run` is missing the commissioning env vars, so the gateway waits on the setup wizard.
Add `-e IGNITION_EDITION=standard` and `-e GATEWAY_ADMIN_USERNAME=admin` (plus `ACCEPT_IGNITION_EULA=Y`
and `GATEWAY_ADMIN_PASSWORD`). The compose stack supplies all of these already, so deploys with
`docker compose up -d ignition-test` or `scripts/deploy-image.sh` don't hit this: it's only a
stand-alone-run gotcha.

## Stand-alone run logs `Error adding historian`

The third-party modules (the TimescaleDB historian among them) are built into the image at `/third-party-modules`,
but the gateway only loads them when told where they are. Add
`-Dignition.gateway.externalModulesFolder=/third-party-modules` after the `--`, like the command
`scripts/build-image.sh` prints. The compose services already pass it.

## A module you enabled in `services/modules.json` doesn't run

`services/modules.json` is the one module list for all three gateways, but modules only load at
boot:

- **Local** reads the file through its bind mount. Restart it: `docker compose restart ignition-local`.
- **Test/production** read the copy inside the image. Commit, rebuild and deploy the new image.
- **Test/production before their first deploy** run the plain base image, which has no
  `modules.json`. They start the list `scripts/setup.sh` recorded in `.env` as
  `LAB_MODULES_ENABLED`; re-run `scripts/setup.sh` after you change `modules.json`. Without that
  line (an `.env` from before this lab version, or no setup run yet) the base image starts every
  module Ignition ships, which costs memory but breaks nothing.

## GHCR push/pull fails (401 / 403 / denied)

The images publish to **your own fork's** GHCR namespace (`ghcr.io/<your-fork-owner>/…`), so this is
never about lacking access to *Mustry's* registry. A 403/401 almost always traces back to a GitHub
setting on your fork:

- **Workflow never ran at all.** Forks ship with Actions **disabled**. Open your fork's *Actions* tab
  and click "I understand my workflows, go ahead and enable them." Nothing builds or pushes until you do.
- **403 on push, org-owned fork.** If your fork lives under a GitHub **organization**, check
  *Settings → Actions → General → Workflow permissions* = **Read and write**, and that
  *Settings → … → Packages* aren't disabled for the org. Personal forks are read-write by default.
- **`denied: installation not allowed to Create organization package`.** Same org policy as above, or
  the org blocks package creation — push under a **personal** fork instead.
- **403 even with `packages: write`.** The workflow already requests it (in `lab05-deploy.yml` / `lab05-release.yml`);
  if you copied a job and dropped the `permissions:` block, add `packages: write` back.
- **`denied: permission_denied: write_package` on push.** A package called `cicd-lab-05-ignition`
  already exists under your account but belongs to another repository (typically the retired
  per-lab repo `cicd-lab-05-ignition-image-based-deploy` you forked in an earlier run of the
  course), so this repo's `GITHUB_TOKEN` may not write to it. Open the package (your profile →
  *Packages* → `cicd-lab-05-ignition` → *Package settings*) and under *Manage Actions access* add
  `cicd-for-ignition` with the **Write** role. Or delete the old package there and re-run the
  workflow: the push creates a fresh one linked to this repo.
- **Wrong namespace / `invalid reference format`.** GHCR paths must be lowercase. CI lowercases the owner
  automatically; the local `scripts/lib.sh` also lowercases and ignores the `.env.example` placeholder.
  If you hand-edited an image name, check for capitals or stray `<…>`.
- **`denied` / `unauthorized` on `docker pull` on your machine.** The package is **private** (a
  package the workflow creates from a public fork is normally public, but one from a private fork,
  or an older package with the same name, is not) and your Docker is not logged in to GHCR with a
  token that may read packages. The `gh` token lacks `read:packages` until you add it (the first
  command opens your browser once):
  ```bash
  gh auth refresh -h github.com -s read:packages
  gh auth token | docker login ghcr.io -u <your-user> --password-stdin
  ```
  Or make the package public: *Package settings* → *Change visibility*. (You don't need any of this
  for the lab itself: the local `build-image.sh` flow uses local images and never touches GHCR.)

## `manifest unknown` when releasing

`lab05-release.yml` promotes the **`:test`** image (what the test gateway is running). If no `:test` image exists yet, the
re-tag fails with `manifest unknown`.

- **New release (tag push):** nothing has ever been shipped to test. Push a change to **`main`** so
  `lab05-deploy.yml` builds and publishes `:test` first, then tag the release.
- **Rollback (manual dispatch):** the version you asked to re-promote was never released — there's no
  `:vX.Y.Z` image for it. Use a version that actually shipped to production before.

## Release fails: `:test ... was built from <sha>, but the tagged commit ... has different image inputs`

A tag push promotes whatever `:test` is, so `lab05-release.yml` first checks that `:test` was built
from the commit you tagged (its `org.opencontainers.image.revision` label must name a commit with
the same `projects/`, `services/`, `third-party-modules/`, `Dockerfile` and `.dockerignore`).
It fails when:

- **You tagged too early.** The merge's `lab05-deploy.yml` run hadn't finished, so `:test` is still
  the previous build. Wait for it to go green, delete the tag and push it again:
  `git push origin :refs/tags/lab05-vX.Y.Z && git push origin lab05-vX.Y.Z`.
- **You tagged the wrong commit,** e.g. a feature branch, or a `main` you hadn't pulled since
  the merge. Tag GitHub's `main` instead: `git fetch origin && git tag -f lab05-vX.Y.Z origin/main`,
  then delete and push the tag as above.

## `no matching manifest for linux/arm64/v8` on pull (Apple Silicon)

Your `docker pull` of a CI-built image fails with `no matching manifest for linux/arm64/v8`.
Cause: the **build** ran on GitHub's `ubuntu-latest` (amd64) and produced an **amd64-only** image,
but your laptop is Apple Silicon (**arm64**), so the pull finds no matching architecture.

Fixed by building **multi-arch**: `lab05-deploy.yml`'s build job uses `docker/setup-qemu-action` and
`platforms: linux/amd64,linux/arm64`, so the pushed image runs natively on both. (Cheap here: besides
the COPYs, the Dockerfile only runs two tiny shell steps, a `sha256sum` with a `sleep` and a `sed`, so
emulating arm64 costs seconds; nothing is compiled.)

If you still see it: the existing `:test` image in GHCR is the **old amd64-only** one. Trigger a fresh
build (push any gateway-content change to `main`) so a multi-arch `:test` overwrites it, then the
pull works cleanly. Confirm the published image is multi-arch with:
```bash
docker buildx imagetools inspect ghcr.io/<your-fork-owner>/cicd-lab-05-ignition:test
# should list both linux/amd64 and linux/arm64
```

## The deploy ran but my change isn't visible

- **Right gateway?** `local` = :8088 (your authoring gateway, file-based), `test` = :8089, `production` = :8090.
- **Which build is it running?** Ask the container for the commit its image was built from:
  ```bash
  docker inspect -f '{{ index .Config.Labels "org.opencontainers.image.revision" }}' lab05-ignition-test
  ```
  It should print the short sha you built. A long hash that is none of your commits means test
  still runs the base image: the deploy didn't recreate it, or a later bare `docker compose up -d`
  put it back (see below). Re-run the deploy one-liner, or `scripts/deploy-image.sh test <image>`.
  (`{{.Config.Image}}` only shows the *name* you deployed, and a moving name like `:local` reads the
  same for every build.)
- **Stale moving tag.** If you deployed `:test` by name and it didn't change, remember moving tags can
  point at an old digest on a host that already cached them. Deploy the immutable `:sha-<short>` tag.

## test/production are an empty gateway again

That's the **default** whenever `IGNITION_TEST_IMAGE` / `IGNITION_PRODUCTION_IMAGE` are unset:
compose falls back to the base Ignition image. Two ways to get there:

- **Nothing was deployed yet.** Build and deploy:
  `scripts/build-image.sh`, then `IGNITION_TEST_IMAGE=cicd-lab-05-ignition:sha-<short> docker compose up -d ignition-test`.
  (The workflows never deploy: they only build and promote images in GHCR.)
- **You deployed, then ran a bare `docker compose up -d`.** Without the variable, compose recreates
  test/production on the base image and your deploy is gone (the image itself is still in
  `docker images`). Redeploy with the one-liner, or put the image in `.env`
  (`IGNITION_TEST_IMAGE=cicd-lab-05-ignition:sha-<short>`) so every later `docker compose up -d`
  keeps it. `scripts/setup.sh` keeps whatever image test/production run, so re-running it is safe.

## The workflow finished but nothing deployed

Expected. This lab runs **no self-hosted runner**, so the workflows build and push images but never
touch a gateway. Deploying is manual: open the workflow run's summary, copy the image name it
printed, and point the gateway at it yourself:

```bash
docker pull ghcr.io/<your-fork-owner>/cicd-lab-05-ignition:sha-<short>
IGNITION_TEST_IMAGE=ghcr.io/<your-fork-owner>/cicd-lab-05-ignition:sha-<short> \
  docker compose up -d ignition-test
```

## A duplicate stack appears when running compose

If a parallel set of containers shows up, the Compose **project name** didn't match. This lab pins it
with `name: cicd-lab05` at the top of `docker-compose.yaml` — confirm that line is present and
unchanged.

## `git status` shows lots of `resource.json` changes

Ignition rewrites the `resource.json` manifests on every interaction, usually touching nothing
but volatile metadata (modification timestamp, actor, signature). That churn is **meant to be
visible** — real edits must show up in git — and it's undone, not hidden:

```bash
scripts/clean-ignition-resource-churn.sh          # dry run: lists volatile-only files
scripts/clean-ignition-resource-churn.sh --apply  # restores them from HEAD
```

Junk-only rewrites are reverted whether or not you already staged them. Files with real content
changes are never touched by the script.
`git diff` already hides the volatile metadata via a textconv driver wired by `scripts/setup.sh`
(through the repo root's `scripts/install-git-config.sh`);
re-run it if diffs still show timestamp/signature noise. Only the machine-local
`local-system-properties/config.json` stays `skip-worktree` (the hooks re-apply it).

## Validate before you push

```bash
scripts/validate.sh      # the CI checks: JSON, .dockerignore, identity policy, compose config,
                         # plus yamllint, shellcheck, iglint, hadolint, actionlint if installed
scripts/build-image.sh   # confirm the image actually builds
```

`validate.sh` skips (and says so) any linter you haven't installed; CI always runs them all.

Still stuck? Ask your instructor or on Discord.


## Why resource.json keeps changing on its own

See [`resource-json-hygiene.html`](https://share.mustrysolutions.com/37202f9a-4e70-4f81-bce4-79519f520bda) ([offline copy](./resource-json-hygiene.html)) for the full picture: what the junk fields are, the difference between hiding them and reverting them, and why an empty `git diff` does not mean the file on disk is clean.
