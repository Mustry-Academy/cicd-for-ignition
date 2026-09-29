# Lab 02 — Branching and Pull Requests

Day 1 of the [CI/CD for Ignition Masterclass](../../README.md).

> Compare branching strategies side by side, and learn to write a pull request a reviewer actually enjoys reading.

This is the second lab in the course. The subject of the exercises is a real (if
small) **Ignition project** — a Perspective HMI screen (the Oatmakers Site 04
oat-line overview, the client from Lab 01) and a couple of Python script libraries — running on a local gateway you
spin up yourself. You don't need prior Ignition experience: the gateway's
*administrative* complexity (config, modules, databases, deploys) is deliberately
**abstracted away**, and what you actually edit is approachable — a small Python
function, or a property on a view. The point of the lab is the **Git workflow**
around those project files: branching, pull requests, and review. The full Ignition
file-based deploy story arrives in [Lab 04](../04-ignition-file-based-deploy/).

## Prerequisites

- Work in **WSL2 (Windows), Linux, or macOS** — run all lab commands there, not in PowerShell or Git Bash (see the platform notes in your welcome package)
- Completed [Lab 01](../01-git-fundamentals/)
- Pass [`preflight`](../../preflight/)
- Docker (with the Compose V2 plugin) for the optional gateway — ~1.5 GB RAM is plenty for the single gateway

## Working model: fork and PR

This lab has you open real PRs, review your peers', and merge your own when
approved — so everyone needs merge rights on the repo they're PRing into. The clean
way to get that without handing a whole cohort write access to one repo: **work in
your own fork, and open PRs inside it.**

1. **Your course fork** (sets `origin` to your fork, `upstream` to the course repo).
   You fork and clone once for the whole course: skip the `gh repo fork` line if
   you already did that in Lab 01.
   ```bash
   mkdir -p ~/mustry-academy && cd ~/mustry-academy
   gh repo fork Mustry-Academy/cicd-for-ignition --clone             # once per course (fork + clone)
   cd cicd-for-ignition
   gh repo set-default --view                                        # where gh's PRs go: must print YOUR fork
   gh repo set-default <your-username>/cicd-for-ignition             # if not (course-setup.sh already sets it)
   cd labs/02-branching-and-prs
   ```
   > **WSL2 (Windows): keep the clone in your Linux home (`~/…`), never `/mnt/c/…`.**
   > On the Windows filesystem your Windows user, your WSL user and the gateway's
   > container user are three different identities, so file ownership breaks in ways
   > `chown` cannot fix and you end up reaching for `sudo` (which makes it worse).
   > `scripts/setup.sh` refuses to run from there. See [`docs/wsl-setup.md`](./docs/wsl-setup.md).
2. Branch and push to **your** fork (`git push -u origin <branch>`).
3. Open PRs **inside your fork**: base repo = your fork (the base *branch* varies
   per exercise step), compare = your branch. Watch out: GitHub's "Compare & pull
   request" banner defaults the base repo to the **upstream** course repo — switch
   it to your fork every time. `gh pr create` may default to the course repo too: check
   `gh repo set-default --view` from step 1 prints your fork.
4. **Invite your reviewer**: add a peer or one of the tutors as a collaborator on
   your fork (Settings → Collaborators → Add people), then request their review on
   each PR.
5. You own your fork, so you can merge your own PRs once they're approved.

## Quick start

Spin up your gateway (optional, but it makes the project tangible). Only one lab
stack runs at a time: stop the previous lab's first (`docker compose down` in that
lab's folder).

```bash
cp .env.example .env
scripts/setup.sh        # boots one Ignition gateway, waits for RUNNING, prints the URL + login
# open http://localhost:8088  → log in with the .env credentials
```

Before opening any PR, run the validator — the green/red signal this lab uses in
place of a test suite (gateway-free, runs in a second):

```bash
scripts/validate.sh     # every project file must be valid JSON / parse as Python
```

Stop the gateway when you're done:

```bash
scripts/teardown.sh             # stop (keeps the gateway's data volume)
scripts/teardown.sh --volumes   # stop and wipe gateway state for a fresh start
```

