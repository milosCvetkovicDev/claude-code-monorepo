---
name: ci-workflow-dispatch-quirks
description: GitHub Actions on acme sometimes does not auto-trigger PR workflows after push — manual dispatch via `gh workflow run` is the workaround.
type: project
originSessionId: 00000000-0000-0000-0000-000000000039
---
# CI workflow dispatch quirks

**Observation:** On `initech-trading-platform/acme`, GitHub Actions sometimes fails to auto-trigger the `CI` / `Platform CI` / `Security Scan` workflows after a `git push` to an epic branch with an open PR. Saw this repeatedly during PR #499 and PR #551 sessions — an empty commit did not reliably help either.

**Fingerprint:** `gh api repos/.../actions/runs?head_sha=<SHA>` returns `workflow_runs: []` minutes after the push, even though the PR shows the new commit and `gh pr view --json mergeStateStatus` reports `BEHIND`/`BLOCKED`.

**Workaround:** Manually dispatch each workflow on the branch:

```bash
gh workflow run ci.yml --ref epic/<branch>
gh workflow run security-scan.yml --ref epic/<branch>
gh workflow run platform-ci.yml --ref epic/<branch>
```

All three in this repo support `workflow_dispatch` (verified by presence of `workflow_dispatch:` in their `on:` blocks). They'll run on the branch HEAD at dispatch time, so no extra args needed.

**Why:** Unclear. Possibly a GitHub Actions regional lag or a webhook delivery gap — the check is always "no runs" rather than "runs failed to start". Reproduced multiple times across 2026-04-17 and 2026-04-24 sessions.

**How to apply:** After pushing to an epic branch, wait ~60s. If `gh pr checks <pr> --json name,state,bucket` still reports "no checks reported" or the counts don't match the commit, trigger the three workflows manually. Don't waste time retrying pushes or creating empty commits — just dispatch.
