# CI/CD for Ignition

> Hands-on training in version control, GitHub Actions, and multi-gateway deployments for Ignition 8.3, by [Mustry Academy](https://mustrysolutions.com/).

This is the course repo. Everything you work on during the four days lives here: the preflight check, every lab, its exercises, slides and docs. You fork it once, clone your fork once, and work lab by lab in its own folder.

**Who this is for:** senior Ignition integrators, and the IT/engineering colleagues who work with them, who want to ship Ignition the way real software is shipped: Git, pull requests, CI pipelines and reproducible deployments.

**Prerequisite:** current Inductive University 8.3 Credential, or equivalent professional experience.

## Before Day 1 (at least 7 days ahead)

Work in **WSL2 (Windows), Linux or macOS**. On Windows, keep the clone in your Linux home (`~/…`), never on `/mnt/c/…`: the Docker labs break there.

1. **Fork and clone** the course repo:
   ```bash
   mkdir -p ~/mustry-academy && cd ~/mustry-academy
   gh repo fork Mustry-Academy/cicd-for-ignition --clone
   cd cicd-for-ignition
   ```
2. **Enable Actions on your fork.** Forks start with workflows switched off: open the *Actions* tab of your fork and click **"I understand my workflows, go ahead and enable them"**. There is no CLI for this button.
3. **Run the course setup:**
   ```bash
   ./course-setup.sh
   ```
   It runs the [preflight](./preflight/) checks (tools, Docker, course images), sets up this clone's git hooks, checks that `origin` is your fork and Actions are on, and prepares the `.env` files for Labs 04 and 06 (it asks once for the GitHub token their runner needs). Safe to re-run until everything is green.
4. **Paste `preflight/preflight-report.txt`** in the Discord `#preflight-help` channel so the TA can confirm you're ready.

## Labs

| Lab | Folder | Day |
|---|---|---|
| 01 | [Git fundamentals](./labs/01-git-fundamentals/) | 1 |
| 02 | [Branching and pull requests](./labs/02-branching-and-prs/) | 1 |
| 03 | [GitHub Actions](./labs/03-github-actions/) | 2 |
| 04 | [Ignition file-based deploy](./labs/04-ignition-file-based-deploy/) | 2 (afternoon) |
| 05 | [Ignition image-based deploy](./labs/05-ignition-image-based-deploy/) | 3 |
| 06 | [Secrets, database migrations, modules & JARs](./labs/06-secrets-db-and-modules/) | 4 (morning) |
| 07 | [Deployments in a multi-gateway architecture](./labs/07-multi-gateway-deploy/) | 4 (afternoon) |

Each day runs **09:00–17:15 CET**. Start every lab from its README.

**Lab 07 is the exception.** You don't work in your fork: the whole cohort contributes to one shared repo that deploys to a real production gateway. Your instructor sends you the link on Day 4; clone it next to this repo in `~/mustry-academy/`. The folder here is the template that repo is built from.

## Working in this repo

- **Open the lab folder, not the repo root,** in VS Code (`cd labs/04-… && code .`). The Flint extension and the lab scripts expect the lab folder as the workspace.
- **One lab stack at a time.** The Docker labs share the same ports (8088–8090, 5432) and container names. Before you start a lab, stop the previous one: `docker compose down` in that lab's folder.
- **Workflows live at the root.** GitHub only runs workflows from `.github/workflows/` at the top of the repo, so each lab's workflows sit there as `labNN-*.yml`, filtered to their own folder. A change in Lab 04 never triggers Lab 06's pipeline.
- **Tags carry the lab number.** Release tags are `labNN-vX.Y.Z` (e.g. `lab04-v1.0.0`), so a tag releases only its own lab.

## Repo layout

```
cicd-for-ignition/
├── README.md              ← you are here
├── course-setup.sh        ← run once before Day 1
├── preflight/             ← environment checks (course-setup.sh runs these)
├── labs/                  ← one folder per lab: README, exercises, slides, docs, code
├── .github/workflows/     ← every lab's pipelines, prefixed labNN-
├── scripts/               ← shared git hooks and helpers
└── welcome-package/       ← source of the welcome PDF you received
```

## Licence

Code: [Apache 2.0](./labs/01-git-fundamentals/LICENSE), see each lab's `LICENSE`. © 2026 Mustry Solutions BV.

## Contact

- Lead instructor: Jasper Mustry (jasper@mustrysolutions.com)
- General enquiries: academy@mustrysolutions.com
- Discord: cohort link in your welcome email
