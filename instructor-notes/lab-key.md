# Lab 01 — instructor answer key

> **Do not read this before you've attempted the You-do solo.** The whole point of Phase 1's spelunking is to build intuition, and the graph drawings in Phase 2 are the payoff — if you peek, you'll skip the learning and you won't notice the structural difference between FF and `--no-ff`.

## Pre-requisite: the seeded history

`sample-app/app.py` should have **four** commits in its history (`git log --oneline -- sample-app/app.py`), oldest → newest:

1. **initial commit** — `app.py` is born with `greet()` and an argv-driven `__main__`. *(author: Sam)*
2. **add shout functionality** — `greet()` gains the `shout` parameter / `--shout` flag. *(author: Sam)*
3. **add farewell functionality** — `farewell()` is added alongside `greet()`. *(author: Sam)*
4. **farewell: add a quick temporary hack** — a deliberately silly `# HACK … definitely safe to ship. -J` comment inside `farewell()`. **Authored by Jasper** — this is the bait for the `git blame` gag in Phase 1 steps 1–4.

SHAs differ per-build because Git timestamps are per-author/date, so the key works by **commit messages**, not literal SHAs. If you re-seed the repo from scratch, re-create the HACK commit with `git commit --author="Jasper Louage <jasper.louage@mustrysolutions.com>"`.

## Phase 1 — whodunnit + focused commit

### 1–4. Whodunnit? (the `git blame` gag)

```bash
git blame sample-app/app.py
# Inside farewell(), the "# HACK: …definitely safe to ship. -J" line shows:
#   <sha> (Jasper Louage <date> NN) # HACK: …
```

**Answer: the line is authored by Jasper** (the instructor). All the other lines are Sam's, so the contrast makes it obvious. This is purely for the laugh + to show that blame is *per line*, with author + commit + date. The follow-up `git log -p -L :farewell:sample-app/app.py` (step 4) shows the full line-history of the function, newest first: the HACK commit on top, then "add farewell functionality" where the function was born (blame = *who*, log = *why*). Lean into it: "blame isn't for finger-pointing, it's how you find the commit behind any line" — then reveal it's your own hack.

### 5–6. Make a focused commit

Expected diff in the new commit: exactly one hunk in `sample-app/README.md` adding a "lab participant" line.

```bash
git cat-file -p HEAD
# tree <TREE-SHA>
# parent <PARENT-SHA>
# author …
# committer …
#
# <commit message>
git cat-file -p <TREE-SHA>
# Should show sample-app/ entry pointing to a *changed* sub-tree.
git ls-tree HEAD sample-app/
# README.md blob SHA should differ from HEAD~1's README.md blob SHA.
# All other blob SHAs (app.py, requirements.txt, tests/) should be UNCHANGED.
```

Common mistake: students accidentally also save unrelated file changes (e.g., they ran `pytest` and a `.pytest_cache/` got pulled in). The `.gitignore` covers `.pytest_cache/`, but if they forced an add, you'll see additional blobs. Look for `git add .` in their shell history.

### 7. The gate

`scripts/verify-lab.sh` should print all-green here. It checks a clean tree, a "lab participant" line in `sample-app/README.md`, and that `HEAD` touched **only** `sample-app/README.md`. Students must run it **before** Phase 2's resets — once Phase 2 rewrites history, the "HEAD touched only README" invariant no longer holds.

## Phase 2 — workflows

### The seed state

`scripts/seed-messy-state.sh` should drop these three changes into the working tree:

1. **`sample-app/app.py`** — add a docstring to the `greet()` function.
2. **`sample-app/README.md`** — add a "Run me" section with the python command.
3. **`sample-app/tests/test_app.py`** — add a second test, `test_greet_handles_empty_string`.

Three files, three distinct logical changes. `git add -p` will offer each as a separate hunk.

### Part A — three clean commits

After `git add -p` and three commits, the expected log on `feature/greeting-tweaks` is:

```
* abc1234 (HEAD -> feature/greeting-tweaks) test: cover empty-string input
* def5678 docs: document how to run the sample app
* 9abcdef refactor(app): add docstring to greet()
* … BASE ancestry below this point
```

