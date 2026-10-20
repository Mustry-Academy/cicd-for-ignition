# Lab 05: Build the gateway image and deploy it by replacing the container

**Duration:** ~2 hours 15 minutes after the teaching, in two parts

1. **Build the gateway image** (~70 min): put project, config **and modules** into immutable Docker layers, prove the image is self-contained, learn to read the layer cache, then put a change of your own into it and keep a stray file out with `.dockerignore`.
2. **Deploy the image** (~65 min): deploy to the test gateway by recreating the container, ship a change end-to-end, and roll back by running the previous build's tag.

The second part deploys exactly the image you build in the first. Do them in order.

## Goal

You should leave this lab able to:

- Explain what an *image-based* gateway is: project, config, **and modules** built into immutable Docker layers, versus files copied into a running gateway (Lab 04).
- Read the [`Dockerfile`](../Dockerfile) and say what each `COPY` puts where, and why the layer order is what it is.
- Read [`.dockerignore`](../.dockerignore) and explain why each pattern keeps the build context lean and secrets out of the image.
- Build the image, tag it with a version such as `:v1.2`, and run it **with no bind mounts**, proving the image is self-contained.
- Inspect the layers with `docker history` and trace a running container back to its commit.
- Deploy an image-based gateway by **recreating the container** from a new image: no `docker cp`, no scan call.
- Ship a change end-to-end by hand: edit → commit → rebuild → redeploy, and explain that this loop is exactly what a deploy pipeline automates.
- Roll a gateway back by **running the previous build's immutable tag**, and explain why versioned artifacts make that cheap.
- Say what survives a container-replace deploy (external DB data) and what does not (internal gateway state, trial clock, UI-made edits).

## Pre-flight

**First, get the latest course version.** From any folder of your clone, this puts the
latest course version on your `main`, locally and on your fork. It replaces whatever was on
your `main`, so there are no merge conflicts:

```bash
git fetch https://github.com/Mustry-Academy/cicd-for-ignition.git main && git checkout -f -B main FETCH_HEAD && git push -f origin main
```

Push rejected with a rule violation? Lab 03's `protect-main` ruleset is still on
your fork: **Settings → Rules → Rulesets → `protect-main` → Delete ruleset**,
then run the command again.

Then stop the previous lab's stack (every Docker lab uses the same ports) and bring this one
up from this lab's folder:

```bash
(cd ../04-ignition-file-based-deploy && docker compose down)
scripts/setup.sh    # safe to re-run: it keeps test/production on the image they run
```

You'll need Docker with Compose v2 and ~8 GB free RAM. You build and deploy on your machine; your changes reach `main` the GitHub flow way: a feature branch, a PR into your fork, merged on GitHub, then `git pull`. If you'd like to read ahead: [`docs/dockerfile-anatomy.md`](../docs/dockerfile-anatomy.md).

> **A bare `docker compose up -d` resets test and production.** The compose file runs the
> base image (an empty gateway) on test/production unless `IGNITION_TEST_IMAGE` /
> `IGNITION_PRODUCTION_IMAGE` are set. So after you deploy an image, a plain
> `docker compose up -d` without them recreates those gateways **empty**. Redeploy with the
> deploy one-liner from Part 2, or put the image in `.env` (`IGNITION_TEST_IMAGE=...`) to make
> it stick. `scripts/setup.sh` guards against this; plain compose does not.

---

# Part 1: Build the gateway image

**Timing:** 20 min demo · 20 min we-do · 20 min you-do · 10 min debrief

## Demo (20 min)

The instructor walks the two files that define the image; build and run along on your machine.

### The mental model

In Lab 04 the gateway was a long-lived, *mutable* thing: you copied files into its `data/` directory and asked it to scan. In image-based deploy the gateway is *immutable*: the deployable state is frozen into an image, and you deploy by replacing the whole container.

Both approaches deliver the same files to the same paths and achieve the same result. File-based keeps the gateway alive (no restarts, fast inner loop) but you own the copy-and-delete logic; image-based gives you a frozen, versioned artifact with no copy scripts, but every deploy is a fresh gateway boot.

### Walk the Dockerfile

Open [`Dockerfile`](../Dockerfile). Four `COPY` lines put the deployable state into the image, and two small `RUN` lines do work at build time (`…` is `/usr/local/bin/ignition`):

