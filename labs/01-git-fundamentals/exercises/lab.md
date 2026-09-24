# Lab 01 — Git Fundamentals

**Duration:** ~180 minutes (09:00 – 12:00)

* 09:00 – 09:30 — introduction (welcome to the series + logistics)
* 09:30 – 10:15 — Teaching: Introductions to git
* 10:15 – 10:45 — We-do
* 10:45 – 11:45 — You-do (breakout rooms)
* 11:45 – 12:00 — wrap-up & questions

This is the **first lab in the CI/CD series**, so we open with a short introduction to the
course as a whole before getting hands-on. After that it's one continuous lab. We deliberately blend Git's *object model* with the
*everyday workflow* so that the two reinforce each other: you'll watch `add -p` build the
index, watch a commit produce a fresh tree and blob, and come to see `rebase` as
"new commit objects, not moved ones." The object model isn't an abstract first hour — it's
the lens for every workflow move you make.

## Goal

You should leave this lab able to:

- Understanding the basic commands of git, `git init`, `git add`, `git commit`, `git push`, `git pull`, `git status`, `git branch`, `git switch` (and the older `git checkout`), `git merge`, `git cherry-pick`, `git blame`, `git tag`
- Understand what `.gitignore` does and why Git tracks everything by default
- Actually understand what git is doing under the hood, how are blobs linked to commits, how every commit is a snapshot
- Choose between **merge** (fast-forward vs `--no-ff`) and **rebase** deliberately, and explain the tradeoffs
- Recover from "oh no I committed to the wrong branch"

## Introduction — welcome to the series (30 min)

Because this is the first class, the instructor opens with the bigger picture before we touch Git.

1. **Welcome & introductions.** Quick round-the-room: name, role, and one thing you want out of this course. 
2. **What this course is about.** This is a **CI/CD course for Ignition**. That means we're going to go deep into git, CI/CD, but it will be applied to Ignition and made very practical for that setting. This is not a pure Git course or a pure CI/CD course, it's really meant to give you practical tools in your day-to-day work. 
3. **How the series fits together.** A rough map of where we're headed — 8 labs, from Git fundamentals to the capstone (Lab 08).
4. **Fork the repo.** Every lab repo gets forked to your own GitHub account first: Fork on GitHub → clone *your fork*. Working in your fork means you can commit, branch and push freely without colliding with anyone else.
5. **How the labs work.** Each lab follows the same rhythm: **Teaching**, **We-do** (instructor live-codes), **You-do** (breakout rooms), then a **debrief**. There are optional stretch challenges if you finish early. Notes you take in `NOTES.local.md` are gitignored and yours to keep. We have 8 labs in total, where the last one (the capstone) will be a bigger challenge for you to fulfill in breakout rooms, where we will be there to guide you. Each lab has its own git repo, so you will always have a fresh start, even if you were not able to complete the previous lab. 
6. **Breakout room rules** Sam and Jasper will float around breakout rooms to see who could use some help. We ask everyone to share their screen at the same time in the breakout rooms, which gives us a 'look over your shoulder' kind of class. 
7. **AI Agents** Of course, AI will probably be able to one-shot these labs, but we would challenge you to do this class as much as possible without it, so you actually get the fundamentals, and then you'll be able to steer AI much better when building this out for yourself.
8. **The Oatmakers story.** After the introduction slides, present [`slides/oatmakers-story.html`](../slides/oatmakers-story.html): one fictional client — Oatmakers, eight Ignition sites, zero CI/CD — whose troubles set the stage for *why* CI/CD is worth adding to an Ignition workflow. The whole series follows this story; each day the map heals a little more.


## Teaching: Introductions to git (45 min)

The instructor teaches the foundations from [`slides/teaching.html`](../slides/teaching.html).
This is the conceptual half — we *do* the moves in the We-do that follows.

### Setup (do this first)

```bash
git switch main
git status        # should be clean
chmod +x scripts/seed-messy-state.sh
```

You should see a `sample-app/` directory with several commits already in its history. Run
`git log --oneline` and confirm you see at least five commits, and that the seed script is
available.

### What is Git, and why it matters

Git is a **Version Control System (VCS)** — software that tracks and manages changes to files over
time. The de-facto standard: 95%+ market share, with a huge ecosystem of GUIs, hosting services and
tooling built on top.

- **What Git does for you:** track changes across many files, compare versions of a project,
  time-travel back to old versions, revert, collaborate and share changes, combine changes.
- Open with a war story — `FINAL_v2_actual_REAL.zip`, lost work, no audit trail. Anyone who's been
  in industry long enough has one.

