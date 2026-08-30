---
name: gha-pod-death-log-truncation
description: "When an ARC/GHA pod dies mid-step, the step's log content is LOST — the run shows the step as in_progress with zero log output. Don't waste time grepping for an error message that isn't there."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

GitHub Actions runners stream stdout/stderr to the GHA API in batches. If the runner pod dies (OOM, network loss, controller eviction, heartbeat timeout) BEFORE flushing the current batch, that batch is lost. The job shows the step as `in_progress` at job-completion time and the log file in the API zip is missing or truncated.

The symptom (in any `gh run view --log` or downloaded zip):

```
ci-affected-shas/system.txt
ci-affected-shas/1_Set up job.txt
ci-affected-shas/2_Run actions_checkout@....txt
ci-affected-shas/3_Capture job start time.txt
```

…and that's it. The step that ACTUALLY died (`arc-setup-workspace`, `npm ci`, etc.) has no log file at all, even though `jq -r '.jobs[].steps[]' shows it as `in_progress`.

**Why:** 2026-05-26 PR #939 ran the ci-v2.yml shadow workflow on ARC for the first time. Three runs in a row (26443148932, 26444347966, 26447212888) failed at the ~12-min mark with `ci-affected-shas` showing `arc-setup-workspace` as in_progress and ZERO log content past the previous step. The first 30 minutes of debugging assumed there was an error message in the log somewhere — there wasn't. The smoking gun was actually the ABSENCE of logs.

**How to apply:**

- **Don't waste time grepping logs that aren't there.** If `gh run view 2>&1 | grep -i error` returns nothing AND the step duration is suspiciously long (>10 min), the pod died — investigate pod lifecycle, not log content.
- **Diagnostic hierarchy when a step has zero logs:**
  1. Check duration: if ~10-15 min, likely GHA heartbeat timeout — see [[feedback_gha_npm_ci_heartbeat_timeout]].
  2. Check job conclusion: `failure` vs `cancelled` indicates different death paths (cancelled often = external/GHA-side; failure often = pod-side OOM/eviction).
  3. Check resource limits vs workload memory profile — if OOM, bumping `mem_lim` in the runner-scale-set values may help.
  4. Check kubelet/node events on the cluster: `kubectl -n arc-system describe pod <runner-pod>` (if still in event log) or scrape Loki for that pod's container_id.
- **Add heartbeat output to long-running silent steps** to defeat the GHA heartbeat detection — see [[feedback_gha_npm_ci_heartbeat_timeout]] for the npm-specific recipe.
- **Don't change unrelated things between runs.** If three failed runs all die at the same elapsed time independent of runner size, the cause is time-based (heartbeat, lifecycle timeout) — not resource-based.