```dockerfile
FROM inductiveautomation/ignition:${IGNITION_VERSION}

COPY --chown=2003:0 third-party-modules/  /third-party-modules/        # large, rarely change
RUN sha256sum /third-party-modules/*.modl && sleep 5                   # stand-in for a module signature/AV scan
COPY --chown=2003:0 services/modules.json …/data/modules.json          # which modules turn on
COPY --chown=2003:0 services/config/      …/data/config/               # gateway config
RUN sed -i 's/"defaultAuthProfileCreated": true/…false/' \
      …/data/config/resources/core/com.inductiveautomation.opcua/one-time/config.json
COPY --chown=2003:0 projects/             …/data/projects/             # project content (changes most)
```

Four things to call out on the board:

1. **Where files land.** `data/projects/` and `data/config/` are the same paths Lab 04's `docker cp` targeted: Ignition scans them at startup. The difference is *when*: Lab 04 copied at deploy time into a running gateway; here they're present from the first boot. `data/modules.json` is the same `services/modules.json` the local gateway reads through its bind mount: one module list, so local, test and production start the same modules.
2. **Layer order = cache strategy.** Docker caches each layer keyed on its inputs. Order from least- to most-frequently-changed, so editing a Perspective view (bottom layer) doesn't bust the modules layer and the 5-second `RUN` above it. Rebuilds stay fast.
3. **`--chown=2003:0`.** The gateway runs as the image's own `ignition` user (uid 2003), not root. A plain `COPY` leaves files root-owned and the gateway FAULTs at boot because it cannot write under `config/`. Ownership is part of what you bake.
4. **The OPC UA `RUN`.** Every tag reads through the OPC UA server's loopback connection, which logs in with an `opcua-module` user source. That user source holds a password hash, so it is never committed or put in the image. The module only creates it when its one-time flag says it hasn't yet; the `sed` re-arms that flag in the image, so every gateway built from it creates its own login at first boot. Without it, the gateway logs `User Source "opcua-module" not found` and every OPC tag reads bad.

### Walk the .dockerignore

Open [`.dockerignore`](../.dockerignore). It's the image-based analogue of Lab 04's `.deployignore`: it controls what enters the **build context**, the tarball Docker hands the builder before running the Dockerfile. Three reasons every excluded line matters:

- **Smaller/faster builds:** `docs/`, `exercises/`, `slides/` and the gateway's own `.resources/` blob stores are megabytes Docker would otherwise upload and checksum.
- **Cleaner image:** even though our `Dockerfile` only `COPY`s four things, a stray `COPY . .` in a future edit would drag in everything not ignored. And `COPY projects/` copies **everything** in that folder, so anything you leave there ships unless `.dockerignore` excludes it. Defence in depth.
- **No leaked secrets:** `.env` is excluded so credentials can never end up in a published artifact. This is the line that matters most.

### Build it and run it standalone

```bash
scripts/build-image.sh          # builds and tags :local
docker history cicd-lab-05-ignition:local   # see the layers, newest on top
```