Reference reading: [`docs/why-version-control.md`](../docs/why-version-control.md).

### Under the hood — the object model (animated slides)

The thread for the rest of the lab: *every workflow command is really a manipulation of commits,
trees, and blobs.* Keep [`docs/git-object-model.md`](../docs/git-object-model.md) open as a cheat
sheet.

- **Blobs — Git is a key-value store.** `.git/objects` stores file *contents*: the key is a hash of
  the content, and a blob has **no filename**. Identical content is stored once.
- **Trees — where filenames live.** A directory listing that points to blobs and sub-trees by hash.
- **Commits — snapshots, chained.** A commit points to a *single* tree (a **full snapshot**) and to
  its parent; unchanged blobs and sub-trees are reused, never re-stored.
- **Branches — movable pointers.** Commits are immutable; a branch is just a readable name that
  moves forward as you commit.
- **HEAD — where you are.** The pointer to your current branch; `git switch` moves it, and the next
  commit attaches wherever it points.

### The workflows, on the graph (animated slides)

- **Merge.** When `main` hasn't moved, merging is a **fast-forward** — the pointer slides up, no new
  commit. When history has **diverged**, Git does a **three-way merge** and records a **merge commit
  with two parents**. Same-line edits on both sides → a conflict you resolve by hand.
- **Rebase.** Re-applies your commits onto the new tip as **brand-new commits** (new SHAs). No merge
  commit — linear history.
- **Cherry-pick.** Copies a *single* commit's change onto your branch as a new commit; the source
  branch keeps its original.

### Remotes and tags

- **Remotes.** Git is **distributed** — every clone is a full copy of the history. A remote (usually
  `origin`) is just another repo you sync with: `clone` copies it down, `push` sends your commits up,
  `pull` brings theirs down.
- **Tags.** A ref that *doesn't* move — a permanent bookmark, which is how you mark a **release**.
  Lightweight (`git tag v1.2`) vs annotated (`git tag -a v1.2 -m "Release 1.2"` — use this for
  releases). Push them explicitly: `git push origin v1.2`. Tags name the exact commit you shipped;
  they'll drive real deploys in later labs.

### The basic command vocabulary

A one-line tour — now that you know what's underneath, the commands are just verbs for moving these
objects and pointers around:

- `git init` — turn a plain folder into a repo (creates `.git/`).
- `git clone` — copy a remote repo (and its full history) to your machine.
- `git status` — what's changed, what's staged, what's untracked. Run it constantly.
- `git add` — stage a change for the next commit (moves it into the **index**).
- `git commit` — record the staged snapshot as a new commit.
- `git branch` — list or create branches (cheap pointers to commits).
- `git checkout` / `git switch` — move `HEAD` to another branch or commit. (`switch` is the modern, safer spelling for branches.)
- `git merge` — combine another branch's work into yours.
- `git cherry-pick` — copy a single commit onto your current branch.
- `git tag` — pin a permanent name to a commit; how you mark a **release**.
- `git push` / `git pull` — send / receive commits to and from a remote. We **name** these now; we use them for real in later labs.

> **Note:** most students will drive Git from VS Code's Source Control panel, which wraps these
> commands in buttons. Teach the CLI so they understand what the buttons actually *do* — and
> reassure them the UI handles the everyday flow; the terminal is for when it doesn't.

### Inspecting & undoing — `git blame` and `git reset`

- **`git blame`** — annotates every line of a file with the commit, author and date that last
  touched it. Read-only and safe; answers "who do I ask about this line?". You'll use it in the
  You-do.
- **`git reset --hard`** — moves the current branch pointer **and** overwrites your working tree to
  match; uncommitted changes are **gone, with no undo**. Plain `reset` (`--mixed`) and `--soft`
  keep your edits. Unsure? `git stash` first — that's your safety net.

### `.gitignore` — telling Git what *not* to track

Git tracks **everything** by default. `.gitignore` is how you tell it what to leave alone — build
output, virtualenvs (`.venv`), `__pycache__`, `.pytest_cache/`, OS/editor junk, and local-only notes
like `NOTES.local.md`.

- Open this repo's own [`.gitignore`](../.gitignore). Notice `.pytest_cache/` is already listed —
  that's exactly why running `pytest` during the You-do won't pollute your focused commit.
