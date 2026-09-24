# Lab 02: instructor answer key

> **Do not read this before you've attempted the You-do.** The point of this lab is
> the *process*: running the GitHub Flow release-week scenario correctly, and
> reviewing well, not getting the "right" strategy or the "right" comments.

The lab is one we-do / you-do flow covering two topics. The You-do is a single
scenario: discuss a strategy (breakout room), then run the release-week feature + P1
fix through GitHub Flow, review peers' PRs, and merge in release order.
Git Flow's double-merge is the first stretch.
This key is grouped by topic; see [`exercises/lab.md`](../exercises/lab.md) for the flow.

---

# Branching strategies

## What "good" looks like for the breakout-room discussion

Part 1 is a *discussion*, not a written doc. Drop into rooms and listen for whether
each person can name a strategy that fits their described reality, and *why*. There's
no single correct strategy; use this table to sanity-check their argument:

| If they describe… | Then strategy should usually be… |
|---|---|
| Single SaaS, 2 to 10 engineers, continuous deploy | GitHub Flow |
| Multiple supported product versions in production | Git Flow (or GitHub Flow + version tags) |
| Regulated environment, formal release validation | Git Flow |
| Small high-trust team with feature flags | Trunk-based |
| Ignition shop with multi-gateway customers | GitHub Flow + per-customer tags (Lab 05 territory) |

If someone picks **trunk-based** for a team with no feature-flag system, push back:
where do in-progress features live in production?

If someone picks **Git Flow** for a single-product SaaS that deploys continuously,
push back: what is the `develop` branch buying you?

What to probe for in the argument:

- **Specific branch naming.** "use descriptive names" is a hope; `feature/<jira-id>-slug`, `fix/<slug>`, `hotfix/<slug>` is a rule. `dev`/`test`/`prod` as *branch* names is a smell (those are tags/environments).
- **A justified merge style.** Can they say *why* `--no-ff` vs squash vs rebase? Best answer names a benefit: "`--no-ff` keeps branch shape in `git log --graph`, so what shipped in v1.2 is visible without tags." "Rebase because it's clean" without saying why clean beats informative is shallow.
- **A concrete hotfix rule.** "Branch from `main`, fix, merge first, tag `v1.2.1`, deploy" (GitHub Flow) or "branch from the `v1.2` tag, merge to `main` and `develop`, tag" (Git Flow) is concrete. "Hotfix as needed" is a hope. Part 2 makes them *do* the GitHub Flow version, so this discussion primes it.

## Common pitfalls in the discussion

- **Strategy + reality mismatch.** Someone has been doing trunk-based informally but names "Git Flow" because it sounds more sophisticated. Probe: "what's the smallest change you'd actually move to Git Flow for?"
- **Hand-waved hotfix process.** Especially for Ignition teams: what does "hotfix the gateway" mean? A deploy of the whole project, a config-only change, or a single tag value? They'll figure this out in Lab 04, but mention it now. Part 2's hotfix is a first taste.
- **No mention of who merges.** Who has merge rights? The PR author? A reviewer? Anyone with approval? Worth asking.
- **No mention of release cadence.** "We ship when ready" is not a cadence. Push for at least a rough rhythm.

## Stretch: Git Flow rerun

The first stretch has participants re-run the *same* scenario in Git Flow, to feel
the contrast against GitHub Flow. It only works after a rewind — post-scenario, their
fork's `main` already contains both changes, so there'd be nothing left to do. The
exercise has them `git reset --hard v1.2` + force-push `main` (and delete the local
feature branch) first; expect "wait, force-push?!" — the answer is that it's their
throwaway fork, and rewriting a shared `main` for real is exactly what Stretch 2's
branch protection forbids. Then, what "good" looks like: they actually notice the
two differences that matter, not just "it was more work."

- **The hotfix merges twice.** They create a long-lived `develop`, run the feature off `develop` and the hotfix off `main`, and the hotfix needs **two PRs** — into `main` (tagged `v1.2.1`) *and* into `develop`. A participant who merges it once hasn't switched models: their next "release" from `develop` would regress the fix. One mechanical gotcha lives here: deleting the hotfix branch after the first merge auto-closes the still-open second PR — both merges first, then delete.
- **They spot what the ceremony buys.** In the main scenario `v1.2` lived in a tag; here a whole branch structure guards the released version. That's the point: Git Flow is what it takes when production runs an *older* release than `main` and tags alone stop being enough.

