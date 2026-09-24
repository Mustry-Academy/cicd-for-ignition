# Lab 02: Branching and Pull Requests

One **we-do / you-do** covering two linked topics:
how a team *branches*, and how changes flow through *pull requests*. They're one
story. A branching strategy is the plan; a pull request is where the plan meets
reality, where your branch naming, your review habits, and your merge-style rules
actually get used. So you'll learn both, then live them: you'll run the release-week
hotfix scenario through GitHub Flow on a real Ignition project, end to end.

## What you're working on

The subject of this lab is a small but **real Ignition project**
(`projects/lab-project/`): a Perspective HMI screen (the Oatmakers Site 04
oat-line overview, the client from Lab 01) and two Python script libraries. You don't need prior Ignition experience: the
gateway's admin complexity is abstracted away, and what you edit is approachable (a
small Python function, or a new view). The lab is about the **Git workflow** around
those files: how you branch, how you open and review a PR, how you merge. Gateway
config, modules, and deploys are deliberately out of scope; they arrive in Lab 04.

## Setup (optional but recommended)

You can do every exercise from the files alone. But spinning up the gateway once
makes the project tangible, and lets you see your new v2.0 view go live:

```bash
cp .env.example .env
scripts/setup.sh          # boots one Ignition gateway, waits for RUNNING
# open http://localhost:8088  → log in with the .env credentials
```

Before opening any PR, run the validator. It's the green/red signal this lab uses
in place of a test suite:

```bash
scripts/validate.sh       # checks every project file is valid JSON / parses as Python
```

## Goal

By the end of this lab you should be able to:

- Describe **Git Flow**, **GitHub Flow**, and **trunk-based development**, and pick one that fits a team
- Run a **GitHub Flow release week** end to end: a feature and a P1 fix through PRs into `main`, released in the right order with version tags — and know when a team needs more (Git Flow's double-merge, in the stretch)
- Open a PR a reviewer enjoys reading: small, scoped, with a clear what / why / how-to-test
- Review someone else's PR with feedback that helps, and choose between approve, request-changes, and comment-only
- Merge cleanly and in the right order when approved

Read-ahead: [`docs/branching-strategies.md`](../docs/branching-strategies.md) covers the three strategies, with diagrams. Optional deep-dive on review craft: [`docs/pr-review-style.md`](../docs/pr-review-style.md).

---

## We-do

### Part A: from strategy to pull request

A branching strategy only comes to life through pull requests, so here is what a
good one looks like. Two PRs side by side on the projector:

| Bad PR | Good PR |
|---|---|
| Title: "update stuff" | Title: "fix(display): handle null readings without crashing" |
| 800-line diff across 12 files | 6-line diff in one file |
| No description | Clear What / Why / How to test |
| Mixes a rename, a bugfix, and a feature | One concern only |
| Leaves `validate.sh` red | `validate.sh` green |

The good column is the whole lesson. A PR is easy to review when it's **small**,
does **one thing**, is **self-describing** (What / Why / How to test), and shows
**how it was verified**. If you catch yourself writing "and" in the title, split
the PR.

### Part B: leaving review feedback

You don't need a formal system, just prefix each comment with what kind it is, so
the author knows how to react. Three labels cover almost everything:

- `praise:` something genuinely good. "praise: nicely focused diff, easy to review."
- `suggestion:` a specific, optional improvement. "suggestion: collapse these two ifs into one."
- `issue:` something that should change before merge. "issue: this still throws on a null reading; `format_reading(None, '°C')` errors instead of showing a placeholder."

That's enough to review well today. If you want the fuller toolkit (more labels,
tone, and handling disagreement) it's in the optional
[`docs/pr-review-style.md`](../docs/pr-review-style.md).

---

## You do

You'll live the release-week scenario from the teaching deck, for real, on your own
fork. Ship a v2.0 feature, get ambushed by a P1 bug in production, and thread both
through **GitHub Flow** — the course's strategy — exactly the way Chapter 1 drew it.
Then your peers review your PRs and you merge in release order.

Do the whole thing in your breakout room, sharing your screen. Open PRs early, and
invite your reviewer early: add a peer from your room or one of the tutors as a
**collaborator on your fork** (Settings → Collaborators → Add people), then request
their review on each PR. The review step needs a peer's PR to exist, and merging
needs a peer to have reviewed yours.

> Careful when opening PRs on a fork: GitHub's "Compare & pull request" banner
> defaults the **base repo** to the upstream course repo — switch it to **your
> fork** every time. `gh pr create` won't guess: it errors with "no default remote
> repository has been set" until you run
> `gh repo set-default <your-username>/cicd-lab-02-branching-and-prs` once (part of
> setup) and pick your fork.