The exact commit ordering depends on the student. What matters is:

- **Three commits**, not one or two.
- Each commit touches **exactly one file**.
- Messages are descriptive (not `wip`, `update`, or `stuff`).

If a student lumps everything into a single commit, push them back to redo with `git reset HEAD~1 --soft` and try `add -p` again. The point of `-p` is staging discipline; one giant commit defeats the exercise.

### Part B — a real merge commit

The unrelated commit (step 5) must touch a file the seed **didn't** — the instructions say
`docs/why-version-control.md`, deliberately far away from both READMEs so nobody mixes it up with
the Phase 1 commit. If a student edits `sample-app/README.md` instead, the seed's "Run me" commit
appends to the same file end and Part C's rebase will hit a conflict they weren't meant to see yet
(that's Stretch 1's job).

**Expected graph after the merge (steps 6–7):** `main` has moved, so a plain `git merge` cannot
fast-forward — Git produces a merge commit:

```
*   merge commit on main
|\
| * test: cover empty-string input
| * docs: document how to run the sample app
| * refactor(app): add docstring to greet()
* | chore: unrelated note on main
|/
* (tag: BASE) <the Phase 1 focused commit>
```

**BASE is a real tag** (created with `git tag BASE` at the top of Phase 2), so it shows up as
`tag: BASE` in every decorated log — a quick way to spot a student who skipped the baseline step:
no `tag: BASE` decoration means their later `git reset --hard BASE` will fail with
"ambiguous argument 'BASE'".

**The two-parent check (step 7):** `git cat-file -p HEAD` on the merge commit prints **two `parent` lines** — one for the previous `main` tip, one for `feature/greeting-tweaks`. This is the concrete payoff of the teaching deck's three-way-merge slide ("a merge commit with two parents"). A fast-forward, by contrast, produces *no* new commit at all — so there's nothing with two parents to inspect. If a student sees only one parent, they fast-forwarded by accident (`main` hadn't actually moved — they skipped step 5).

**Wrap-up thread (the `--no-ff` question):** the assignment no longer does the merge-style
comparison, so raise it in the wrap-up instead: if `main` *hadn't* moved, a plain `merge` would
fast-forward (no merge commit), while `--no-ff` would still force one — preserving the "this was a
branch" signal. Demo it live if there's time: reset to `BASE`, branch, commit, merge each way.

> **Note on `--all` graphs:** the warm-up branch `we-do-greeting-polish` still exists, so its three
> commits show up in every `git log --all` from here on. That's expected — don't let students think
> they broke something.

### Part C — linear rebase

**Step 9 is the load-bearing step:** after `git reset --hard BASE`, students must put a **new**
commit on `main` (redo the README note). If they skip it, `main` equals the feature branch's fork
point and `git rebase main` prints **"Current branch feature/greeting-tweaks is up to date"** — a
silent no-op with no new SHAs. A student reporting that message skipped the note redo.

After Part C, `git log --graph --decorate --oneline` should show a **linear** history:

```
* (HEAD -> main, feature/greeting-tweaks) test: cover empty-string input
* docs: document how to run the sample app
* refactor(app): add docstring to greet()
* chore: unrelated note on main
* (tag: BASE) <the Phase 1 focused commit>
```

No merge commit. No diverging branch. `main` and `feature/greeting-tweaks` point to the same commit.

The feature commits will have **new SHAs** because rebase rewrites them. Students who don't notice this is a good moment to revisit the "commits are immutable" point from the We-do — `git rebase` doesn't *move* commits, it creates new ones and re-points the branch.

## Stretch keys

> All three are optional, only attempted if a room finishes early. In `lab.md` the **conflict**
> stretch is #1 (higher value for this lab), the **reconstruct-`git diff`** stretch is #2 (deeper
> dive), and **cherry-pick** is #3.

### 1. Conflict resolution

**The setup matters:** after Part C, `main` and `feature/greeting-tweaks` point at the same commit,
so a rebase would fast-forward and never conflict. Step 1's `git reset --hard HEAD~3` on `main`
re-creates the divergence (the three feature commits stay on the feature branch). A student who
skipped it will report "Successfully rebased" with no conflict — send them back to step 1.