A participant who can articulate "Git Flow's double-merge is the price of supporting
old versions" has understood both strategies from the inside. That's the whole goal.

## Branching-strategy debrief crib

- *"Where does `v1.2` live in GitHub Flow — and when do tags stop being enough?"*: The answer to the first half is **in the tags** (`git checkout v1.2` gets you back). The second half is the binary from the matrix: tags stop being enough when more than one version is live and old releases need patches — that's what `develop` + double-merge buy. Stretch-doers can answer from experience; push the others to reason it out.
- *"Did the double-merge feel worth it?"* (stretch-doers): The best answers connect ceremony to a *reason*: worth it when more than one version is live, pure overhead when only `main` ships. Someone who found it purely annoying probably has a single-version reality, which is a fine answer if they *say* that.
- *"Which strategy surprised you?"*: Most non-developers are surprised by **trunk-based**. It looks chaotic but works in mature teams. Worth contrasting with Git Flow, which looks rigorous but mostly creates merge work.
- *"Which would you adopt tomorrow?"*: Push for a one-sentence reason. "GitHub Flow because we're a 4-person team and continuous deploy" is a good answer. "GitHub Flow because it's simple" without a fit-to-team reason is shallow.
- *"What makes branching harder for Ignition teams?"*: Three honest answers:
  1. Project export format makes diffs noisy
  2. Multi-gateway state means "what's in production" is plural
  3. Hotfix-via-Designer is still a thing in many shops, and it bypasses Git entirely
- Foreshadow Lab 04: most of what we've discussed assumes a clean text-file diff. Ignition projects test that assumption, and this lab's `projects/lab-project/` is a first, deliberately gentle look at what those text files are.

---

# Pull requests

## The scenario, and the branches you should see

Part 2 produces two branches and two PRs per participant, both based on `main`:

1. `feature/v2-<view>` off **`main`**: a new Perspective view (the v2.0 feature). PR base = `main`, left open until the fix has shipped.
2. `fix/null-reading` off **`main`**: the null-reading fix. **One** PR, `fix -> main` — merged first, then `v1.2.1` tagged on `main`.
3. The feature branch, updated from `main` after the fix lands (`git merge main`), then its PR merged.