### 1. Discuss: which strategy fits your team? (breakout room)

Talk it through out loud, no writing. Each person sketches their own team or
project (release cadence, regulatory constraints, team size, how often production
ships), and the room argues which of Git Flow, GitHub Flow, or trunk-based fits
**their** reality, and why. Disagreement is the point.

You'll run step 2 in **GitHub Flow** regardless — it's the course's strategy.
Knowing which one you'd actually pick is what makes feeling the difference land
in the stretch.

> Never worked on a multi-engineer team? Argue it for an Ignition team you've
> consulted with, or use the scenario in `docs/branching-strategies.md` as a stand-in.

### 2. Run the release-week scenario in GitHub Flow

`v1.2` is live in production. You start the v2.0 feature, and mid-work a P1 bug in
production ambushes you. You thread both through GitHub Flow.

**Step 1: set the GitHub Flow stage.** One long-lived branch — `main` — and a tag
marking what's in production. In GitHub Flow, tags carry the release history. Tag
what's live as `v1.2` on `main` and push the tag.

```bash
git switch main
git tag v1.2
git push origin v1.2      # "production" is v1.2
```

Mental model: `main` = the one shared line of development, `v1.2` = the exact
commit customers are running, releasing = merging to `main` and tagging. Every
branch you cut next is short-lived: off `main`, back to `main` through a PR.

> **Two commands graduate from "named" to "used" today.** `git tag v1.2` pins a
> permanent, human-readable name to the exact commit you're on; unlike a branch, a
> tag never moves — that's what makes it a release marker. `git push` uploads your
> local commits and refs to a remote (`origin` = your fork on GitHub; this morning
> everything stayed local). Two habits that trip people up: tags don't ride along
> with a normal push, so `git push origin v1.2` sends one explicitly — and a *new*
> branch needs `git push -u origin <branch>` once, where `-u` links it to your
> fork so every later push is just `git push`.