Now run the image **with no bind mounts** on a spare port: this is the proof that the image carries everything. `scripts/build-image.sh` prints the same command at the end of every build (with the build's own tag instead of `:local`):

```bash
docker run -d --rm --name demo -p 9088:8088 \
  -e ACCEPT_IGNITION_EULA=Y \
  -e IGNITION_EDITION=standard \
  -e GATEWAY_ADMIN_USERNAME=admin \
  -e GATEWAY_ADMIN_PASSWORD=password \
  cicd-lab-05-ignition:local \
  -n demo -- -Dignition.allowunsignedmodules=true \
  -Dignition.gateway.externalModulesFolder=/third-party-modules
docker logs -f demo
# wait ~30-60s for "Starting project: example-project" in the log,
# then open http://localhost:9088 → the example-project is there
```

No `./projects` mount, no scan call: the project showed up because it's *inside the image*. The `-d` runs it detached, so Ctrl-C only leaves the logs; stop the gateway with `docker stop demo` (the `--rm` cleans it up). The last argument tells the gateway where the third-party modules in the image live; leave it out and those modules never load (the log says `Error adding historian`, because the TimescaleDB historian is one of them).

## We-do (20 min)

Together, build and dissect the image.

1. **Build with a real provenance stamp.** `scripts/build-image.sh` passes `--build-arg GIT_SHA=$(git rev-parse --short HEAD)`. Confirm it landed:
   ```bash
   docker inspect -f '{{ index .Config.Labels "org.opencontainers.image.revision" }}' \
     cicd-lab-05-ignition:local
   git rev-parse --short HEAD
   ```
   That label is how you trace any running container back to the commit it was built from.

2. **Prove the layer cache.** Build once (done). First, a trap: `touch` a project file and rebuild:
   ```bash
   touch projects/example-project/project.json
   scripts/build-image.sh
   ```
   Every layer still says `CACHED`. Docker keys the `COPY` cache on a checksum of file *contents*; timestamps are invisible to it. Now make a real change and rebuild:
   ```bash
   printf '\n' >> projects/example-project/project.json   # any content change works
   scripts/build-image.sh
   ```
   The modules/config layers stay `CACHED`; only the `projects/` layer (and anything after it) rebuilds. Then drop a new file into `third-party-modules/` and rebuild:
   ```bash
   echo test > third-party-modules/dummy.txt   # a new file IS a content change
   scripts/build-image.sh
   ```
   Notice *more* layers bust, including the 5-second `RUN`, because that `COPY` sits higher in the Dockerfile.

   **Clean up and rebuild:**
   ```bash
   rm third-party-modules/dummy.txt && git checkout -- projects/ && scripts/build-image.sh
   ```
   Otherwise the dummy file and the stray newline end up in every later build.

3. **Explore the image, not the repo.** Open the image in Docker Desktop (*Images →
   `cicd-lab-05-ignition` → Files*), or whatever image browser you prefer, and find all four
   things the Dockerfile COPYed. Three live under `/usr/local/bin/ignition/data/`: `projects/`,
   `config/` and `modules.json`; the fourth is `/third-party-modules` at the root. Note what's
   *not* there: `README.md`, `docs/`, `.env`. Prefer the CLI?
   The Ignition base image's entrypoint treats trailing args as *gateway* arguments, so override
   it with `--entrypoint`:
   ```bash
   docker run --rm --entrypoint find cicd-lab-05-ignition:local \
     /usr/local/bin/ignition/data/projects -maxdepth 2
   ```

## You do (20 min)

Your turn: change what goes into the image, rebuild, and prove the change from the image
itself, using the commands from the we-do. Work on a branch off an up-to-date `main`:

```bash
git switch main && git pull
git switch -c feature/image-change
```

### Part 1.1: Put a config change into the image (10 min)

1. Open `services/config/resources/core/ignition/system-properties/config.json` and replace the
   text of `"homepageNotes"` with a note of your own, e.g.
   `"homepageNotes": "Built into the gateway image. Deployed by replacing the container."`.
   That is the note a logged-in user sees on the gateway's Home page.
2. Rebuild with `scripts/build-image.sh`. Which layers rebuilt, and which stayed `CACHED`? Why
   did the `projects/` layer rebuild although you never touched a project?
3. Prove the change is **in the image**, not just in your folder:
   ```bash
   docker run --rm --entrypoint grep cicd-lab-05-ignition:local homepageNotes \
     /usr/local/bin/ignition/data/config/resources/core/ignition/system-properties/config.json
   ```

### Part 1.2: Keep a project export out of the image (10 min)

`COPY projects/` copies everything in that folder. Someone exported a project from the
gateway and saved the export in it:

1. Simulate it: `echo "pretend this is a project export" > projects/example-project-export.zip`.
2. Rebuild, then find it in the image:
   ```bash
   scripts/build-image.sh
   docker run --rm --entrypoint find cicd-lab-05-ignition:local \
     /usr/local/bin/ignition/data/projects -maxdepth 1
   ```
   It's there.
3. Add a pattern for it to `.dockerignore`, with a one-line comment that says why:
   ```
   # Project exports are copies of a project: keep them out of the image
   **/*.zip
   ```
   Rebuild and run the same `find`: the file is gone from the image, although it's still on
   your disk.
4. Delete the file (`rm projects/example-project-export.zip`), check `git status` shows only
   your two edits, then commit and push:
   ```bash
   git add .dockerignore services/config/resources/core/ignition/system-properties/config.json
   git commit -m "Add a homepage note and keep project exports out of the image"
   git push -u origin feature/image-change
   ```
   On GitHub, open a pull request into your fork's `main`, wait until `lab05-ci.yml` is
   green and merge it. Then pull `main`:
   ```bash
   git switch main && git pull
   ```
5. Build version `v1.2` from `main`. That is the image you deploy in Part 2:
   ```bash
   scripts/build-image.sh --tag v1.2
   ```
   On your fork the merge also fired `lab05-deploy.yml`, which builds the same commit on a
   GitHub-hosted runner and pushes it to your GHCR. You don't need that image today (the
   stretch uses it); a red or missing run there doesn't block this lab.

