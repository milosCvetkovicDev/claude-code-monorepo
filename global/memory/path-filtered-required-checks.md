---
name: path-filtered-required-checks
description: Historical — Validate Terraform workflow used to be path-filtered and force --admin merge bypass on non-infra PRs. Fixed in #662 (Platform platform redesign Phase 0).
type: project
originSessionId: 00000000-0000-0000-0000-000000000051
---

**Status: RESOLVED** (2026-05-06, platform branch, task #662 / commit on epic `platform-redesign`)

## Original problem (kept for historical context)

`Validate Terraform` was in the branch protection required-checks list for `main`, but `terraform-validate.yml` had `pull_request: paths: ['infra/**', '.github/workflows/terraform-validate.yml']`. Any PR that didn't touch `infra/**` left the check stuck in `EXPECTED` state forever — `gh pr merge` returned "the base branch policy prohibits the merge", forcing `--admin` bypass.

Why it bit us: GitHub treats a workflow that *would* run as required, but a workflow that *never starts* doesn't satisfy the gate. Same trap applies to any other path-filtered workflow promoted to required — recheck if a new one is added to required checks.

Observed on PR #578 (epic/data-seeding-commission-gp-alignment, 2026-04-28). Same pattern would have blocked any PRD/docs/lib-only PR.

## Fix (#662)

`terraform-validate.yml` no longer has a `paths:` filter on its `pull_request` trigger — it runs on every PR. Inside the single `Validate Terraform` job, a `Detect infra changes` step diffs against `${{ github.event.pull_request.base.sha }}` and sets `steps.changes.outputs.has_infra`. Every Terraform step is gated `if: steps.changes.outputs.has_infra == 'true'`. Non-infra PRs short-circuit in ~5–10s and return a green check without running terraform tooling. The `Check Results` step exits 0 trivially when `has_infra != true`.

Net: the required-check status is always populated, infra PRs get the same validation as before, no `--admin` bypass needed for any PR class.

## How to apply (now)

If a non-infra PR ever again hits "base branch policy prohibits the merge", DO NOT use `--admin`. Instead:
- Verify `Validate Terraform` actually ran on the PR (`gh pr checks <num>` should show the job, not `EXPECTED`).
- If it didn't run: the `paths:` filter has likely been reintroduced — revert that and call out the regression.
- If it ran and failed: that's a real failure, fix it.

The structural-assertion fixture at `.github/workflows/test/terraform-validate-path-filter.yaml` should catch this regression in CI before merge.