Both branches then insert a different line just above `message =` inside `greet()`, so the conflict lands there. During the rebase, `HEAD` is `main` (the comment) and the incoming side is the feature commit (the docstring):

```
def greet(name: str, shout: bool = False) -> str:
<<<<<<< HEAD
    # CONFLICT BAIT — main and your feature branch both edit greet()
=======
    """Return a friendly greeting for `name`."""
>>>>>>> <hash> (refactor(app): add docstring to greet())
    message = f"Hello, {name}!"
```

Resolution: keep **both** lines (delete the three `<<<<<<<` / `=======` / `>>>>>>>` markers, leave the comment and the docstring). Save, `git add sample-app/app.py`, `git rebase --continue`. If a student gets stuck, `git rebase --abort` is a legitimate exit — better to bail and try again than to mash through and produce broken history.

### 2. Reconstructing `git diff` (deeper dive)

```bash
# Pick two adjacent commits, say HEAD and HEAD~1.
git ls-tree -r HEAD       > /tmp/tree-head.txt
git ls-tree -r HEAD~1     > /tmp/tree-prev.txt
diff /tmp/tree-prev.txt /tmp/tree-head.txt
# Lines that appear only in tree-head.txt → added or modified files
# Lines that appear only in tree-prev.txt → removed or modified files
# (matched on path; the SHA difference tells you the blob changed)

# For a changed file:
git cat-file -p <OLD-BLOB-SHA>  > /tmp/old.txt
git cat-file -p <NEW-BLOB-SHA>  > /tmp/new.txt
diff /tmp/old.txt /tmp/new.txt
# This output matches what `git diff HEAD~1 HEAD -- <path>` shows (minus the header).
```

Goal: students see that `git diff` is not a black box — it's a tree walk + blob comparison. The mental model from the We-do is now operational.

### 3. Cherry-pick one commit

```bash
git switch main && git reset --hard BASE
git log --oneline feature/greeting-tweaks   # student picks any of the feature SHAs
git cherry-pick <SHA>
git log --oneline -2
```

Expected observations:

- The commit lands on `main` as a **new commit with a different SHA** — same change, new identity
  (different parent and committer timestamp, so a different object).
- `feature/greeting-tweaks` is **untouched** — cherry-pick copies, it doesn't move.
- If the student picks the *second or third* feature commit, the pick still applies cleanly because
  the seed's three changes are in three different files — a nice aside: cherry-pick replays a
  **change (diff)**, not a snapshot.
- **Stretch 1 interaction:** if the student did Stretch 1 first, its rebase rewrote the feature
  branch — the docstring commit's diff now sits on top of the conflict-bait comment, so picking
  *that* commit onto `BASE` (which has no comment) **conflicts**. Expected, not broken: steer them
  to the docs or test commit for a clean pick, or let them resolve it the same way as Stretch 1 —
  it's a second, unplanned proof that cherry-pick replays a diff against whatever context it finds.

Tie it back to the object model: like rebase, cherry-pick manufactures new commit objects; the
original is still reachable from the source branch.

## Wrap-up & questions crib

Use these as conversational threads, not as questions to grade:

- **Object model in practice:** rebase conflicts, `git reflog` recovery, and "`git mv` is just rename + commit" all make sense once you see commits/trees/blobs. Ask where the model clicked for them during the solo.
- **Merge vs rebase:** rebase produces clean history but loses "this was a branch" signal; merge with `--no-ff` preserves the branch shape but adds noise. Most teams pick one as default. Many shops rebase feature branches and merge with `--no-ff` at PR time.
- **Aliases:** common ones — `lg` for `log --graph --decorate --oneline --all`, `st` for `status -sb`, `co` for `checkout`. Discourage `git unstage` aliases that wrap `reset HEAD --` until students understand the index.
- **Recovery from push-to-main:** the answer depends on whether anyone has pulled yet. If not, `git reset` + `git push --force-with-lease`. If yes, a **revert** is safer — the wrong commit stays in history, but a new commit undoes it. We talk about force-pushing nuance in Lab 02.