The single most important GitHub Flow check across all of it: **did the fix merge —
and `v1.2.1` get tagged — before the feature?** Merging is releasing: whatever is on
`main` at tag time ships in that release. A `v1.2.1` tag that contains half of v2.0
is the classic mistake this scenario exists to catch. See it with
`git log --graph --oneline --all` (the tag should sit on the fix's merge commit, below
the feature's).

## The fix code (reference solution)

The P1 fix has participants repair `lab.display.format_reading()` so a null reading
(comms loss / unread tag) shows a placeholder instead of throwing. A clean solution:

```python
PLACEHOLDER = "--"


def format_reading(value, units):
    if value is None:
        return "%s %s" % (PLACEHOLDER, units)
    try:
        return "%.1f %s" % (float(value), units)
    except (ValueError, TypeError):
        return "%s %s" % (PLACEHOLDER, units)
```

What to look for / push on:

- **Normal readings still format.** `format_reading(162.0, "°C")` must still return `"162.0 °C"` (one decimal, units appended). A fix that returns the placeholder for valid numbers, or quietly drops the rounding, has broken the happy path. If `validate.sh` is green but a real value renders wrong, that's an `issue:`, and a great reminder that "parses cleanly" is not "works."
- **Null, not just zero.** The whole point is `None` (bad quality / comms loss). `0` is a *valid* reading and must still format as `"0.0 °C"`. A fix that treats `0` as missing is wrong.
- **One concern, small diff.** If the PR also renames things or reformats the module, it's no longer the small scoped PR the block is teaching. Call it out.

> **On testing.** This lab's green/red signal is `scripts/validate.sh`, which checks
> that JSON is valid and Python parses, *not* behavior. That's deliberate: automated
> behavior tests (and a real "tests pass" gate in CI) arrive in Lab 03. So in the
> review, "is it tested?" becomes "did they verify it, and is the verification
> something I could repeat?" If a participant *wants* to prove the behavior, the
> honest manual check is the gateway's **Script Console** (`lab.display.format_reading(None, "°C")`),
> but that's optional and not required to pass the exercise.

## The feature (reference solution)

The v2.0 feature is a new Perspective view, added off `main`. A clean one:

- **A new resource folder** under `views/pages/` (easiest: copy `overview`, rename),
  with its `view.json` payload and `resource.json` manifest, plus the page registered
  in `page-config/config.json` so it's actually reachable.
- **`validate.sh` green** (valid JSON throughout), and a small, scoped diff.

Watch for: a copy that breaks the JSON (validate.sh catches it), a page that isn't
registered so nothing actually goes "live," or a sprawling redesign that's no longer
a small PR. Any of those is fair review fodder. The feature is deliberately low-stakes
(the *fix* carries the review teeth); its job is to be the open branch that the
P1 ambush interrupts.

## What "good" looks like for the peer review

The You-do asks for a few genuinely helpful comments: at minimum a `praise:` and a `suggestion:`, plus an `issue:` when something's actually wrong. There's no quota: a thoughtful 3-comment review beats six box-ticking ones. The lab keeps participants to three labels on purpose; the fuller set (`question`, `nitpick`, `thought`, `chore`) lives in the optional `docs/pr-review-style.md` for anyone who wants it, and you should feel free to model those richer labels in your own review comments.

### A reference review skeleton

The **fix PR** is the richest to review, and carries a GitHub-Flow-specific check
the null-reading fix alone doesn't. A strong review will include something like:

- **The GitHub Flow structural check.** Is the fix **just the fix** — no v2.0 work riding along — and is the plan to merge it (and tag `v1.2.1`) *before* the feature? Merging is releasing: a fix PR that merges after the feature quietly ships half of v2.0 under a patch tag. Either problem is a legitimate `issue:`, and the point of the whole scenario.
- **One `praise:`** something genuinely good. A focused diff, or keeping the `None` guard. Praise is not throwaway; it tells the author what's working.
- **At least one `question:`** there's almost always something genuinely unclear. "question: should a null reading show `--`, or hold the last-known value? What do operators expect on comms loss?" Questions surface assumptions the author didn't realize they had.
- **At least one `suggestion:`** a specific change the author could make. Not a vague "this could be better" but a concrete alternative. "suggestion: reuse `lab.util.to_float(value, default=None)` for the junk-input case — keeping the `None` check on the result."
  > **The `to_float` trap (know this one).** *Naive* reuse — `lab.util.to_float(value)` with its default of `0.0` — silently turns a null reading into `"0.0 °C"`: exactly the zero-vs-null confusion the exercise teaches, and `validate.sh` stays green through it. Correct reuse passes `default=None` and still checks for `None` before formatting, which is barely shorter than the explicit guard. If a reviewer suggests plain `to_float` and the author accepts it unthinkingly, that's a live demo of "accepting every suggestion without thinking" — surface it in the debrief.
- **Optionally `nitpick:`** for small style things. PEP8, the docstring wording, `is None` vs `== None`. Always non-blocking.
- **`issue:` only when you mean it.** If the fix breaks valid readings (placeholder for real numbers, or lost rounding), that's a real issue. Don't use `issue:` for taste differences.

For the **feature PR**, the review is lighter: valid JSON, page actually registered
and reachable, change scoped. It's a fine place to model `praise:` and a small
`suggestion:` without a blocking `issue:`.

### Tone: what to flag

Watch reviews for:

- **Sarcasm or condescension.** "Why didn't you just guard the None?" reads as judgmental. Better: "question: any reason to keep the explicit `None` check over leaning on `lab.util.to_float`?"
- **Vague criticism.** "This isn't very specific" is not actionable. Better: "suggestion: 'feature branches' is generic; would you commit to a specific pattern like `feature/<ticket-id>-<slug>`?"
- **Drive-by comments without context.** A single `?` or `huh?` is unhelpful. Push them to expand.
- **Blocker comments dressed as nitpicks.** If the comment would prevent merge, it shouldn't be labeled `nitpick:`, which misleads the author.

If you spot any of these, model the rewrite in your own review comment on the same PR (or in the debrief). The label vocabulary is most of the lesson, but tone is where it actually lands.

## What "good" looks like for the author's response

Authors should:

- React to every comment with *something* (a reply, a reaction, or a fix-up commit).
- For `suggestion:` and `issue:` comments: explicit accept/decline with reasoning. Silent ignores are a smell.
- For `question:` comments: an answer, even if short.
- Re-request review after substantive changes.

Common author mistakes:

- **Marking conversations as resolved without responding.** Push back: even a `+1` reply is more communicative than silent resolution.
- **Accepting every suggestion without thinking.** Authors are not obligated to agree. A `decline: I think the explicit None check reads clearer than the helper here` is a valid response.
- **Force-pushing over fix-ups.** A force-push during review nukes the reviewer's context. Prefer additive commits during review; squash on merge if you must.

## Merge order (the GitHub Flow payoff)

The merge *order* is the lesson here, more than the merge *style*. In GitHub Flow,
merging is releasing, so merge order is release order:

1. `fix -> main` first (production is on fire), then **tag `v1.2.1`** on `main`.
2. `feature -> main` last (v2.0 progresses), after updating the feature branch
   from `main` so it carries the fix.

Common mistakes to catch:

- **Tagging `v1.2.1` after the feature merged.** The single most important thing to verify: the "patch" tag now ships half of v2.0. Ask them to prove it — `git log v1.2.1 --oneline` should contain the placeholder fix but **not** the silo detail view. The tag should sit on the fix's merge commit.
- **Forgetting the tag.** In GitHub Flow the tag *is* the release record; skip it and "what's in production" has no answer beyond "whatever main was at some point." No tag, no audit trail.
- **Merging the feature before the fix.** Not fatal for the code (main ends up the same), but the release story is wrong — and if they then tag, see mistake one.
- **Updating the feature branch too early.** `git merge main` on the feature branch only picks up the fix *after* `fix -> main` has merged; run before that, it's a silent no-op ("Already up to date") and they'll think they're done. The exercise sequences it in the merge step for this reason.

As for the merge *button* itself, GitHub's dropdown gives three options; any is fine
here as long as it's deliberate. A merge commit keeps the branch shape visible in
`git log --graph`; squash gives `main` a clean one-commit-per-PR history, which is
why many GitHub Flow teams default to it. If GitHub doesn't show all three, the repo
restricted them in Settings, Branches, Merge button options; worth surfacing as a
procedural point.

## Stretch: branch protection

Acceptable settings vary by team. Look for at least:

- "Require pull request reviews before merging": usually 1 approval
- "Dismiss stale pull request approvals when new commits are pushed": fights against approve-and-then-force-push
- "Do not allow bypassing the above settings": applies the rules even to admins

We deliberately don't require "passing CI" here because Lab 02 has no CI: `validate.sh` is a local convenience, not an enforced gate. Lab 03 introduces CI; when participants set up branch protection then, they should layer "require status checks" on top.

## Pull-request debrief crib

- *"One thing you'll steal?"*: Push for specifics. "I liked their PR description" is shallow. "I liked that they linked to the ticket and quoted the customer's report" is real.
- *"One habit to drop?"*: The honest answers are often: "writing PRs too big," "not verifying my own change before opening," "leaving lots of nitpicks instead of one suggestion."
- *"When does request-changes do more harm than good?"*: Three common cases:
  1. When the only issues are nitpicks (use approve + nitpick comments instead).
  2. When the reviewer is the second of two and the first already approved (use comment-only).
  3. When the timing matters and the author is offline (consider a synchronous chat instead of a blocking review).
- *"Smallest meaningful Ignition PR?"*: They just shipped ones: a single script-function hotfix, a single new view. The point is to seed the idea that PR-sized changes are *possible* for Ignition, even though many shops currently PR whole gateway backups.

End the lab with one explicit foreshadowing line: **"Tomorrow we add the CI safety net, turning `validate.sh` into a gate no one can merge past, and that makes all of this scale."**
