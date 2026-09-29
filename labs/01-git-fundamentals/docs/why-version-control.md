# Why version control matters

Reference reading for the lab's "Why version control matters" segment. If you missed it in class or want to re-read after the session, this is the backstop.

## The pre-VC world

If you've worked in any engineering team long enough, you've seen at least one of these:

- A folder called `Backups/` with timestamped zip files. `project_2024-03-15_FINAL.zip`. `project_2024-03-15_FINAL_v2.zip`. `project_2024-03-16_actual_final.zip`.
- A shared network drive where two people overwrite each other's work in the same afternoon.
- A senior engineer who is the *only* person who knows which copy of a file is "the right one."
- A rollback strategy that consists of "restore from last night's tape backup."

These aren't hypothetical. They're how most software was written until the early 2000s, and how a lot of industrial automation work is *still* written today.

## What a Version Control System (VCS) gives you

A version control system gives you four things that are hard to live without once you've used them:

**1. History.** Every change is recorded with author, timestamp, and a message. You can answer "who changed this line, when, and why" in seconds.

**2. Blame.** Not the punitive kind — `git blame` literally shows you the commit that last touched each line. It's how you reconstruct the reasoning behind code you didn't write.

**3. Branching.** Multiple people can work on different things at the same time, in isolation, without stepping on each other's files. Merging brings the work back together when it's ready.

**4. Safe undo.** You can always get back to a known good state. Every commit is a checkpoint. Even "I just deleted everything" is recoverable as long as the commit existed.

## Centralized vs distributed

Older VCSes (CVS, Subversion, Perforce, TFS) are *centralized*: there's one server, every commit goes to it, and if the server is down, nobody can commit.

Git is *distributed*: every clone is a full copy of the entire repository, including all history. You can commit, branch, and inspect history while completely offline. The "central" server (GitHub, GitLab, Bitbucket) is just a convention — one clone that everyone agrees to push to and pull from.

The distributed model is why GitHub-style workflows exist. You fork a repo (take your own copy), make changes, and propose them back via a pull request. That whole workflow is impossible in a centralized VCS.

## What about Ignition projects / configuration?

Ignition projects and configuration are *just files*. Vendor docs sometimes hint that "you don't need source control because Ignition has gateway backups." That's wrong in three ways:

- Gateway backups are blob snapshots — no per-change history, no per-file blame.
- Multiple engineers can't work on the same project in parallel without overwriting each other.
- There's no review step before a change goes live.

Putting your Ignition projects and configuration in Git solves all three problems and is the *foundation* for everything in this masterclass. We'll start versioning real Ignition projects later in the series. For Day 1, we use a tiny Python app so the Git mechanics aren't tangled up with Ignition file-format quirks.

## Further reading

- [Pro Git book](https://git-scm.com/book/en/v2) — free, comprehensive, the canonical reference
- *Git from the Bottom Up* by John Wiegley — the best treatment of Git's object model in long-form
