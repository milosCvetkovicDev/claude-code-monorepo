---
name: platform-ci-legacy-gate-timeout-and-admin-merge
description: "Platform PR merges — legacy ci-gate 20-min timeout on cold builds, admin-merge-past-legacy technique, UNSTABLE is mergeable, squash-stack retarget"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000067
---

Merging Platform-only PRs to `main` (strict up-to-date + required checks = `Validate Terraform` + `ci-gate` + `platform-ci-gate`). Hard-won mechanics from the platform-v2-fe-alignment epic drain (2026-07-02):

- **Legacy `ci-gate` has a 20-min timeout** (ci.yml:185 `timeout-minutes: 20`; Platform `ci/ci` is 25, \_ci.yml:148). A **cold/large** `nx affected` build overruns it → job `cancelled` at ~20 min → `ci-gate` FAILURE. This is the #1 cause of "CI takes forever" — NOT flakiness, NOT churn. Small/warm-cached builds (e.g. tiny PRs) slip under it.
- **Re-run to warm the cache:** `gh run rerun <id> --failed` — Nx caches each task that finished before the cutoff, so each re-run starts warmer until the remaining work fits under 20 min. Converges in 1–3 passes. This is how a big Platform PR eventually passes ci-gate without a code change.
- **`nx.json` changes can't be cache-warmed down** — nx.json is a _global_ input, so it busts every task hash → full cold build every run → legacy gate times out **deterministically**. Such a PR (#1578) can ONLY land via admin-merge or a timeout bump.
- **Admin-merge past the legacy gate (for Platform-only PRs):** the legacy `ci-gate` builds the **legacy** stack, which Platform-only changes don't touch — so it's _irrelevant_ to their correctness. If `platform-ci-gate` is green (the relevant gate), `ALLOW_PR_MERGE=1 gh pr merge <pr> --squash --admin --delete-branch` lands it. **The guard hook does NOT special-case `--admin`** — it gates ALL `gh pr merge` behind the `ALLOW_PR_MERGE=1` front-prefix, and that prefix permits `--admin` too. `--admin` also bypasses strict up-to-date (BEHIND is fine). NEVER admin-bypass `platform-ci-gate` itself — re-run it on infra-cancel instead. Requires user authorization + admin token.
- **`UNSTABLE` mergeStateStatus IS mergeable** when all _required_ checks are green (only a non-required/informational check like `integration-tests` is red). A merge waiter that only fires on `CLEAN` will hang forever on a mergeable `UNSTABLE` PR — check for **3/3 required green**, not `CLEAN`.
- **Squash-merged base → stacked PR:** after the base PR squash-merges, the stacked PR's diff re-shows the base's files (git can't see squashed==original). `gh pr update-branch <stacked>` **collapses it cleanly** (the stacked branch's tree is a superset, so the 3-way merge drops the overlap) — no rebase/force-push needed. Verified 63→46 files, 0 overlap.
- **`--delete-branch` silently skips in detached HEAD** (`could not determine current branch` warning, exit 0, branch NOT deleted). Delete merged branches explicitly afterward: `git push origin --delete <branch>`.
- Merge-guard hook lives at `acme/.claude/hooks/block-dangerous-commands.sh`. See [[feedback_gh_pr_merge_delete_branch_worktree_quirk]], [[path-filtered-required-checks]].
