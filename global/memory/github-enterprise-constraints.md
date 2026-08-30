---
name: github-enterprise-constraints
description: Enterprise-level GitHub restrictions that affect CI/CD workflow design
type: project
originSessionId: 00000000-0000-0000-0000-000000000078
---
Enterprise policy blocks GITHUB_TOKEN from creating or approving pull requests.

**Why:** The `initech-trading-platform` org is under an enterprise that enforces `can_approve_pull_request_reviews: false`. This cannot be overridden at the org or repo level.

**How to apply:** Any CI/CD workflow that needs to create PRs (e.g., automated deploy PRs, dependency update PRs) must either:
1. Use direct push instead of PR creation (current approach for Platform deploy)
2. Use a GitHub App token or PAT instead of GITHUB_TOKEN
3. Request enterprise admin to change the policy

Discovered 2026-04-10 when Platform deploy PR creation failed with: "GitHub Actions is not permitted to create or approve pull requests"
