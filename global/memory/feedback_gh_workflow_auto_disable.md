---
name: gh-workflow-auto-disable
description: "GitHub auto-disables workflows after sustained failures — `gh workflow run` returns HTTP 422 'Cannot trigger workflow_dispatch on a disabled workflow'; need `gh workflow enable` first"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

GitHub Actions automatically disables a workflow after sustained scheduled failures (the exact threshold isn't publicly documented but ~50+ consecutive failures will trip it). The workflow file stays in the repo; only the trigger is disabled. `gh workflow run` fails with:

```
HTTP 422: Cannot trigger a 'workflow_dispatch' on a disabled workflow
```

The fix is `gh workflow enable <workflow.yml>` first, then dispatch:

```bash
gh workflow enable platform-runner-health.yml --repo <owner>/<repo>
gh workflow run platform-runner-health.yml --repo <owner>/<repo> --ref main
```

**Why:** 2026-05-25 after merging PR #918 (rewrite of `platform-runner-health.yml`), the dispatch failed because the workflow had been auto-disabled — the OLD version had been failing every 15 min for several days querying a deleted VM (`dev-runner-01/02`). Re-enabling + dispatching produced the expected success in <30s.

**How to apply:**
- After fixing a workflow that's been failing on a schedule, always check `gh workflow list --repo <owner>/<repo>` for the `state` column — if it says `disabled_inactivity`, enable before dispatching.
- When inheriting CI/CD work, scan for workflows in `disabled_inactivity` state — they often indicate forgotten / broken monitors and are worth either fixing or deleting.
- DO NOT rely on schedule alone to validate a rewritten workflow — auto-disable means the schedule won't fire. Always do a manual `workflow_dispatch` first.