- `git status` shows **untracked** files (Git sees them, you haven't added them) separately from
  **ignored** files (Git pretends they aren't there). Knowing the difference saves you from the
  classic "why did my commit include `.venv/`?" mistake.

## We-do (30 min)

The instructor live-codes, narrating the object graph at every step — now we *do* the moves the
Teaching block described.

**1. A commit is a tree (quick recap).** Walk the existing `sample-app/` history:

1. `git log --oneline` — note one commit's SHA, e.g. `a1b2c3d`.
2. `git cat-file -p a1b2c3d` — read the commit object out loud. Note the `tree` line and the `parent` line. *That SHA is the **key**; `cat-file` prints the **value** — this is the key-value store from the slide.*
3. `git cat-file -p <tree-SHA>` — read the tree object. It lists blobs and sub-trees by SHA — the **filename lives in the tree entry**, exactly like the tree slide.
4. `git cat-file -p <blob-SHA>` — see the raw file content. (Confirm: the blob has no filename of its own.)

**2. What a commit actually does.** Now make the graph move:

1. Edit one line of `sample-app/README.md`.
2. `git add sample-app/README.md` — the **index** now holds a new blob, staged but not committed. `git status` shows the staged change.
3. `git commit -m "docs: tweak intro"` — a **new commit object** is born, pointing at a **new tree**, whose `README.md` entry points at a **new blob**. `HEAD` (a **ref**) advances to it.
4. `git cat-file -p HEAD`, then its tree, then the `sample-app` sub-tree, then the README blob — confirm only the README blob SHA changed; `app.py`'s blob is byte-for-byte the same SHA as before. *This is the snapshot slide made real: the commit is a **full snapshot**, but the unchanged blob is **reused, not re-stored**.*

**3. Branching and rewriting are just pointer moves and new objects.**

1. `git switch -c demo/throwaway` — a branch is a *cheap, **movable** pointer* to a commit (the moving label from the branches slide). Nothing is copied.
2. `git rebase -i HEAD~3` — reorder, squash, reword. Show the commit SHAs **change**: rebase doesn't *move* commits, it **creates new commit objects** and re-points the branch. Tie it straight back to "commits are immutable; their SHA is their content."
3. **Merge — fast-forward.** When `main` hasn't moved, `git merge demo/throwaway` just slides the `main` pointer forward. No merge commit. Linear history.
4. **Merge — `--no-ff`.** Advance `main` with a separate commit, then `git merge --no-ff demo/throwaway`. Now there **is** a merge commit. Prove the slide: `git cat-file -p HEAD` and **count the `parent` lines — there are two**. That two-parent commit *is* the three-way merge from the deck. Display the shape with `git log --graph --decorate --oneline --all`.
5. **Oops-recovery.** "Oops, committed to main." Demo `git reset HEAD~1 --soft` — the ref moves back one commit but the change stays in the **index** — then `git switch -c feature/recovered && git commit`. Reinforce: `reset` moves a ref; your blobs didn't go anywhere.

## You-do (breakout rooms) (60 min)

Break into rooms. **Share your screen** so Sam and Jasper can float and look over your shoulder.
Open a scratch terminal and a scratch notebook (`NOTES.local.md` is gitignored).

We start with a short **guided warm-up together**, then you go solo through two phases on the same
clone. **Do Phase 1 first** — its gate (`scripts/verify-lab.sh`) checks that `HEAD` is your focused
commit, and Phase 2's merges and resets break that check, so it only passes before Phase 2.

### Warm-up (together) — get set up, trace a commit, then stage by hunk

**Part 0 — your fork, on your machine, in VS Code (2 min).** Most of you did this before the
session — then only steps 3–4 apply. The point: everyone in the room works from the same place.

1. Make **one parent folder** for the whole series — all 8 lab repos will live side by side in it:
   `mkdir -p ~/mustry-academy && cd ~/mustry-academy`.
2. Fork + clone in one go: `gh repo fork mustry-academy/cicd-lab-01-git-fundamentals --clone`
   (if you already forked, it just clones your fork). Prefer the website? Press **Fork** on
   github.com — but you still need to clone your fork afterwards:
   `git clone git@github.com:<your-username>/cicd-lab-01-git-fundamentals.git`.
   Then `cd cicd-lab-01-git-fundamentals`.
3. Check the remote: `git remote -v` must show **your username**, not `mustry-academy` — your fork
   is where you can commit, branch and push freely.
4. From inside the repo, open VS Code with `code .` and work from its integrated terminal
   (`` Ctrl+` ``) from here on.

> **WSL2:** clone into your Linux home (`~/…`), never `/mnt/c/…` — Git is far slower across the
> Windows boundary and line endings get messy. `code .` from WSL automatically opens a window
> connected to WSL.

**Part 1 — trace a commit through the object graph.**

1. Make a small change to `sample-app/README.md` — add a single sentence.
2. `git add sample-app/README.md && git commit -m "docs: expand sample-app intro"`.
3. `git cat-file -p HEAD` — read it out loud. Note the `tree` SHA and the `parent` SHA.
4. `git cat-file -p <tree-SHA>` — this is the **root** tree, so the `README.md` entry you see here is the *repo's own* README, not the one you edited. Find the `sample-app` **sub-tree** entry instead, and note its SHA.
5. `git cat-file -p <sample-app-tree-SHA>` — *this* tree lists your `README.md`. Note its blob SHA.
6. `git cat-file -p <blob-SHA>` — confirm it matches your new file content.
7. `git ls-tree HEAD sample-app/` — the same walk in one command. The `README.md` blob SHA should match the one you just traced by hand.

**Part 2 — stage by hunk.** Reset back to a clean tree first: `git reset --hard HEAD~1` (this drops the practice commit above — that's fine, we're about to do it properly).

1. `git switch -c we-do-greeting-polish`.
2. `scripts/seed-messy-state.sh` — confirm with `git status` that you have a known dirty tree across `sample-app/`.
3. `git add -p` — stage **one** logical change, commit it. Repeat twice more, so you have three small commits. After each commit, glance at `git ls-tree -r HEAD sample-app/` and notice which blob SHA changed.
4. `git log --graph --decorate --oneline -5` — confirm your three commits sit on top of `main`.

> **Hint:** when `add -p` asks "Stage this hunk?", `y`/`n` is yes/no, `s` splits the hunk, `e` lets you hand-edit, `q` quits.

### Solo

Now work the two phases on your own. **Do Phase 1 first** — its gate (`scripts/verify-lab.sh`)
checks that `HEAD` is your focused commit, and Phase 2's merges and resets break that check.

### Phase 1 — whodunnit, then a focused commit

The warm-up left you on a scratch branch — first return to a clean `main`:

```bash
git switch main
```

Jot each answer in `NOTES.local.md` as you go.

**Whodunnit? (1–4)**

1. Open `sample-app/app.py` and find the suspicious line inside `farewell()` — the one promising it's *"definitely safe to ship."*
2. Run `git blame sample-app/app.py`. Every line shows its **commit · author · date**.
3. **Who wrote that line?** Read the author off the blame output. Anyone you recognise…?
4. Read the full story of those lines: `git log -p -L :farewell:sample-app/app.py`. Blame finds the *who*, log finds the *why* — together they're how you reconstruct the reasoning behind any line.

**Focused commit + gate (5–7)**

5. **Make a focused commit.** Add a line to `sample-app/README.md` that contains the **literal words "lab participant"** plus your name, e.g. `Lab participant: Ada Lovelace` — the Phase 1 gate script greps for those exact words. Commit it with a clear message.
6. Prove that **only the `README.md` blob changed**: compare `git ls-tree HEAD~1 sample-app/` with `git ls-tree HEAD sample-app/` — the `README.md` blob SHA differs, and every other entry (the `app.py` blob, the `tests/` tree) is identical.
7. **The gate.** Run `scripts/verify-lab.sh` — it should print all-green ✅. Run this **now**, before Phase 2: Phase 2 rewrites history, and the "HEAD touched only README" check no longer holds afterwards.

### Phase 2 — branch, merge, and rebase

Tag your baseline now — `main` already includes your Phase 1 commit, and you'll reset
back here a few times. A tag stays put while `main` moves, so `git reset --hard BASE`
always brings you back to this exact commit:

```bash
git switch main
git tag BASE    # a name that stays put while main moves
```

**Part A — three clean commits.**

1. `git switch -c feature/greeting-tweaks` from `main`.
2. Run `scripts/seed-messy-state.sh`. Confirm `git status` shows three changed files.
3. Use `git add -p` to produce **three separate commits**, each containing **one** of the three changes. Write a sensible message for each — imagine the reviewer needs to skim them in 30 seconds. (Lumped everything into one commit? Redo with `git reset HEAD~1 --soft` and try again.)

**Part B — a real merge commit.**

4. From Part A, `feature/greeting-tweaks` is **three commits ahead**; `main` still sits at your Phase 1 commit.
5. Put one small **unrelated** commit directly on `main` — append a line to `docs/why-version-control.md` (a file neither Phase 1 nor the seed touches), then `git commit -am "chore: unrelated note on main"`. Now the branches have **diverged**, so a fast-forward is impossible.
6. `git merge feature/greeting-tweaks` — Git can't fast-forward, so it records a **merge commit**.
7. `git cat-file -p HEAD` and **count the `parent` lines: two** — your own three-way merge commit from the slide. `git log --graph --decorate --oneline --all` shows the diamond where the branches rejoin.
8. **Sketch the graph in `NOTES.local.md` and keep it** — in Part C you'll fold in the same feature work with a *linear* history instead.

**Part C — linear rebase.**

9. Reset once more — you're still on `main` from Part B: `git reset --hard BASE` — this drops Part B's merge **and** its note commit. Then **redo the note commit** (append another line to `docs/why-version-control.md`, `git commit -am "chore: unrelated note on main"`) so `main` is ahead of the feature branch's fork point — without it, the rebase has nothing to do.
10. `git switch feature/greeting-tweaks && git rebase main`. The three feature commits should now sit on top of the new `main` tip, with no merge commit. (Notice the feature commits got **new SHAs** — rebase rewrote them.)
11. `git switch main && git merge feature/greeting-tweaks` — this *will* fast-forward. The history is linear.
12. Compare your final `git log --graph --decorate --oneline --all` to the reference walk-through in [`instructor-notes/lab-key.md`](../instructor-notes/lab-key.md). Don't peek before you've finished Part C.

## Stretch challenges `[OPTIONAL]`

Only if you finish the two phases early. The first is the higher-value one for this lab; the second
is a deeper object-model dive for the curious; the third adds one more everyday tool to your belt.

**1. Rebase through a conflict.** After Part C, `main` and `feature/greeting-tweaks` point at the
**same commit** — a rebase would do nothing. Diverge them again first, then make `main` collide
with the feature's docstring commit. Same-region edits on both branches are what *forces* a conflict:

```bash
# 1 — pull main back behind the feature branch
git switch main
git reset --hard HEAD~3     # the 3 feature commits leave main but stay on feature/greeting-tweaks

# 2 — edit the same spot the feature's docstring commit touches
#     (the python block below does it for you — or just make the edit by hand)
python3 - <<'PY'
from pathlib import Path
p = Path("sample-app/app.py")
t = p.read_text()
t = t.replace(
    '    message = f"Hello, {name}!"',
    '    # CONFLICT BAIT — main and your feature branch both edit greet()\n'
    '    message = f"Hello, {name}!"',
)
p.write_text(t)
PY
git commit -am "main: add a comment inside greet()"
```

Then `git switch feature/greeting-tweaks && git rebase main` — the feature commit that added a docstring to `greet()` touches the same spot, so Git halts with a conflict on that commit. Open `sample-app/app.py`, resolve (keep both the comment and the docstring), `git add sample-app/app.py`, then `git rebase --continue`. Confirm linear history with `git log --graph --decorate --oneline --all`. If you'd rather bail, `git rebase --abort` is also a valid exit.

**2. Diff without `git diff` (deeper dive).** Pick two adjacent commits in the seeded history. Using only `git cat-file` and `git ls-tree`, determine: which files exist in commit B but not A? For files in both, which blob SHAs differ? For the changed blobs, print both and identify the changed line(s) by eye. You're reconstructing what `git diff` does internally — a tree walk plus a blob comparison. Confirm with `git diff <A> <B>`.

**3. Cherry-pick one commit.** Grab a **single** commit from a branch without merging the whole thing — and watch it land as a **brand-new commit**. (Did Stretch 1 first? Pick the **docs** or **test** commit: Stretch 1's rebase rewrote the docstring commit so its diff now expects the conflict-bait comment, and picking it onto `BASE` would conflict again.)

```bash
git switch main && git reset --hard BASE    # main is behind your feature work again
git log --oneline feature/greeting-tweaks   # pick one commit's SHA

git cherry-pick <SHA>        # replays just that change onto main as a new commit
git log --oneline -2         # same change — NEW SHA

# other forms — pick what you need:
git cherry-pick <A> <B>      # a hand-picked few
git cherry-pick <A>~3..<A>   # a contiguous range
```

`cherry-pick` doesn't *move* a commit — it **replays the change as a new commit** on your current branch; `feature/greeting-tweaks` keeps its original. This is how you grab a single fix without merging a whole branch.

## Wrap-up & questions (15 min)

- Which of the "why VC matters" reasons resonated most with your day-to-day work?
- When does the object-model mental model *actually* matter in real life? (Hint: rebase conflicts, recovery with `git reflog`, understanding why `git mv` is just rename + commit.)
- One thing that surprised you about how Git stores files.
- Where would your team prefer **merge** over **rebase**, and why? Are there situations where the opposite is true?
- If a teammate committed straight to `main` and pushed it: what do they do *now*?
- Which commands do you want to alias? (e.g., `git lg` for `log --graph --decorate --oneline --all`)