### Picking up your edits

A running gateway does **not** auto-detect changes to files under `projects/`. The
simplest way to load your edits is to reload the gateway — no API key needed:

```bash
docker compose restart      # reload the project from disk
```

If you'd rather hot-reload without a full restart, set up a one-time Ignition API
key (optional — instructions in `.env.example`) and trigger a project scan instead:

```bash
scripts/scan.sh                 # faster reload via the gateway's scan API
```

## Lab structure

The whole lab lives in one file, [`exercises/lab.md`](./exercises/lab.md): a single
**we-do / you-do** flow covering two linked topics —

- **Branching strategies** — Git Flow vs GitHub Flow vs trunk-based, and which fits your team
- **Pull requests** — scope, review, and merge hygiene

The you-do ties them together: you run the release-week scenario (a v2.0 feature plus
a P1 production fix) through **GitHub Flow** — the course's strategy — with PRs your
peers review, merged in release order and tagged. A stretch reruns it in Git Flow.

## Repo layout

```
labs/02-branching-and-prs/
├── README.md
├── docker-compose.yml            ← one Ignition gateway (named volume + bind-mounted projects/)
├── .env.example                  ← copy to .env before running
├── flint.config.json             ← Flint (VS Code) config: projects + local gateway
├── exercises/
│   └── lab.md                    ← the lab (Parts 1–3)
├── docs/                         ← reference reading
│   ├── branching-strategies.md
│   ├── pr-review-style.md
│   └── wsl-setup.md              ← Windows/WSL: read once before this lab
├── scripts/
│   ├── preflight.sh              ← WSL/permission checks setup.sh runs first
│   ├── setup.sh                  ← boot the gateway and wait for RUNNING
│   ├── scan.sh                   ← push project-file edits to the running gateway
│   ├── teardown.sh               ← stop the gateway (--volumes to wipe state)
│   └── validate.sh               ← the PR green/red check (valid JSON + parseable Python)
└── projects/                     ← the Ignition project (bind-mounted into the gateway)
    └── lab-project/
        ├── project.json
        ├── com.inductiveautomation.perspective/   ← the Perspective HMI dashboard + page config
        └── ignition/script-python/lab/            ← Python scripts (you edit display; util is a helper)
```

The PR template GitHub pre-fills on every PR lives at the repo root, in
[`.github/pull_request_template.md`](../../.github/pull_request_template.md): GitHub
only reads it from there. Open this lab folder in VS Code (`code .` from here), not
the repo root: `flint.config.json`'s paths are relative to the workspace folder.

## The Compose stack

A single Ignition 8.3 gateway. Two things to understand about how it's wired:

- **The gateway's own config and runtime state live in a named volume** (`ignition-data`) that the gateway generates itself on first boot. It never lands in the repo — which is exactly why you never see or touch gateway config in this lab. (That's Lab 04's subject.)
- **Only `./projects` is bind-mounted** from the repo into the gateway. So the project files you edit on your laptop *are* the project files the gateway runs.

```yaml
services:
  ignition:
    image: inductiveautomation/ignition:8.3.8
    ports: ["8088:8088"]
    volumes:
      - ignition-data:/usr/local/bin/ignition/data        # gateway-owned, self-generated, not in git
      - ./projects:/usr/local/bin/ignition/data/projects   # the one thing you edit

volumes:
  ignition-data:
```

> The gateway regenerates a `.resources/` blob store and other operational files inside `projects/` as it runs. Those are gateway-owned churn and are gitignored — if you ever see them in `git status`, your ignore rules are off.

> **No CI in this lab.** We deliberately ship no workflow for Lab 02 (the repo-root `.github/workflows/` holds the later labs' workflows, path-filtered so your Lab 02 PRs don't trigger them). `scripts/validate.sh` is something *you* run; Lab 03 turns it into a required status check no one can merge past. Having pre-built CI here would muddy that narrative.

## License

Apache 2.0 — see [`LICENSE`](./LICENSE).
