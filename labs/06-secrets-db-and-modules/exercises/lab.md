# Lab 06 — Secrets, database migrations, JAR files and third-party modules

**Day 4.** Four things every real Ignition deployment carries
that the pipeline doesn't handle yet: secrets, the database schema, third-party
modules and JAR files. Two real production Ignition repos we maintain (one
file-based, one image-based; shown on screen by the instructor) are the working
references throughout.

**Duration:** ~3.5 hours

* 60 min teaching ([`slides/teaching.html`](https://share.mustrysolutions.com/9d789532-1459-4e18-b819-686fcc62a164), [offline copy](../slides/teaching.html))
* 45-60 min we-do (demos below, woven into the teaching)
* ~85 min you-do ([`slides/assignment.html`](https://share.mustrysolutions.com/014ffcf0-71b9-4e7a-81ef-64d13ea0dbc4) mirrors this file; [offline copy](../slides/assignment.html)):
  warm-up ±10, Part 1 ±30, Part 2 ±20, Part 3 ±25
* Debrief

<!-- Infra status: verified end to end on a real personal fork on 2026-07-30 —
     warm-up, 1A-1D, 2A-2B, 3, the Part 3 negative test and a v* tag release,
     all green on 8.3.8, checked from outside the run logs (pg_stat_activity per
     gateway, schema_migrations on test AND production, module startup lines).
     Nothing open. -->

## Goal

You should leave this lab able to:

- Sort configuration into **public / per-environment / secret**, and say where each kind lives
- Explain why a secret that has ever been pushed is **burned** — the fix is *rotate*, not *delete*
- Move a password from `.env` + Compose interpolation → **file-based secrets** (`/run/secrets/`) → Ignition 8.3 secret providers (embedded vs **referenced**)
- Wire the whole path: **GitHub secret → secret file written by the deploy workflow → file-type secret provider → referenced secret in gateway config** (the production pattern)
- Explain why `db-init/` is bootstrap, not deployment
- Write a schema change as a **golang-migrate up/down pair** (`0002_name.up.sql` / `.down.sql`, like our file-based production repo), apply it with `migrate up`, and read the `schema_migrations` ledger
- Read the migrate step in `lab06-deploy.yml`, which runs **before** the ship step, and say why the order matters
- Deploy **third-party modules**: committed `.modl` files, external-modules folder flag, headless license/cert acceptance in `modules.json`
- Say where the two kinds of **JAR** live: JDBC drivers as 8.3 config resources (inside the config tree), library JARs on the gateway classpath

## Pre-flight

Get the latest course version first. From any folder of your clone, this puts
the course's `main` on your `main`, locally and on your fork. It replaces what
was on your `main`, so earlier exercises can't cause merge conflicts:

```bash
git fetch https://github.com/Mustry-Academy/cicd-for-ignition.git main && git checkout -f -B main FETCH_HEAD && git push -f origin main
```

Push rejected with a rule violation? Lab 03's `protect-main` ruleset is still on
your fork: **Settings → Rules → Rulesets → `protect-main` → Delete ruleset**,
then run the command again.

```bash
cd ~/mustry-academy/cicd-for-ignition/labs/06-secrets-db-and-modules
[ -f .env ] || cp .env.example .env   # keeps the .env course-setup.sh may have made
scripts/setup.sh          # idempotent: safe if the stack is already up
```

Stop the previous lab's stack first (`docker compose down` in its folder):
every Docker lab uses the same ports and container names.

In `.env`, change two lines: `RUNNER_REPO_URL` points at your fork and
`RUNNER_GITHUB_PAT` holds your Lab 04 token. Leave the database passwords as
shipped: Part 1 builds on them. Check that `gh repo set-default --view` prints
`<you>/cicd-for-ignition`.

The workflows live at the course repo's root, not in this folder:
`../../.github/workflows/lab06-{ci,deploy,release}.yml`.

---

## We-do (instructor demos)

### Demo 1 — a leak is forever

1. Commit a fake API key on a branch, push, then "remove" it in a follow-up commit.
2. `git log -p` / GitHub UI: the key is still perfectly readable in history.
3. The real-world response: **rotate the credential**, then (optionally) scrub history — and why scrubbing alone is never enough on a shared remote.

### Demo 2 — where a secret can live, on the image-based production repo (on screen)

1. `.env` → Compose interpolation and where it leaks: `docker inspect`, `docker compose config`, process env.
2. The production setup live: `secrets/` with committed dummy values for local test, a file-type secret provider, a DB connection whose password is `{"type": "Referenced", "data": {"providerName": "PlantSecrets", "secretName": "MSSQL_PASSWORD"}}`, and the `${ENV:NAME}` placeholders in the core collection that the boot script renders to files (umask + chmod **before** the value lands).
3. The infra handoff doc: the table of env vars the infra team fills per environment.

### Demo 3 — migrations, live on the file-based production repo (on screen)

1. `db-init/` recap: rename the volume → SQL runs; existing volume → it doesn't. Bootstrap, not deployment.
2. The `db-migration/migrate/` folder: 4-digit paired files (`0001_….up.sql`/`.down.sql`), `docs/MIGRATIONS.md` rules ("always pairs", "never edit deployed migrations"), `migrate.sh` running golang-migrate in Docker, the `schema_migrations` table.
3. The pipeline steps — and the two flaws worth spotting together: migrations run **after** the scan, with `continueOnError: true`. What can go wrong?

### Demo 4 — modules and JARs, in both repos

1. The file-based repo's `third-party-modules/it|ot/` and the copy step to the gateway host; the image-based repo's `modules/ignition/` as a COPY layer.
2. Headless acceptance: `ACCEPT_MODULE_LICENSES` / `ACCEPT_MODULE_CERTS` env vars, and the `modules.json` `certFingerprint` + `licenseAgreementHash` the gateway *derives* on first boot (you commit what it wrote — you never type them).
3. The JDBC driver JAR living **inside** the 8.3 config tree (`database-driver/PostgreSQL/postgresql-42.7.2.jar` next to its `config.json`), vs library JARs (`modules/jar/` → `lib/core/gateway/`) with pinned dependencies and a README recording where each JAR came from.

## You do (breakout rooms)

Follows [`slides/assignment.html`](https://share.mustrysolutions.com/014ffcf0-71b9-4e7a-81ef-64d13ea0dbc4) ([offline copy](../slides/assignment.html)) 1:1.

### Warm-up (together): deploy to test and production, and check the db-connections

Create the two **deploy environments** on github.com: your fork → **Settings →
Environments → New environment**. In each one, **Environment secrets → Add
environment secret**:

| Environment | Secret | Value | Variables |
|---|---|---|---|
| `lab06-gateway-test` | `IGNITION_API_KEY` | `IGNITION_API_KEY_TEST` from your `.env` | none |
| `lab06-gateway-production` | `IGNITION_API_KEY` | `IGNITION_API_KEY_PRODUCTION` from your `.env` | none |

`setup.sh` generated a unique key per gateway: nothing key-related lives in the
repo, and a test key won't authenticate against production. `lab06-deploy.yml`
picks its environment from the deploy target, so without them nothing deploys.

Now deploy. On github.com open your fork → **Actions** tab → **Lab 06 · Deploy**
in the list on the left → **Run workflow** (on the right) → branch `main`,
gateway `test` → **Run workflow**. Watch the run go green, then do the same with
gateway `production`. Open the test gateway, Connections → Databases →
Connections: both connections (`TimescaleDB` and `TimescaleDB_Reports`) are
**Faulted**; production shows the same. The pipeline is green and the gateway is
broken: a config-only deploy can't carry the password values or the
per-environment database target. Part 1 fixes both.
<!-- Seeded state: TimescaleDB_Reports exists only in core (username
     `reporting`, connectURL → ignition_local_development); TimescaleDB has the local-development/test/production
     overrides. Both passwords are Embedded ciphertexts under CUSTOM
     secrets-management keys that are committed for the local gateway
     (services/config/ignition/keys/ + IGNITION_ROOT_KEY_PASSWORD in compose)
     and excluded from the deploy payload — so local decrypts them and
     test/production fault with "Unable to decrypt ciphertext", by design.
     The TimescaleDB Historian provider (core + all three modes) carries the
     same kind of custom-key ciphertext for `ignition`; it stays silent until
     Part 3 installs its module, and Part 3 step 5 re-points it in the UI. -->

### Part 1: set up a secret for the db-connection (±30 min)
Two db-connections, same database server, different users: `TimescaleDB` logs in
as `ignition`, `TimescaleDB_Reports` as the read-only `reporting` user.
Branch before the first edit, so every Part 1 change lands on the feature branch:
`git switch main && git pull && git switch -c feature/fix-test-db-connections`.
- **1A.** Both passwords become secret files: compose `environment:` → files
  mounted at `/run/secrets/postgres_password` and `/run/secrets/reporting_password`.
  A top-level `secrets:` block declares both files, and **both** get attached to
  **both** services — the DB service (`POSTGRES_PASSWORD_FILE` +
  `REPORTING_PASSWORD_FILE`, and `db-init/` reads the reporting file on a fresh
  volume) and the gateway service (its provider reads them in 1B). Keep the same
  values — Postgres only sets them on first volume init.
- **1B.** Create a **file-type secret provider** (`LabSecrets`) on the local
  gateway with secrets `POSTGRES_PASSWORD` and `REPORTING_PASSWORD`; re-point
  **both** connections at their **referenced** secret (in every deployment
  mode that overrides the password field). Then check `git status`: the provider
  belongs under `resources/core/ignition/secret-provider/`, because
  `local-development` never deploys.

  Landed under `resources/local-development/` by mistake? Test would fault on a
  missing provider while local stays green. Move it to core and rescan:
  `mv services/config/resources/{local-development,core}/ignition/secret-provider`
  and `./scripts/scan.sh`.
- **1C.** Build the fix for test, in two halves: add the **test
  deployment-mode override** for `TimescaleDB_Reports`
  (`…resources/test/ignition/database-connection/TimescaleDB_Reports/config.json`,
  connectURL → `ignition_test`) **and its `production` twin** (connectURL →
  `ignition_production` — production inherits the same core flaw; copy the pattern from
  `TimescaleDB`, which has all three modes), and add
  `POSTGRES_PASSWORD` + `REPORTING_PASSWORD` as secrets on **both**
  environments, on github.com (your fork → **Settings → Environments** → the
  environment → **Add environment secret**). One Postgres serves all three
  databases, so the values are the same everywhere:

  | Environment | Secret | Value |
  |---|---|---|
  | `lab06-gateway-test` | `POSTGRES_PASSWORD` | the content of `secrets/postgres_password.txt` |
  | `lab06-gateway-test` | `REPORTING_PASSWORD` | the content of `secrets/reporting_password.txt` |
  | `lab06-gateway-production` | `POSTGRES_PASSWORD` | the content of `secrets/postgres_password.txt` |
  | `lab06-gateway-production` | `REPORTING_PASSWORD` | the content of `secrets/reporting_password.txt` |

  Nothing to change in the workflow: its **Materialize secret files** step
  already turns these secrets into files, and the **Ship secret files** step
  hands them to the gateway at `/run/secrets/`. Nothing is deployed yet.
- **1D.** The full deploy moment, every station separately: **check the branch**
  (`git branch --show-current` prints `feature/fix-test-db-connections`) → **commit & push** (your diff **adds** no
  secret value: the secret scan in `lab06-ci.yml` is the check) → **open the
  PR on github.com** → **watch the PR validate** (`lab06-ci.yml` green) →
  **merge** → **watch the pipeline deploy** (materialize secret files → ship
  them into the gateway → ship projects and config → scan → smoke check) →
  **verify test** (both connections Valid, `TimescaleDB_Reports` on
  `ignition_test`) → **release to production with a tag** (`git switch main &&
  git pull && git tag lab06-v1.0.0 && git push origin lab06-v1.0.0`: after the
  merge on github.com you are still on your feature branch, so switch and pull
  first, or the tag lands on the feature commit. The Lab 04 routing: the tag,
  not the merge, is what ships to production. `lab06-release.yml` fires on the tag and runs the same
  `lab06-deploy.yml` with `target: production`: same commit, same pipeline steps,
  different environment) → **verify production**
  (both Valid, `TimescaleDB_Reports` on `ignition_production`). Fork carried a
  stale `lab06-v1.0.0` over? `git tag -l 'lab06-*'`, take the next free number.
- **Gate:** both connections Valid on test AND production, fixed by the pipeline
  and not by hand, and you can narrate: GitHub secret → file → provider →
  reference.

### Part 2: ship a DB-migration (±20 min)
- **2A.** Branch first: `git switch main && git pull && git switch -c feature/downtime-log`.
  Write `db-migration/migrate/0002_add_downtime_log.up.sql` **and**
  `.down.sql`; apply with `scripts/migrate.sh up`; read `schema_migrations`
  (version 2, not dirty); re-run to see idempotency (`no change`). Your stack
  starts with **nothing applied** — `scripts/migrate.sh version` says
  `error: no migration` before you begin, and this first `up` applies `0001`
  *and* your `0002` in one go, which is what "replayable from zero" means.
  Note: golang-migrate will NOT stop you editing an applied migration — that
  discipline is a written rule (the production repo's `docs/MIGRATIONS.md`), not
  a tool feature.
- **2B.** Read the **Migrate database** step in `lab06-deploy.yml` (repo
  root). Nothing to change. It sits **above** the `Prune working tree per
  .deployignore` step, which deletes `scripts/` and `db-migration/` from the
  checkout, and **before** the ship step, so the table exists before the screen
  that reads it. It is not `continueOnError`: a failed migration stops the run.
  The database follows the deploy target, so a `target: production` promotion
  migrates `ignition_production`, not test:

  ```yaml
  - name: Migrate database
    run: |
      set -euo pipefail
      case "$DEPLOY_TARGET" in
        production) db=ignition_production ;;
        *)          db=ignition_test ;;
      esac
      ./scripts/migrate.sh up --database "$db"
  ```

  PR with the migration, the named query **and** the screen that reads the new table together;
  watch the run migrate test before shipping; prove it in test's
  `schema_migrations`.

  The screen is deliberately tiny: a table bound to a named query that reads
  the new table. A Perspective query binding always points at a named query,
  so create that first. In the Designer, open `packaging-site`:

  1. **Project Browser → Data → Named Queries → New Query**, name it
     `DowntimeLog`, database `TimescaleDB`, query
     `SELECT reason, minutes, area FROM downtime_log ORDER BY id DESC`. Save.
  2. Open the `pages/packaging` view, drop a **Table** component in, then bind
     `props.data` → **Query** → path `DowntimeLog`. **File → Save All**.

  No Designer? Create the named query as two files in
  `projects/packaging-site/ignition/named-query/DowntimeLog/`. `query.sql`:

  ```sql
  SELECT reason, minutes, area FROM downtime_log ORDER BY id DESC
  ```

  and `resource.json`:

  ```json
  {
    "scope": "DG",
    "version": 2,
    "restricted": false,
    "overridable": true,
    "files": ["query.sql"],
    "attributes": {
      "type": "Query",
      "enabled": true,
      "database": "TimescaleDB",
      "parameters": [],
      "permissions": [{ "zone": "", "role": "" }],
      "useMaxReturnSize": false,
      "maxReturnSize": 100,
      "autoBatchEnabled": false,
      "cacheEnabled": false,
      "cacheAmount": 1,
      "cacheUnit": "SEC",
      "fallbackEnabled": false,
      "fallbackValue": ""
    }
  }
  ```

  Then paste this component into the view's `root.children` list in
  `projects/packaging-site/com.inductiveautomation.perspective/views/pages/packaging/view.json`
  — the JSON *is* the screen, which is the whole reason it deploys as a file:

  ```json
  {
    "meta": { "name": "DowntimeTable" },
    "position": { "grow": 1, "shrink": 1 },
    "propConfig": {
      "props.data": {
        "binding": {
          "config": {
            "parameters": {},
            "polling": { "enabled": false, "rate": "0" },
            "queryPath": "DowntimeLog",
            "returnFormat": "dataset"
          },
          "type": "query"
        }
      }
    },
    "props": { "style": { "margin": "16px" } },
    "type": "ia.display.table"
  }
  ```

  Note *where* that named query runs: on the gateway, against **that gateway's**
  `TimescaleDB` connection — so the same screen reads `ignition_test` on test
  and `ignition_production` on production, and it needs its table to already be
  there. That is the whole argument for migrate-before-ship.
- **Gate:** a green deploy run whose log shows migrate → ship → scan → verify, and test's ledger at version 2 (the `lab06-v1.1.0` release at the end of Part 3 migrates `ignition_production` the same way).

### Part 3: deploy third-party modules (±25 min)
- Install the three spare `.modl` files by adding **minimal** `services/modules.json` entries, let the gateway derive the acceptance fields, commit them, ship them through the pipeline, and verify they come up **Running** with no hands on the gateway.

  The spare modules are **Embr Periscope**, **Embr Charts** and the **TimescaleDB Historian**. Their `.modl` files already sit in `third-party-modules/` — and that is *all* that ships: no `modules.json` entry, and their ids are absent from the compose module env vars. The gateway neither loads nor trusts them.

  Branch first: `git switch main && git pull && git switch -c feature/third-party-modules`.

  **Step 1 — look first.** Open `http://localhost:8088` → *Platform → Modules* (the platform-modules page): none of the three is in the list. A `.modl` on disk does nothing on its own.

  **Step 2 — accept them in the env vars.** In `docker-compose.yaml`, add the three module ids to **all three** lists in the shared env anchor: `GATEWAY_MODULES_ENABLED` (the gateway may load them), plus `ACCEPT_MODULE_LICENSES` and `ACCEPT_MODULE_CERTS` (headless license + certificate acceptance). The ids are hard to discover, so they are given:

  ```
  com.mussonindustrial.embr.periscope
  com.mussonindustrial.embr.charts
  com.mustry.historian.timescaledb
  ```

  **Step 3 — add the manifest lines you actually know.** You do *not* know the fingerprints or the license hashes, and you shouldn't guess. Add only:

  ```json
  "com.mussonindustrial.embr.periscope": {
    "filename": "/third-party-modules/Embr-Periscope-Ignition83-0.12.0.modl",
    "onStartup": "enabled"
  },
  "com.mussonindustrial.embr.charts": {
    "filename": "/third-party-modules/Embr-Charts-Ignition83-4.0.1.modl",
    "onStartup": "enabled"
  },
  "com.mustry.historian.timescaledb": {
    "filename": "/third-party-modules/TimescaleDB-Historian.modl",
    "onStartup": "enabled"
  }
  ```

  **Step 4: boot once and let the gateway fill in the rest.** `docker compose up -d`: the env lists live in a shared YAML anchor, so this recreates **all three** gateways, and the local one is the one that matters here. On that boot it accepts the licenses from the env vars, installs the modules headlessly and **rewrites `modules.json`**, appending to each entry the two fields it computed:

  ```json
    "certFingerprint": "e5a3cf3f06627c175b68b0122ac8f2c3f9c992e2",
    "licenseAgreementHash": 101444854
  ```

  Side effect of that recreate: test and production are **new containers**, and
  the secret files the pipeline wrote into `/run/secrets` lived in the old ones.
  Both gateways show their database connections **Faulted** ("Unable to read
  secret 'POSTGRES_PASSWORD' from provider 'LabSecrets'") until the pipeline
  deploys to them again: step 6 does that for test, step 7 for production.

  `git diff services/modules.json` shows exactly what it added. **Commit those lines** (together with your `docker-compose.yaml` edit). They are the whole point: with acceptance stored as data, a *fresh* gateway (an image-based deploy, a rebuilt container) installs the modules without a human ever clicking an install dialog. The negative test below is what shows you the other side of it: strip the derived lines and the boot stops dead at commissioning.

  **Step 5 — verify they are actually Running:**

  ```bash
  # the gateway logged them starting up:
  docker logs lab06-gateway-local-development 2>&1 | grep -E "Starting up module 'com\.(mussonindustrial|mustry)"
  ```

  Three `Starting up module` lines (Periscope, Charts and the TimescaleDB Historian) = installed and Running. In the UI it is *Platform → Modules*: all three listed, all Running.

  **Step 5b: point the historian's password at the secret.** The TimescaleDB
  Historian's password is still **Embedded**: it only decrypts on your local
  gateway, so test and production would fail with `Error adding historian`. On
  the local gateway (`http://localhost:8088`) open **Services → Historians →
  TimescaleDB Historian → Edit**, set the password to **Referenced** with
  provider `LabSecrets` and secret `POSTGRES_PASSWORD`, and **Save**. The
  historian has its own settings in every deployment mode: do the same for
  **core**, **local-development**, **test** and **production**. `git status`
  then shows the four historian folders changed; commit them with
  the module changes.

  **Step 6: ship them.** PR → merge → deploy run. Because the module manifest changed, the deploy **restarts** the gateway: modules only load at boot, unlike projects and config, which reload hot. The same run ships test's secret files again, so its connections turn Valid.

  Then open *Services → Historians* on test: the **TimescaleDB Historian** provider is **Running**. You never configured it on test: its config waited in the repo for its module, and since step 5b its password is a **reference** (`LabSecrets` / `POSTGRES_PASSWORD`) that each gateway resolves from its own secret file. Not Running there after the run? Step 5b missed a deployment mode: the embedded ciphertext only decrypts on your local gateway. (The gateway log shows one `Error adding historian` during the module restart in every run: the restart happens before the new config ships, and the historian starts a few seconds later.)

  **Step 7: release it.** Production still runs `lab06-v1.0.0`, and since step 4 its connections are Faulted:

  ```bash
  git switch main && git pull && git tag lab06-v1.1.0 && git push origin lab06-v1.1.0
  ```

  Check production (`http://localhost:8090`): the three modules **Running**, the TimescaleDB Historian provider **Running**, both connections **Valid**, and the `ignition_production` ledger at 2 (this release also carries Part 2's migration):

  ```bash
  docker exec lab06-timescaledb psql -U ignition -d ignition_production -c 'SELECT * FROM schema_migrations;'
  ```

  **Negative test (what un-accepted looks like), on one module.** Do this on your
  own local gateway, last — not in a second checkout (a second clone would fight
  this one for ports 8088-8090 and, sharing the compose project name, for the
  same containers and volumes). Delete Periscope's two derived lines **and** drop
  `com.mussonindustrial.embr.periscope` from `ACCEPT_MODULE_LICENSES` /
  `ACCEPT_MODULE_CERTS` — leaving it in `GATEWAY_MODULES_ENABLED` — then wipe the
  local gateway's volume and boot it. Make both edits before you boot: a boot with
  only one of them writes the derived lines straight back.

  ```bash
  docker compose rm -sf gateway-local-development
  docker volume rm "$(docker compose config --format json \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')_gateway-local-data"
  docker compose up -d gateway-local-development
  curl http://localhost:8088/StatusPing
  # → {"state":"RUNNING","details":"COMMISSIONING"}
  ```

  A module that is enabled but unaccepted parks the gateway at the commissioning
  screen: it will not finish booting until a human accepts the licence, which on
  a server nobody is sitting at means the gateway is simply down. That is why
  acceptance has to be data in the repo.

  **Recovering takes two stages, and it is worth understanding why.** That
  fresh volume re-ran commissioning, and commissioning found the committed
  `security-properties` policy but no internal identity on disk. So it played
  safe: it created a `temp` user source + identity provider and rewrote
  `security-properties` to point at them, dropping the `APIToken` read/write
  permissions your scan API needs. First put the acceptance back and let the
  gateway finish booting: until then the `temp` identity doesn't exist yet, so
  there is nothing to undo and the scan still 403s. Then undo it:

  ```bash
  # 1: the acceptance back (your committed manifest + env lists), boot to RUNNING
  git checkout -- docker-compose.yaml services/modules.json
  docker compose up -d gateway-local-development
  until curl -fsS http://localhost:8088/StatusPing | grep -qx '{"state":"RUNNING"}'; do sleep 5; done
  # 2: undo what commissioning did to the identity policy, then restart
  git checkout -- services/config/resources/core/ignition/security-properties/
  rm -rf services/config/resources/core/ignition/{user-source,identity-provider}/temp
  docker restart lab06-gateway-local-development
  until curl -fsS http://localhost:8088/StatusPing | grep -qx '{"state":"RUNNING"}'; do sleep 5; done
  ./scripts/scan.sh    # HTTP 200 again = the API token permissions are back
  ```

  Note what that means for the real world: wiping a gateway's data volume while
  its config tree survives is exactly how you lock yourself out of a gateway.
  `scripts/setup.sh` choreographs the first boot to avoid it; a bare
  `docker compose up` on a wiped volume does not.
- **Gate:** all three modules Running on test **and** production, hands-free (*Platform → Modules* shows all three Running), the TimescaleDB Historian provider Running on both (*Services → Historians*), and production's connections Valid with its ledger at 2 after the `lab06-v1.1.0` release.

### Stretch (optional)
- **S1.** The internal secret provider, and where it breaks: create an **internal secret provider** on the local gateway, store `REPORTING_PASSWORD` in it (the gateway encrypts it and keeps the ciphertext in its own config) and point `TimescaleDB_Reports` at it in core **and** in the test override from 1C (it overrides the password field, so a core-only change never reaches test). Locally it stays Valid; ship it and test faults: the ciphertext only decrypts on the gateway that created it. Then revert to the referenced secret from Part 1.
- **S2.** Expand-contract rename: `0003` add + backfill, screen switch, `0004` drop.
- **S3.** Add a `gitleaks` job to `lab06-ci.yml`; test it with a fake-key PR (red), then close the PR without merging. Make the fake key random: gitleaks ignores obvious fakes like `1234abcd` or AWS's `EXAMPLE` keys. This one is caught:

  ```bash
  echo "reporting_api_key = \"$(openssl rand -hex 20)\"" > projects/fake-key.txt
  ```

  With `fetch-depth: 0` gitleaks scans **every commit in the PR**, so a key added in one commit and deleted in the next still fails:

  ```yaml
  gitleaks:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v3
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  ```
- **S4.** Ship a **library JAR** through the pipeline and use it on a screen.
  The teaching's second kind of JAR, done for real: `jar-files/jar/` carries
  `commons-csv-1.14.1.jar` (pinned, checksummed in its README), and your job
  is to get it onto the gateway classpath (`lib/core/gateway/`) via the
  pipeline, then prove it works from a Perspective screen.

  1. **Prove the gap first.** In any lab project, add a view with a **Text
     Field** and a **Label** next to it, wired through a view custom
     property (this is the shape `lab06-ci.yml`'s iglint accepts; a
     binding that reaches a sibling with `../TextField` fails its
     VIEW018 fragile-component-reference rule):
     - add a custom property `line` on the view (`view.custom.line`, a
       string);
     - bind the text field's `props.text` to `view.custom.line` with a
       **property binding**, **bidirectional** ticked (typing writes the
       property);
     - bind the label's `props.text` to `view.custom.line` (property binding)
       and add this **script transform**:

     ```python
     def transform(self, value, quality, timestamp):
         from org.apache.commons.csv import CSVFormat
         from java.io import StringReader
         records = CSVFormat.DEFAULT.parse(StringReader(value or "")).getRecords()
         return " | ".join(records[0]) if records else ""
     ```

     The imports sit inside the transform: a transform is a function body.

     The binding errors (`No module named csv`): the class isn't on the
     gateway classpath yet. (Perspective bindings run **on the gateway**, so
     it's the gateway's classpath that counts, not the Designer's.)
  2. **Fix local with a file volume.** The local gateway gets the JAR the way
     it gets everything else: a bind mount — a single-file one, exactly like
     the `services/modules.json` line already there. Add this to the
     `gateway-local-development` service's `volumes:` list in
     `docker-compose.yaml`:

     ```yaml
     - ./jar-files/jar/commons-csv-1.14.1.jar:/usr/local/bin/ignition/lib/core/gateway/commons-csv-1.14.1.jar
     ```

     Then `docker compose up -d` — the config change recreates the gateway.
     Library JARs load at **boot**, like modules. After the gateway is back,
     type a CSV line in the text field: the label shows the parsed fields
     (`pump,3,ok` → `pump | 3 | ok`).
  3. **Make it deployable state.** Test and production have no working tree
     to mount from — the pipeline ships the bytes. The step below is ready
     to copy: paste it into `lab06-deploy.yml` at the marked
     `# Stretch S4: paste the ready-made "Ship library JARs" step HERE`
     comment, right after the module-manifest step (it is the same pattern:
     copy, compare, restart only when changed):

     ```yaml
     - name: Ship library JARs (restart if changed)
       run: |
         set -euo pipefail
         shopt -s nullglob
         changed=false
         for f in jar-files/jar/*.jar; do
           name="$(basename "$f")"
           before="$(docker exec "$IGNITION_CONTAINER" md5sum "/usr/local/bin/ignition/lib/core/gateway/$name" 2>/dev/null | cut -d' ' -f1 || true)"
           if [ "$before" != "$(md5sum "$f" | cut -d' ' -f1)" ]; then
             docker cp "$f" "$IGNITION_CONTAINER:/usr/local/bin/ignition/lib/core/gateway/$name"
             echo "  shipped JAR $name"
             changed=true
           fi
         done
         if [ "$changed" = false ]; then
           echo "Library JARs unchanged — no restart needed."
           exit 0
         fi
         docker restart "$IGNITION_CONTAINER"
         # RUNNING without COMMISSIONING, like the module step above.
         state=''
         for _ in $(seq 1 60); do
           state="$(curl -fsS --max-time 3 "$IGNITION_URL/StatusPing" 2>/dev/null || true)"
           if echo "$state" | grep -q '"state":"RUNNING"' && ! echo "$state" | grep -q COMMISSIONING; then
             echo "gateway RUNNING again."
             exit 0
           fi
           sleep 5
         done
         echo "gateway did not come back after JAR restart (last StatusPing: ${state:-no answer})" >&2
         exit 1
     ```

     Also add `"labs/06-secrets-db-and-modules/jar-files/**"` to the `push.paths` list at the top of
     `lab06-deploy.yml` — without it, a PR that only changes a JAR never triggers a
     deploy.
  4. **Ship it.** PR with the view, the compose volume **and** the workflow
     change → merge → watch the run ship the JAR and restart test → open the
     view on test (`http://localhost:8089`) and see the CSV parse on a
     gateway you never touched.
  - **Gate:** typing a CSV line in the text field shows the parsed fields on
    **test**, the JAR got there through the pipeline, and the run log shows a
    restart on the JAR deploy but none on your next config-only deploy.

## Debrief

- One surprise, one question, per room.
- Why must the migrate step never be `continueOnError`?
- The production ordering question from Demo 3: migrations after the scan, with `continueOnError: true`. What incident does that setup eventually produce?