## Definition of done (part 1)

You're finished with part 1 when:

- [ ] `scripts/build-image.sh` builds the image and tags it `:local`.
- [ ] You ran the image **with no bind mounts** and saw `example-project` load, proving it's self-contained.
- [ ] You can explain the Dockerfile's layer order in terms of cache busting.
- [ ] You can trace a built image back to its commit via the `revision` label.
- [ ] Your homepage note is in the image, proven with `docker run --entrypoint`.
- [ ] `.dockerignore` keeps `*.zip` project exports out of the image, proven with `find` before and after.
- [ ] You built `v1.2` from `main` after your PR was merged.

## Stretch challenge `[OPTIONAL]`

- **`docker history --no-trunc`.** Find which layer is largest. Is it the base image, the modules, or your project? What would you do differently if the project were 500 MB of assets?

## Debrief (10 min)

- The image is immutable, but the gateway still writes runtime state (internal DB, logs) at `data/`. Where does that go in our test/production setup, and why is it safe to throw away on each deploy? (Hint: look at what's *not* a volume in `docker-compose.yaml`, and where historian data lives.)
- We pin `inductiveautomation/ignition:8.3.8`, not `:latest`. Why does an immutable-artifact philosophy demand a pinned base?
- Lab 04's `.deployignore` was read by a shell loop in the workflow; Lab 05's `.dockerignore` is read by the Docker daemon. What does moving that responsibility *into the tool* buy you?
- In part 2 this image gets deployed, and in a real pipeline it would go through a registry first. What's the one tag you'd never want to deploy to production by name, and why? (Foreshadow: moving vs. immutable tags.)

---

# Part 2: Deploy the image locally by replacing the container

**Timing:** 15 min instructor demo · 40 min you-do · 10 min debrief

Every deploy in this part runs on your own machine, **and you type the deploy
commands yourself, no script**. Your merges still reach GitHub (GitHub flow, as in
Part 1), so `lab05-deploy.yml` builds each of them on your fork too, but you deploy
your own local build of the same commit. Your local Docker image store plays the
role of the registry.

## Pre-flight

Part 1 finished: you have built `v1.2`, and
`scripts/setup.sh` has the stack up (local gateway :8088, test gateway :8089,
TimescaleDB).

## Instructor demo (15 min)

Watch on the instructor's screen; you type the same commands yourself in Part 2.1. The
instructor deploys a Part 1 image to the test gateway once and points out:

1. **Before:** which image does test run? `docker compose ps ignition-test` shows the plain
   base image: an empty gateway.
2. **The deploy is one command:** `IGNITION_TEST_IMAGE=<image> docker compose up -d ignition-test`.
   `docker-compose.yaml` reads the variable into the test service's `image:`
   (`image: "${IGNITION_TEST_IMAGE:-inductiveautomation/ignition:8.3.8}"`, the base image
   when it's unset); compose sees a new image and recreates the container.
3. **The wait:** a fresh-image boot re-commissions the gateway, so it takes a few minutes to
   reach RUNNING.
4. **What persisted:** the historian's tables live in TimescaleDB, not in the container.

## You do (40 min)

### Part 2.1: Deploy `v1.2` to test (10 min)

1. `docker images cicd-lab-05-ignition` lists `v1.2` among the other tags.
2. **Before:** which image is test running?
   ```bash
   docker compose ps ignition-test
   ```
   The `IMAGE` column shows `inductiveautomation/ignition:8.3.8`: the base image, an empty
   gateway.
3. Check the historian's database before the deploy:
   ```bash
   docker exec lab05-timescaledb psql -U ignition -d ignition_test -c '\dt'
   ```
   The first check shows no tables (`Did not find any relations`); they appear after the
   first deploy and survive every later one.
4. **Deploy** `v1.2`:
   ```bash
   IGNITION_TEST_IMAGE=cicd-lab-05-ignition:v1.2 docker compose up -d ignition-test
   ```
5. **Wait for RUNNING:** `curl -s localhost:8089/StatusPing` until it prints `{"state":"RUNNING"}`.
   `{"state":"RUNNING","details":"COMMISSIONING"}` means it is still commissioning: keep waiting.
6. **Verify:** run `docker compose ps ignition-test` again: it now shows
   `cicd-lab-05-ignition:v1.2`. Open http://localhost:8089/app/home/perspective/session-launcher
   and launch example-project: the project from the image is live. Log in at
   http://localhost:8089: the Home page shows your Part 1.1 note. No copy, no scan: the
   container was **replaced**.
7. Run the `psql` line again: the historian's tables are there now.

### Part 2.2: Change a view, build `v1.3` and deploy it (15 min)

The full loop a pipeline automates.

1. Make a branch off an up-to-date `main`:
   ```bash
   git switch main && git pull
   git switch -c feature/tweak-view
   ```
2. Change the view in the Designer, on the local gateway (:8088): open *Perspective → Views →
   pages → overview*, select the **Title** label in the header, change its text and
   **File → Save All**. The local gateway writes the change into `projects/`.
3. Commit and push:
   ```bash
   git status                     # only your view shows up
   git add projects/ && git commit -m "Change overview title"
   git push -u origin feature/tweak-view
   ```
   On GitHub, open a pull request into your fork's `main`, wait until it is green and merge
   it. Then pull `main`:
   ```bash
   git switch main && git pull
   ```
4. Build `v1.3` and deploy it:
   ```bash
   scripts/build-image.sh --tag v1.3
   IGNITION_TEST_IMAGE=cicd-lab-05-ignition:v1.3 docker compose up -d ignition-test
   ```
5. Verify at :8089: your title is live, and `docker compose ps ignition-test` shows `v1.3`.
   `docker images` now shows **`v1.2` and `v1.3`**: two deployable versions, both still on
   your machine.

### Part 2.3: Roll back to `v1.2` (10 min)

1. Pretend `v1.3` broke something on test. You need the previous version back, now.
2. Deploy `v1.2`: the same command, the older version:
   ```bash
   IGNITION_TEST_IMAGE=cicd-lab-05-ignition:v1.2 docker compose up -d ignition-test
   ```
3. Verify at :8089: the title is back to its previous text, and `docker compose ps
   ignition-test` shows `v1.2`.
4. Count the irreversible steps you just took. (Zero: both versions still exist, and you can flip between them as often as you like.)

## Definition of done (part 2)

- [ ] The test gateway (:8089) runs **your** image, shown by `docker compose ps ignition-test`.
- [ ] You shipped a view change as `v1.3`: Designer → PR → build → deploy → visible on test.
- [ ] Your image store holds **`v1.2` and `v1.3`**.
- [ ] You rolled test back to `v1.2` and verified the old title is live again.
- [ ] You checked that the historian's tables appeared with the first deploy and survived the later ones (`psql … -c '\dt'`), and can say why.
- [ ] You can name the two steps a production pipeline adds between your build and your run (push + pull).

## Stretch challenge `[OPTIONAL]`

Three directions, pick by appetite:

1. **Let GitHub build the image for you.** In part 2 you built locally and deployed
   by hand. The workflows in this repo move the **build** half to CI, GitHub flow:
   merge to `main` → an image is built and pushed, tag → that image is promoted.
   The deploy half stays manual, exactly like you did it.
   0. **Only if the pull in step 2 says `denied`:** the first push created the package
      `cicd-lab-05-ignition` under your account. From a public fork it is normally public and
      needs no login. If it is private, log Docker in with a token that may read packages
      (add the scope once, it opens your browser):
      ```bash
      gh auth refresh -h github.com -s read:packages
      gh auth token | docker login ghcr.io -u <your-user> --password-stdin
      ```
      (Or make the package public: your GitHub profile → *Packages* →
      `cicd-lab-05-ignition` → *Package settings* → *Change visibility*.)
   1. Your merges already did the CI half. Each PR you opened ran `lab05-ci.yml` (including
      a no-push image build), and each merge fired `lab05-deploy.yml`, which built that
      commit on a free GitHub-hosted runner and pushed it to **your** GHCR namespace. Find
      the run for your Part 2.2 merge (the newest one, on your fork's *Actions* tab or with
      the command below) and wait for it to go green: there is no image to pull until
      `lab05-deploy.yml` has finished.
      ```bash
      gh run list --workflow lab05-deploy.yml --limit 3   # newest first; wait for ✓
      ```
   2. Open the run's summary page. It prints the image name it just built. Pull it
      and point test at it: the same two commands you used all through part 2, only
      the image name is longer:
      ```bash
      docker pull ghcr.io/<your-user>/cicd-lab-05-ignition:sha-<short>
      IGNITION_TEST_IMAGE=ghcr.io/<your-user>/cicd-lab-05-ignition:sha-<short> \
        docker compose up -d ignition-test
      ```
   3. Tag the latest `main` and push the tag (pull first, so the tag lands on the commit
      `lab05-deploy.yml` just built):
      ```bash
      git switch main && git pull
      git tag lab05-v0.1.0 && git push origin lab05-v0.1.0
      ```
      `lab05-release.yml` checks that `:test` was built from that commit, then re-tags it to
      `:v0.1.0` + `:production`: **no rebuild**. Deploy it to production (:8090) the same way,
      with `IGNITION_PRODUCTION_IMAGE`.
   4. Prove test and production run the **same image bytes**
      (`{{.Image}}` is the sha256 of the image a container runs):
      ```bash
      docker inspect -f '{{.Image}}' lab05-ignition-test
      docker inspect -f '{{.Image}}' lab05-ignition-production
      # identical sha256 → production runs the bytes the test gateway tested
      ```
   5. **Observe what's still manual:** you typed the image name twice. That last
      mile (a machine that owns the gateway, picking up the tag on its own) is
      what Lab 06 and Lab 07 automate.

2. **Go deeper on the image:** do layer forensics with `docker history --no-trunc`,
   or read the no-push `docker build` job that `lab05-ci.yml` runs on every PR:
   what would a broken Dockerfile look like in the PR's checks?
3. **A first taste of Lab 06:** put more kinds of cargo in the image, the way the
   production image from the teaching does:
   - **A module:** the SFC module ships with the base image but `services/modules.json`
     keeps it off. Set `com.inductiveautomation.sfc` to `"onStartup": "enabled"`, rebuild,
     deploy to test, and find it running under *Platform → Modules*: test runs whatever
     modules the `modules.json` in the image enables. The local gateway reads the same file through its bind mount: restart
     it (`docker compose restart ignition-local`, modules only load at boot) and SFC runs
     there too. It also writes SFC's default settings under
     `services/config/resources/core/com.inductiveautomation.sfc/`: commit them together
     with `modules.json`, so the image carries the same settings local runs with.
   - **A migrations folder:** create
     `db-migrations/0001_create_downtime_log.up.sql` with a simple
     `CREATE TABLE`, add a `COPY db-migrations/ /db-migrations/` layer, rebuild,
     and read the file back out of the image with `--entrypoint cat`. Nothing
     runs it yet: Lab 06 wires that up.
   - **An extra JAR:** download a plain Java library, e.g. commons-csv from Maven Central,
     and add a `COPY` layer that puts it on the gateway's classpath:
     ```bash
     mkdir -p jars && curl -fLo jars/commons-csv-1.14.1.jar \
       https://repo1.maven.org/maven2/org/apache/commons/commons-csv/1.14.1/commons-csv-1.14.1.jar
     ```
     ```dockerfile
     COPY --chown=2003:0 jars/ /usr/local/bin/ignition/lib/core/gateway/
     ```
     Rebuild and list `/usr/local/bin/ignition/lib/core/gateway/` with `--entrypoint ls`.
     Where in the layer order does it belong, and why?

## Debrief (10 min)

- File-based vs image-based, now that you've run both: which failure modes did you meet on each side, and what would you pick for your own plant?
- The rollback took one command. What made it that cheap? (Immutable tags: the previous version already exists as an artifact.)
- Each deploy was a fresh gateway. Which state at your plant could **not** survive that, and where would you move it (volume? external DB)?
- In production the image goes through a registry. What changes in the mechanics, and what stays exactly the same?
