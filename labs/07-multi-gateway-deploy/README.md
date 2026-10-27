# Lab 07: Deployments in a multi-gateway architecture

Day 4 of the [CI/CD for Ignition Masterclass](https://github.com/Mustry-Academy/cicd-for-ignition).

> The final lab. For once you do **not** work in your fork. Everyone works as a
> **contributor on one real, public repo**,
> [`Mustry-Solutions/demo-oatmakers`](https://github.com/Mustry-Solutions/demo-oatmakers):
> the repo behind Mustry's live Oatmakers demo at
> <https://cloud.mustrysolutions.com>. Build on your local development
> gateway; a change to `release.yaml` reaches the **live production gateway**.
> Feature branch → PR → review → tag → release pin →
> live, again and again, with the rest of the group in the same version
> stream.

This folder holds the **material** for the lab: the slides, the exercise and
the reference docs. The code you work on lives in demo-oatmakers; nothing in
this folder runs.

The release rule: `release.yaml` is the **only** production
trigger. Each pin is a git tag `<project>@vX.Y.Z` that must exist before the
file may point at it; CI enforces that on the PR. Rollback is `git revert`
of the release PR.

## Prerequisites

- The instructor adds you as a **collaborator** on demo-oatmakers at the start
  of the session. Accept the invite from your GitHub notifications. No fork.
- Docker with the Compose V2 plugin, `git`, `curl`, `python3`
- Docker resources for one local Ignition development gateway and one
  PostgreSQL database
- Ports **8088 and 5432** free: stop the lab 06 stack first
  (`docker compose down` in `labs/06-secrets-db-and-modules/`)
- _Background:_ [labs 03-06](../): the runner, tags, secrets, migrations and
  module moves all return here, wired into one pipeline

> **WSL2 (Windows): keep the clone in your Linux home (`~/...`), never
> `/mnt/c/...`.** See [`docs/wsl-setup.md`](./docs/wsl-setup.md).

## Quick start

Clone it **next to** the course repo, not inside it:

```bash
cd ~/mustry-academy    # the folder that already holds cicd-for-ignition/
git clone git@github.com:Mustry-Solutions/demo-oatmakers.git
cd demo-oatmakers
cp .env.example .env
# edit .env: clear LAB_USER and leave IGNITION_API_KEY empty
./scripts/setup.sh     # local development gateway + database, idempotent
```

| Service | URL | Login / fed by |
|---|---|---|
| local gateway | http://localhost:8088 | `admin` / `password`, bind-mounted from your working tree |
| local database | localhost:5432 | see `local-development/secrets/` |
| **production** | https://cloud.mustrysolutions.com | the `Deploy` workflow, only when `release.yaml` changes |

## Lab structure

[`exercises/lab.md`](./exercises/lab.md) is the source of truth;
[`slides/assignment.html`](https://share.mustrysolutions.com/a95c879a-d14b-4f76-8214-8f39784f09b1) ([offline copy](./slides/assignment.html)) mirrors it 1:1:

| Part | Topic | Gate |
|---|---|---|
| 0 (±5 min) | Start the local development gateway and database | sign in on `localhost:8088` and open oatmakers in the Designer |
| 1 (±20 min) | Your own project through the full loop: PR → approval → `<yourname>@v1.0.0` tag → `release.yaml` pin | your view live on production |
| 2 (±35 min) | Five challenges on the shared oatmakers project: module, JAR, migration + referenced secret, simulator tags, history in the TimescaleDB-Historian | your challenge live via an `oatmakers@` tag (the group starts at the `v5.1.0` pin) |
| 3 (extra) | Build on each other's work: a showcase view, a shared library at its own tag, small PRs, real merge conflicts | a merged PR that uses someone else's Part 2 work |

## Material

The slides and the resource.json page open in your browser (click **Open document** on the first page); the offline copy next to each link is the same file in this folder.

| File | What |
|---|---|
| [`slides/teaching.html`](https://share.mustrysolutions.com/8e1ea98f-1dc8-4972-8d59-65afb8afb879) ([offline copy](./slides/teaching.html)) | The teaching hour: architectures, repo layouts, release files, promotion as a PR, tag ownership, and how demo-oatmakers deploys |
| [`slides/assignment.html`](https://share.mustrysolutions.com/a95c879a-d14b-4f76-8214-8f39784f09b1) ([offline copy](./slides/assignment.html)) | The you-do, slide by slide |
| [`exercises/lab.md`](./exercises/lab.md) | The exercise, including the rules for a shared live demo and troubleshooting |
| [`docs/multi-gateway-deployments.md`](./docs/multi-gateway-deployments.md) | The teaching content written out in full |
| [`docs/production-gateway.md`](./docs/production-gateway.md) | The production gateway: what it is, how deploys reach it, the ground rules |
| [`docs/resource-json-hygiene.html`](https://share.mustrysolutions.com/cd8236d4-d050-4d49-b8c7-bbe4bfc35a0f) ([offline copy](./docs/resource-json-hygiene.html)) | Why `resource.json` churns and the two tools in demo-oatmakers that deal with it |
| [`docs/wsl-setup.md`](./docs/wsl-setup.md) | Windows / WSL setup |
| [`architectures/`](./architectures/) | The three reference architecture diagrams |

## License

[Apache 2.0](./LICENSE): © 2026 Mustry Solutions BV.
