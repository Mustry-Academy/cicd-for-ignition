# PR review style — the Mustry Academy take

**Optional deep-dive.** The lab teaches the essentials of reviewing inline in
[`exercises/lab.md`](../exercises/lab.md) — small/scoped PRs and three core
comment labels are all you need for the review work. This doc is the fuller toolkit for
when you want to go further. Two ideas: what makes a PR easy to review, and how to
leave feedback that actually helps.

## What makes a PR easy to review

A reviewable PR has four properties. In order of importance:

**1. Small.** Under 200 lines of diff, ideally under 50. The smaller a PR is, the better the review it gets — reviewers find more bugs in small PRs because they read them carefully. A 1,000-line PR gets rubber-stamped no matter how rigorous the reviewer thinks they are.

**2. One concern.** A PR does *one thing*. A bugfix is not a refactor. A rename is not a feature. A formatting pass is not a code change. If you find yourself writing "and" in the PR title, split the PR.

**3. Self-describing.** The PR description answers three questions before the reviewer has to ask:
- **What** does this change? (one sentence)
- **Why** are we doing it *now*? (the motivation, often a bug, ticket, or user request)
- **How** does a reviewer verify it? (the commands or steps to run)

**4. Tested.** Either: it includes a test that would have caught the original bug, or there's a written reason it can't be tested (and you've made the manual test plan explicit in "How to test").

Lab 02's [`pull_request_template.md`](../.github/pull_request_template.md) enforces three of the four by structure. Smallness is up to you.

## Conventional comments

A simple convention: prefix every review comment with one of seven labels. Each label signals severity, frames the tone, and lets the author scan the review by category.

| Label | Meaning | Author should respond by… |
|---|---|---|
| `praise:` | Noticing something genuinely good | Reading and feeling appreciated |
| `nitpick:` | Trivial preference, take it or leave it | Reacting `+1` or replying briefly |
| `suggestion:` | A specific change you propose, but not a blocker | Accepting, declining with reasoning, or discussing |
| `issue:` | Something that should change before merge | Fixing, or pushing back with reasoning |
| `question:` | You don't understand something | Answering |
| `thought:` | A musing for the future, not actionable now | Reading, optionally creating a TODO |
| `chore:` | A reminder of something procedural | Doing it (rebase, retitle, etc.) |

You can add a modifier after the label: `suggestion (non-blocking):`, `nitpick (style):`, `issue (security):`. Modifiers are optional but useful when reviewers care more about category than the prefix already conveys.

Full spec: [conventionalcomments.org](https://conventionalcomments.org/).

## Tone

Conventional comments help, but they don't make rude feedback polite.

**Better:**
- "issue: this swallows the exception; the caller can't tell if it failed. Can we re-raise or return a sentinel?"
- "suggestion: I think `is None` is more PEP8-compliant than `== None`."
- "question: I'm not following why we close the connection here but not on line 23. What's the difference?"

**Worse:**
- "this is wrong"
- "why didn't you use `is None`???"
- "?"

The rule: if you wouldn't say it in person, don't write it. Asynchronous communication amplifies tone — what feels neutral in your head reads as cold or sarcastic to a colleague.

## Choosing approve / request-changes / comment-only

GitHub gives you three review verdicts. Use them as follows:

- **Approve.** You'd be happy for this to merge as-is. Trivial nitpicks are fine in an approve.
- **Request changes.** There's at least one `issue:`-labeled comment. The author *must* address it before merging.
- **Comment-only.** You read the PR but are not voting. Useful when you have opinions but it's not your area, or when you're the second reviewer and someone else already approved.

A common mistake: marking "request changes" for nitpicks. This blocks the PR for no good reason — it adds friction without adding value. Reserve request-changes for things that are actually wrong.

## When the author disagrees

Code review is a *negotiation*. The author isn't obligated to accept every suggestion. The norm:

1. Reviewer leaves a comment.
2. Author either fixes it or explains why they didn't.
3. If they disagree, reviewer either: yields (closing the thread with `+1` to the author's reasoning) or escalates (asking a third opinion).

Endless back-and-forth on a single thread is a smell. If you can't agree in two rounds, pull in someone else or take it to a synchronous conversation.

## What to look for as a reviewer

A useful checklist, in priority order:

1. **Does it do what the PR says it does?** (Mismatch between description and diff is the most common review finding.)
2. **Does it break anything else?** (Look at the call sites of changed functions.)
3. **Is it tested?** (Or: is the manual test plan good?)
4. **Is it understandable to someone who comes back to it in 6 months?** (Naming, comments where the *why* isn't obvious, no dead code.)
5. **Style and convention.** (Lowest priority. Save for nitpicks.)

Style nitpicks should mostly be caught by automated linting — which is exactly what Lab 03 is about.
