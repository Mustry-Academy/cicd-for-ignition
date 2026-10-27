# Deployments in a multi-gateway architecture

This document is the Lab 07 teaching hour written out in full. The slides
([`slides/teaching.html`](https://share.mustrysolutions.com/8e1ea98f-1dc8-4972-8d59-65afb8afb879), [offline copy](../slides/teaching.html)) are the presentation; this
is the version you can re-read.

Five parts: three reference architectures, how a repository maps onto each,
the deploy mechanism (a releases folder, promotion by PR, multi-site options),
tag ownership, and how this lab's repo deploys.

Where the course left us: **one repository, one site, one logical gateway** in
three environments (local, test, production).

---

## Part 1: Three reference architectures

The diagrams are in [`architectures/`](../architectures/) (Inductive
Automation's reference architectures). The repository layout follows the
shape.

### Architecture 1: standalone: one gateway does everything

Devices, tags, history, Perspective sessions: all on one gateway
(`architectures/one-gateway.png`). Most plants start here, and at the right
size it is a perfectly good place to stay.

- One box is one failure domain: PLC polling, history and every client
  session share the same CPU and the same restart.
- It strains when heavy Perspective load competes with device polling, and
  every deploy touches the box that also runs production.
- **CI/CD view:** one repo, one pipeline, one deploy target. Labs 04-06
  already built everything this architecture needs.

### Architecture 2: frontend and backend gateways

Backend gateways own device connections, tag providers and history; a
frontend gateway owns the Perspective sessions; they talk over the gateway
network (`architectures/backend-frontend.png`).

- Why split: client sessions can no longer starve device polling, and you can
  redeploy or restart visualization without touching data collection.
- It scales: more frontends behind a load balancer, more backends per device
  group, without redesigning anything.
- **CI/CD view:** one plant, but **several deploy targets with different
  content**: projects mostly go to the frontend, device and tag config to
  the backends. The pipeline has to route.

### Architecture 3: multi-site with an enterprise level (hub and spoke)

Each site collects and runs locally; a central level aggregates history,
reporting and corporate clients
(`architectures/multi-site-enterprise-architecture.png`).

- Sites keep local autonomy: Edge or standard gateways collect and buffer at
  the plant; local clients keep working when the WAN link drops.
- The center aggregates: a central database service, enterprise reporting,
  corporate clients through load-balanced frontend gateways.
- **CI/CD view:** many targets in **different networks**. A self-hosted
  runner per site becomes the deploy agent inside each network, and "which
  version runs where" becomes a real bookkeeping problem. Part 3 solves
  both.

---

## Part 2: How repositories and pipelines map onto each architecture

### The baseline (labs 04-06)

```
oatmakers-repo/
├─ projects/
│  ├─ oatmakers/
│  └─ oatmakers-packaging/
├─ gateways/            # gateway config
├─ db-migration/
└─ .github/workflows/deploy.yml
```

One repository holds everything; one pipeline deploys it; one site, one
logical gateway, three environments (local → test → production).

### Frontend-backend: one repo, several projects, a config folder per gateway

Two gateways do not force two repositories. One repo can hold all projects
and all gateway config; the pipeline routes each piece to its gateway:

```
oatmakers-repo/
├─ projects/                       # one folder, all projects
│  ├─ oatmakers/                   # HMI            → gw-frontend
│  ├─ oatmakers-shared/            # its parent     → gw-frontend
│  ├─ oatmakers-packaging/         # HMI            → gw-frontend
│  └─ oatmakers-packaging-shared/  # its parent     → gw-frontend
├─ gateways/                       # a config folder per gateway
│  ├─ gw-frontend/                 # sessions, auth, gateway network
│  └─ gw-backend/                  # devices, tag providers, history
└─ .github/workflows/deploy.yml
```

- Each project in `projects/` can deploy to a **different gateway**.
- Each HMI has its **own parent project** it inherits from
  (`oatmakers-shared`, `oatmakers-packaging-shared`); a parent deploys to
  every gateway that runs its child.
- Each gateway has its **own config folder** under `gateways/`.
- A screen change and its tag change are **one PR**, deployed to two
  different gateways.

---

## Part 3: The deploy mechanism: releases, promotion and the multi-site options

The architecture shows the shape; this is how anything actually moves. The
bookkeeping is a **releases folder**, usually its own small repository: one
folder per environment, one file per gateway, everything plain text under
version control. The fleet's state gets a `git log`.

```
oatmakers-releases/
├─ production/
│  ├─ gw-site1-backend.yaml
│  ├─ gw-site1-frontend.yaml
│  ├─ gw-site4-backend.yaml
│  ├─ gw-site4-frontend.yaml
│  ├─ … sites 2, 3, 5 … 8 …
│  └─ gw-central.yaml
├─ staging/
│  └─ gw-staging.yaml
└─ test/
   └─ gw-test.yaml           # tracks main, auto
```

One file per gateway; each project pinned to a version, its parent pinned
underneath it:

```yaml
# releases/production/gw-site4-frontend.yaml
gateway: gw-site4-frontend
projects:
  oatmakers:
    version: v2.0.1   # the hotfix
    shared:  v1.9.2   # its parent, pinned with it
  oatmakers-packaging:
    version: v1.4.0
    shared:  v1.2.0
```

This file **is** the record of what runs on `gw-site4-frontend`. Change the
file, and the pipeline makes it true.

And test is the deliberate exception: no pins:

```yaml
# releases/test/gw-test.yaml
gateway: gw-test
track: main            # every merge deploys automatically
```

Pinning starts where humans need control: staging and production.

### A promotion is a pull request

1. **The PR:** bump `oatmakers: v2.0.0 → v2.0.1` in site 4's
   frontend file (that is where the HMI runs). The
   diff *is* the release note: exactly what changes, exactly where.
2. **Review is the approval gate.** The reviewer approves a promotion, not
   code. Merging is the trigger; nobody logs into a gateway.
3. **Site 4 goes first:** its own runner deploys its two gateways and runs
   the health checks; then you deliberately wait half an hour and watch. The
   least critical site proves the release before anything else moves.
4. **The rest follows:** the same bump for the other sites, then
   `gw-central` last. A failed check at any point stops everything after it.
5. **Rollback is `git revert`** of the release PR: the file goes back, the
   pipeline makes the old pins true again.

Test never appears in this flow: it tracked main automatically since the merge
that started it all.

---

### Scaling to multi-site

You now hold every piece: the routing from Part 2, and the releases and
promotions from earlier in this part. Multi-site is those pieces multiplied:
the only new decisions are where the repository boundaries go, where the
runners live, and how versions are made inside a bigger repository.

### Option A: one repository deploying to every site

The same idea scaled out. One repo holds every project (each HMI with its
own parent project), a config folder per gateway across all sites, and the
migrations:

```
oatmakers-repo/
├─ projects/
│  ├─ oatmakers/                   # every site's HMI
│  ├─ oatmakers-shared/            # its parent, one copy
│  ├─ oatmakers-packaging/
│  └─ oatmakers-packaging-shared/  # its parent
├─ gateways/
│  ├─ gw-site1-backend/ … gw-site8-frontend/
│  └─ gw-central/
├─ db-migration/migrate/      # runs at every site
└─ .github/workflows/deploy.yml   # matrix over sites
```

- **A self-hosted runner per site, and one at the enterprise level.** The
  workflow runs as a matrix; each site's job lands on that site's runner
  (`runs-on: [self-hosted, site-4]`), *inside* that site's network. Nothing
  needs inbound access.
- **db-migrations ship the same way:** each site's runner migrates that
  site's database before shipping the projects, exactly the lab 06 order.
- A parent project is one folder in one repo: change it once and every
  site's next deploy carries it.
- **The release files from earlier in this part do the bookkeeping.** The
  repo says what exists; one file per gateway says which version runs where.

**A version tag per project.** One repo does not mean one version number. A
tag carries its project's name as a prefix, and the deploy treats the tag as a
selector, not a repo-wide stamp:

```
commit a41 ── oatmakers@v2.0.0
commit b52 ── oatmakers-packaging@v1.4.0
commit c63 ── (merge: no tag, nothing releases)
commit d74 ── oatmakers-shared@v1.9.2      ← the parent project
commit e85 ── oatmakers@v2.0.1             ← the hotfix
```

```
tag: oatmakers@v2.0.1
  → parse the prefix: "oatmakers"
  → ship ONLY projects/oatmakers/, as it was at that tag
  → nothing is compiled: the files are the release
```

The other folders are present in the checkout and completely ignored; their
version numbers don't move. Five commits, four tags, four independent version
sequences in one repository.

**A parent project is versioned like any other project.** `oatmakers-shared`
is tagged on its own stream, and every gateway that runs `oatmakers` runs the
parent **next to** it: the HMI inherits from it. That is why each parent is
pinned explicitly in every gateway's release file:

```yaml
# releases/production/gw-site4-frontend.yaml
projects:
  oatmakers:
    version: v2.0.1   # its own tag
    shared:  v1.9.2   # its parent, deployed alongside
  oatmakers-packaging:
    version: v1.4.0
    shared:  v1.2.0
```

Delivery is unchanged: release files, promotion by PR, each site's runner
delivering its own.

### Option B: splitting into multiple repositories

Three splits, each answering a different question. Mix them freely.

1. **A repository per site, plus one for the enterprise level**
   (`oatmakers-site1` … `oatmakers-site8`, `oatmakers-enterprise`). Each site
   team owns its own repo and pipeline to its own gateways; the enterprise
   repo deploys `gw-central`. Cost: a change every site needs becomes eight
   PRs, and sites drift apart without bookkeeping.
2. **A repository per vendor project** (`palletizer-vendor`). One project,
   nothing else. The vendor works in it, and their pipeline deploys **only
   that project** to your gateways, alongside your own deploys. They never
   see the rest of the plant. Project-level deploys (lab 04) are what make
   this safe.
3. **Config repositories separate from one projects repository.** All
   projects combined in one repo keeps the shared library and cross-project
   review easy; gateway config per site lives in repos the infra team owns.
   Cost: a feature that needs both takes two PRs, in the right order.

### Choosing: the trade-offs

| Layout | Strongest when | Watch out for |
|---|---|---|
| One repository for everything | One team; shared library used everywhere; a cross-gateway change should be one reviewable PR | Everyone sees everything; vendors need carve-outs; the repo grows with the fleet |
| Repository per site + enterprise | Site teams work at their own pace; access ends at the site boundary | A shared change is N PRs; sites drift apart silently |
| Vendor repository per project | External parties must contribute without seeing the plant | Disciplined project-level deploys; a clear interface contract (which tags and queries the project may expect) |
| Config repos + one projects repo | Infra and application are different teams; projects stay together for the shared library | One feature can need two PRs in two repos |

Pick the *fewest* repositories that answer your actual questions: who may
see what, who owns what, how shared code travels. The releases folder answers
**which version runs where** for every layout here.

---

## Part 4: Tag management: decide who owns the tags

Tags also change on production, while everything else changes in Git.
Decide who owns them before your first multi-gateway deploy.

### Two scenarios that really happen

1. **Operators change tags on production.** Night shift trims an alarm limit
   at 03:00 to stop a nuisance alarm. Saturday's deploy ships the tag export
   from Git: the limit is silently back to the old value. If operators may
   change tags on production, your deploy must not blindly overwrite them.
2. **Process engineers create tags on production.** Forty new tags, born
   directly on the production gateway. The test gateway has never seen them: screens can't be
   tested against them, and a strict "make it match Git" deploy would even
   delete them. Tags born on production need a way back into test and the
   repo.

### Three ownership models

| Model | How it works | Fits when |
|---|---|---|
| **Development is master** | Every tag change travels through the repo and the pipeline. Editing tags on production is forbidden (or exported back the same day). The deploy may overwrite the tag provider. | Tags change rarely and the development team owns the process |
| **Production is master** | Tags are exported from production into the repo on a schedule; the deploy never touches the tag provider; the test gateway refreshes itself from those exports. | Engineers and operators live in the tag browser |
| **Split ownership** | Test owns **structure** (UDT definitions, folders, new tags); production owns **values** (setpoints, alarm limits). The deploy ships definitions and never writes values, or you split by provider or folder. | Most plants, but only if the split is written down and enforced |

Whichever model you pick: write it down, agree it with operations, and let
the pipeline enforce it.

---

## Part 5: How this lab's repo deploys

The assignment runs on one real repository,
[`Mustry-Solutions/demo-oatmakers`](https://github.com/Mustry-Solutions/demo-oatmakers):
the repo behind Mustry's live Oatmakers demo at
<https://cloud.mustrysolutions.com>. It is option A at its smallest: one repo,
one local development gateway, one production gateway (`oatmakers-site-7`)
and one release file.

### Local development and a pinned production deploy

Build and verify changes on the local gateway at `localhost:8088`, backed
by its own PostgreSQL database. Saves in the Designer land in the working
tree through bind mounts. Merge the reviewed feature PR, tag the merged
`main`, then promote the tag with a `release.yaml` PR.

| Trigger | Workflow | Runner label | Target |
|---|---|---|---|
| a merged change to `release.yaml` (a manual run only from `main`) | `Deploy` (`deploy.yml`) | `[self-hosted, demo-oatmakers]` | `oatmakers-site-7`, cloud.mustrysolutions.com |

- **Production is pinned.** The production deploy is wide: every pinned
  project ships from its own tag, and the gateway payload (gateway config,
  module manifest, third-party modules, JARs, migrations) ships from the
  `oatmakers` pin. Migrations run first; a module or JAR change restarts the
  gateway briefly. Per-gateway identity, users and API keys are never shipped.
- **`main` is protected**: a pull request, one approval from someone else and
  a green `CI OK` check. Nobody pushes to `main`.

### A release is a prefixed tag, and the tag comes before the pin

```bash
git switch main && git pull
git tag <yourname>@v1.0.0
git push origin <yourname>@v1.0.0
```

```diff
 # release.yaml
 gateway: oatmakers-site-7
 projects:
   oatmakers: v5.1.0
+  <yourname>: v1.0.0
```

Merging a feature PR deploys nothing to production. The tag makes the release
exist; the `release.yaml` PR (stage it with `git add release.yaml`, never
`git commit -am`) points production at it. CI checks every pin against the
existing tags and turns `CI OK` red for a pin whose tag was never pushed, or
whose tag points at a commit that is not on `main`: tag the merged `main`,
never a feature branch. Pushing a missing tag does not re-run CI; re-run the
failed check from the PR's **Checks** tab.
Rollback is `git revert` of the release PR. A revert re-ships old files; it
does not undo a migration that already ran, so migrations must keep the
previous screens working.

### One version stream, many people

Everyone who changes the shared project cuts the **next free** `oatmakers@`
number:

```bash
git fetch --tags
git tag -l 'oatmakers@*' --sort=-v:refname | head -3
```

- **Tag races happen.** Two people pick `v5.2.0`; the second `git push` of the
  tag is rejected. Delete your local tag (`git tag -d oatmakers@v5.2.0`; a
  plain `git fetch --tags` will not overwrite it), fetch the tags and take
  the next number.
- **A tag contains everything merged before it.** If someone pins `v5.3.0`
  while your `v5.2.0` waits, check whether yours is inside theirs before you
  pin anything:

  ```bash
  git merge-base --is-ancestor oatmakers@v5.2.0 oatmakers@v5.3.0 && echo "already included"
  ```

  Already included: you are live, done. Never pin a lower version over a
  higher one.

### Rules for shipping together to one live gateway

1. Small PRs: one view, one migration pair, one module.
2. Stage only what you changed; the gateway rewrites files on its own.
3. One release PR in flight at a time; announce it in the chat.
4. A conflict in `release.yaml` is normal: `git rebase origin/main`, keep
   every pin from `main`, re-apply only your own line,
   `git push --force-with-lease`.
5. Never lower a pin; a pushed tag is permanent.
6. Announce a release that adds a module or a JAR: it restarts the gateway.

### The five challenges

| Challenge | Where it lives in the repo | Taught in | How it reaches production |
|---|---|---|---|
| Third-party module | `third-party-modules/` + `services/modules.json` | lab 06 | `oatmakers@` pin, gateway restart |
| Library JAR | `jar-files/jar/` | lab 06 | `oatmakers@` pin, gateway restart |
| Migration + referenced secret | `db-migration/migrate/` pair, a connection whose password references `POSTGRES_PASSWORD` | lab 06 | `oatmakers@` pin, migrations run before anything ships |
| Simulator device + tags | `services/config/` (device, tag definitions) | lab 04 (config is files) | `oatmakers@` pin, hot scan |
| History | a historian from the TimescaleDB-Historian module (already in the repo) + history on the tags | lab 06 (modules as data) | `oatmakers@` pin, hot scan |