**Step 2: ship the v2.0 feature (the silo detail view).** Oatmakers' v2.0 scope
starts with a **silo detail view** — that's your feature. Branch off `main` — in
GitHub Flow every branch starts at `main` and returns to it through a PR:
`feature/v2-silo-detail`. The easiest path to the view itself:
copy the `overview` resource folder to `silo-detail` under `views/pages/`, edit
its `view.json` title, and register the `/silo-detail` page in
`page-config/config.json` so it's reachable. Run `scripts/validate.sh` (green),
commit with a
[Conventional Commits](https://www.conventionalcommits.org/) message, push, and open
a PR with **base = `main`**. Request your reviewer on it, and **leave it
open**: the ambush comes before you merge.

> Gateway up? `scripts/scan.sh` (or `docker compose restart`), then open the project.
> Your new page is there. That's the "it goes live" moment.

**Step 3: the P1 ambush, fixed the GitHub Flow way.** Your feature is still open when
a customer hits the null-reading crash in v1.2, live. It can't wait for v2.0.

1. Branch the fix off `main`: `fix/null-reading`. Because your
   feature PR is still **open**, `main` *is* v1.2 — the fix carries no v2.0 work.
2. The bug: `lab.display.format_reading()` in
   [`projects/lab-project/ignition/script-python/lab/display/code.py`](../projects/lab-project/ignition/script-python/lab/display/code.py)
   does `"%.1f" % None` on a null reading (a tag not yet read, or a comms loss) and
   throws, so the label shows an error instead of a value. Fix it: return a clean
   placeholder like `"-- °C"` for `None` (and other bad input), while keeping the
   normal numeric formatting. Remember `0` is a valid reading and must still format as
   `"0.0 °C"`. Run `scripts/validate.sh` (green).
3. **One PR into `main`.** That's the whole GitHub Flow ceremony: no `develop`, no
   double-merge. **Don't merge yet**: your peers review first, and the merging
   (plus the `v1.2.1` tag) happens in release order in step 3.
4. That's **two PRs open** (feature → `main`, fix → `main`): your reviewer
   requested on each. **Merge order is the lesson now**: the fix must land (and
   `v1.2.1` be tagged) *before* the feature merges — in GitHub Flow, merging is
   releasing.

```bash
# the fix branches off main — which IS v1.2, because the feature hasn't merged yet
git switch main
git switch -c fix/null-reading
# fix format_reading(), then:
scripts/validate.sh
git commit -am "fix(display): placeholder for null readings"
git push -u origin fix/null-reading
# ONE PR: fix -> main   (reviewed, merged first, then tagged v1.2.1 — step 3)
```

> The whole lesson: merging is releasing. Whatever is on `main` when you tag
> `v1.2.1` ships in v1.2.1 — merge the feature first and your "patch" quietly
> ships half of v2.0. Order is the one ceremony GitHub Flow kept.

### 3. Review a peer's PR, then merge yours

You each have a fix PR and a feature PR open. Pair up in your room so each PR gets
one reviewer — the collaborator invites from step 2 decide who reviews whom.

1. Open the PR you were asked to review (it's in your GitHub notifications). The
   **fix** is the richest to review.
2. **Read it slowly**, at least 5 minutes before writing anything. For the fix:
   - Do valid readings still format? `format_reading(162.0, "°C")` must return
     `"162.0 °C"`, and `format_reading(0, "°C")` must return `"0.0 °C"` (zero is a
     valid reading, not "missing").
   - GitHub Flow check: is the fix **just the fix** (no v2.0 work riding along),
     and is it set to merge **before** the feature? Merging is releasing.
   - Did they run `validate.sh`? Is the "How to test" something you could follow?
   For the feature PR: is the JSON well-formed, the page registered, the change scoped?
3. Leave a few genuinely helpful comments: at minimum a `praise:` and a `suggestion:`,
   plus an `issue:` if something is actually wrong. Quality over quantity, no quota.
4. Submit the review: **Request changes** if you left at least one `issue:`,
   **Approve** otherwise.

> Watch your tone. Conventional comments help, but they're not magic. If you
> wouldn't say it in person, don't write it in the PR.

Then respond and merge, in release order:

1. On your PRs, react to every comment (`+1` for praise, reply to questions, push a
   fix-up commit for what you accept, reply with reasoning for what you decline).
   Additive commits, no force-push during review. Re-request review when ready.
2. Merge the **fix PR first** (production is on fire), then tag `v1.2.1` on
   `main` — in GitHub Flow, the tag *is* the release:

   ```bash
   git switch main && git pull
   git tag v1.2.1 && git push origin v1.2.1
   ```

   Delete the fix branch once it's merged (GitHub offers a button; take it).
3. Now finish the feature: pull the fix down into your feature branch
   (`git switch feature/...` then `git merge main`), push, then merge the
   feature PR into `main` and delete the feature branch (GitHub offers a
   button; take it).

---

## Stretch challenges `[OPTIONAL]`

- **Now do it in Git Flow.** Same scenario, the heavyweight strategy — feel what
  the ceremony buys (support for more than one live version) and what it costs.
  First rewind your fork — after the scenario, `main` already has both changes:

  ```bash
  git switch main
  git reset --hard v1.2
  git push --force origin main       # your throwaway fork: force-push is fine here
  # GitHub's delete button only removed the remote branches; clear the local ones too:
  git branch -D feature/v2-silo-detail fix/null-reading
  # and un-release the patch, so the stretch can re-tag it:
  git tag -d v1.2.1 && git push origin --delete v1.2.1
  ```

  Then build the Git Flow world: a long-lived `develop` next to `main`
  (`git switch -c develop && git push -u origin develop`). Rerun the two changes
  Git Flow's way: the v2.0 view on `feature/*` **off `develop`** → PR into
  `develop`; the null-reading fix on `hotfix/*` **off `main`** → **two PRs**, into
  `main` (tag `v1.2.1`) **and** into `develop`. Merge the hotfix PRs first (both,
  *then* delete the branch — deleting it between the two merges auto-closes the
  still-open second PR), pull the hotfix into the feature (`git merge develop`),
  then merge the feature. Notice the difference: the hotfix merges **twice** — skip
  the `develop` merge and v2.0 regresses the fix next release. In the main scenario
  `v1.2` lived in a tag; here a whole branch structure guards it. GitHub Flow
  answered release week with one merge and a tag; Git Flow's double-merge is what
  it costs to support *old* versions properly. You now know both from the inside.
- **Branch protection.** On a repo you own, require PR reviews before merging
  (1 approval), dismiss stale reviews on new commits, and restrict direct pushes to
  `main` (no one, including admins). Screenshot the settings and share it with a
  one-line description of what you protected against. We don't require "passing CI"
  here because Lab 02 ships no CI: `validate.sh` is something *you* run, and Lab 03
  turns it into a required status check.

## Debrief

- Where does `v1.2` live in GitHub Flow — and when do tags stop being enough? (Stretch-doers: did the double-merge feel worth it? When does Git Flow's ceremony earn its keep, and when is it just merge work?)
- Which of the three branching strategies surprised you? Which would you adopt tomorrow if it were up to you?
- One thing you saw in someone else's PR that you'll steal for your own work? One habit you want to drop?
- When does a `request-changes` review do more harm than good?
- For your Ignition projects specifically: what's the smallest change you could meaningfully PR? You just did one: a single script function, a single new view. (The smaller the unit, the easier review becomes. Whole-gateway-backup PRs are unreviewable, exactly the problem Lab 04 onward tackles.)
