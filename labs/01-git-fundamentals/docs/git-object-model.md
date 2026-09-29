# Git's object model — cheat sheet

Reference reading for the lab's object-model segment. Keep this open while you work through the You-do.

## The four object types

Everything in a Git repository is one of four object types, all stored in `.git/objects/`:

| Type | What it is | Points to |
|---|---|---|
| **blob** | The raw contents of a file. No filename, no permissions. | nothing |
| **tree** | A directory listing — names, permissions, and the blob/tree SHA for each entry | blobs and other trees |
| **commit** | A snapshot: pointer to one tree + parent commit(s) + author + message | one tree + zero-or-more parent commits |
| **tag** | A named, immutable reference to a commit (annotated tags only) | one commit |

At heart, `.git/objects` is a **key-value store**: the **key** is a hash of the content, the **value** is the content itself. `git cat-file -p <key>` prints the value back. Each object is therefore content-addressed: its SHA-1 (or SHA-256, in newer Git) is computed from its content, so two identical files anywhere in any repo will have the same blob SHA. That's how Git deduplicates storage.

## The relationships, visually

```
commit  ──tree──▶  tree  ──blob──▶  blob ("Hello, world!")
   │                  │
   │                  └──tree──▶  tree  ──blob──▶  blob (test code)
   │
   └──parent──▶  commit  ──tree──▶  ...
```

A commit is *one* snapshot. To see what changed between two commits, Git walks both trees and compares blob SHAs. That's all `git diff` is doing under the hood.

## The commands that show you the objects

| Command | What it does |
|---|---|
| `git cat-file -t <SHA>` | Tell me the *type* of this object (`commit`, `tree`, `blob`, `tag`) |
| `git cat-file -p <SHA>` | Pretty-print the contents |
| `git cat-file -s <SHA>` | Size in bytes |
| `git ls-tree <commit-or-tree>` | One-line tree contents |
| `git ls-tree -r --name-only HEAD` | Recursive list of every tracked file |
| `git log -S "needle"` | Find every commit that added or removed `needle` |
| `git log --follow -- <file>` | History of one file, even across renames |
| `git rev-parse HEAD` | Show the SHA that HEAD points to |
| `git rev-parse HEAD:path/to/file` | Show the blob SHA of `path/to/file` at HEAD |

## HEAD, refs, and the index

These are the three small pieces of state that turn the object store into a workable repository:

- **HEAD** is a pointer. Usually to a branch (`ref: refs/heads/main`); sometimes directly to a commit ("detached HEAD"). The thing it points to is *your current position*.
- **Refs** are named pointers to commits. `refs/heads/main` is a branch ref. `refs/tags/v1.0` is a tag ref. Branches and tags are *just* refs — text files in `.git/refs/` containing a SHA.
- **The index** (also called the staging area) is a snapshot of what your *next* commit will look like. `git add` updates the index. `git commit` turns the index into a new commit object.

When you understand that all three are just pointers/snapshots into the same object graph, commands like `git reset` stop being magic — they're just "move this ref to that SHA, and maybe sync the index/working tree along the way."

## Why this matters in practice

Three places this mental model pays off:

1. **Rebase conflicts.** Rebase rewrites commits by replaying their diffs onto a new base. When you understand that each commit is a snapshot tied to a tree, you understand why moving a commit can produce a conflict — you're trying to apply *this tree change* on top of *a different starting tree*.
2. **Recovery.** "I deleted my branch" doesn't mean the commits are gone. The commit objects are still in `.git/objects/`. `git reflog` shows you every HEAD movement from the last 90 days (Git's default). Find the SHA, `git checkout <SHA>`, you're back.
3. **`git mv` is a lie.** It's literally `mv + git add` + `git add` of the removal. The blob SHA is unchanged. Git infers renames by content similarity at *diff time*, not commit time.

If you've ever wondered why a file you "moved" shows up as one deletion and one addition in `git log`, this is why — Git doesn't track renames; it detects them.
