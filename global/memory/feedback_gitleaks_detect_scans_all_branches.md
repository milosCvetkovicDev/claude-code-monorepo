---
name: feedback_gitleaks_detect_scans_all_branches
description: "CI gitleaks detect scans ALL fetched branches, not just HEAD — one branch's false positive reddens every re-running PR; suppress via .gitleaks.toml path allowlist"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000011
---

The repo's `security-scan.yml` runs `gitleaks detect --config .gitleaks.toml --verbose --redact --exit-code 1` after `actions/checkout` with `fetch-depth: 0`. That fetch pulls **all** branches into the clone, and `gitleaks detect` scans the **entire commit set across all refs** (observed: "2372 commits scanned"), NOT just the PR's HEAD-reachable history.

**Consequence:** a secret or false-positive committed on ANY branch reddens the gitleaks ("Secret Scanning") check on EVERY PR whose CI re-runs after that commit exists — including unrelated `base: main` PRs that don't contain the file. Other PRs only show "pass" because their last gitleaks run **predates** the offending commit; any re-run flips them red too. I mis-diagnosed this twice as "merge-ref scoped / stale merge-ref" — it is not; it is all-refs scanning.

**Why:** confirmed 2026-06-06 on the CNPG PRs — the vendored Barman manifest (`charts/cnpg-barman-plugin/manifest.yaml` base64 `SIDECAR_IMAGE`, commit `497db827` on the operator-install branch) flagged #1146 and #1158 even though neither contains the file.

**How to apply:**
- Suppress false positives with a `.gitleaks.toml` `[allowlist] paths` regex (e.g. `'''charts/cnpg-barman-plugin/manifest\.yaml$'''`), NOT a `.gitleaksignore` fingerprint. gitleaks reads the config from the checked-out merge-ref and applies the allowlist **globally** to all scanned findings, so it suppresses the finding on every branch.
- `.gitleaksignore` entries are `commit:file:rule:line`. A **commit-less** entry only matches `gitleaks protect --staged` (the pre-commit hook), NEVER CI `gitleaks detect`. Line-pinned fingerprints also drift on any file change. Avoid both for CI suppression.
- To make a single PR green now, add the allowlist to that PR's branch. The **durable repo-wide cure** is the allowlist reaching `main` (it lands when any PR carrying it merges) — then every PR's merge-ref has it.
- "Secret Scanning (Gitleaks)" is **informational**, not a required merge gate (CLAUDE.md), so the red is noise/alert-fatigue, not a blocker — but fix it so real secrets aren't masked. See [[platform-cnpg-data-tier-poc-gated]].
