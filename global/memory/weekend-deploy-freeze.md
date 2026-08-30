---
name: weekend-deploy-freeze
description: GitHub Actions Deploy workflow auto-skips on Sat/Sun. Manual workflow_dispatch bypasses.
type: project
originSessionId: 00000000-0000-0000-0000-000000000079
---
# Weekend Deploy Freeze

The `Deploy` workflow's `deployment-gate` job evaluates `date -u +%u`. If the day-of-week is ≥ 6 (Saturday=6, Sunday=7 UTC), it sets `proceed=false` and every `deploy-*` job is skipped. The gate is silent — CI green and Deploy workflow "completed success" but a "No Deployment Needed" job runs instead of the actual deploy.

**Why:** Reduce risk of weekend production breakage — no one is around to respond to alerts during off-hours.

**How to apply:**
- Weekend CI-on-main success ≠ "deployed" — always verify with `gh run view <id> --json jobs` and look for `deploy-*` jobs with `conclusion: "skipped"`
- To deploy on a weekend (or any time the gate blocks), use manual dispatch:
  ```bash
  gh workflow run "Deploy" --ref main -f environment=<env> -f app=<app-or-empty>
  ```
  Manual dispatch bypasses the freeze unconditionally (`if [ "$EVENT_NAME" = "workflow_dispatch" ]; then proceed=true`)
- Also bypassable by the `DEPLOYMENT_FREEZE` repository variable — not used currently but available for longer freezes (code freezes, holiday windows)
- prod-acme-legacy requires manual dispatch regardless of day (environment rule), so this freeze only affects development auto-deploys
