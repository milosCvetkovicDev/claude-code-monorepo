---
name: gh-run-watch-lies-on-cancelled
description: gh run watch --exit-status returns 0 even when the run conclusion is "cancelled" — must verify conclusion via the API
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000050
---

`gh run watch <id> --exit-status` returns exit code 0 when the run completes, **regardless of whether the conclusion is success or cancelled**. The exit code only reflects "the run reached a terminal state".

**Why:** Bit me twice in cancel-receipted-purchase deploy chain (2026-04-30). First legacy-web dev deploy was silently cancelled by concurrency rules (a second deploy started seconds after the first); my background watcher exited 0 and I told the user "deploy succeeded" — they then reported the feature wasn't on dev. Investigated: run conclusion was `cancelled`. Re-deploy needed. Same risk applies to every `gh run watch` use I make for prod deploys.

**How to apply:** After every `gh run watch <id>`, ALWAYS verify the actual conclusion:

```bash
gh run watch <id> --exit-status
gh api repos/<owner>/<repo>/actions/runs/<id> --jq '{conclusion, status}'
# Fail loudly if conclusion != "success"
```

Or chain them:

```bash
gh run watch 12345 --exit-status && \
[ "$(gh api repos/.../actions/runs/12345 --jq .conclusion)" = "success" ] || \
echo "❌ Run not actually successful — check conclusion"
```

The lesson: never trust the watch exit code alone for any deploy I report as "succeeded".

---

## Companion pitfall: `gh run rerun --failed` on an AGGREGATOR gate never re-runs the tests (2026-06-20)

When a REQUIRED check is an **aggregator** that only reads upstream job _outputs_ (e.g. Platform `platform-ci-gate` reads the `ci` job's per-service `test:unit` result map and fails if any entry != success), `gh run rerun <id> --failed` re-runs ONLY the failed job — which is the **5-second aggregator gate**, NOT the `ci`/test job. The gate then re-reads the SAME stale upstream outputs and fails identically. A naive "retry on flake" watcher that loops `rerun --failed` produced **17 identical 5s failures** = ONE stale result re-counted 17×, never a real test re-execution → looks deterministic, masks a flake.

**How to apply:** To actually re-execute the tests behind an aggregator gate, use a **FULL** rerun: `gh run rerun <id>` (no `--failed`) re-runs the whole workflow graph incl. the `ci`/test job → fresh per-service map → gate re-aggregates fresh. Confirmed 2026-06-20: a single Platform trading-service `test:unit` flake (`runWithTimeout` + `ECONNREFUSED redis`) blocked #1351 (tenant-filter); full rerun → green/CLEAN → merged. Before blaming a code change for an aggregator-gate red, check whether the per-service map names a service whose tree is **identical to green main** — if so it's a flake; full-rerun, don't debug the diff.
