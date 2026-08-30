# CI/CD Learnings

## Workflow IDs
CI: 000000000 | Deploy: 000000000 | Security: 000000000 | E2E: 000000000 | Dev Instance: 000000000

## Trigger Rules
- Push triggers: `main` only. Feature branches covered by `pull_request`
- Concurrency: `ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}` + cancel-in-progress
- `workflow_dispatch` without `--ref` uses **main branch workflow** — always `gh workflow run <wf> --ref <branch>`

## GHCR Authentication (Two Tokens)
| Purpose | Token | Permission | Lifetime |
|---------|-------|-----------|----------|
| CI push (build & push images) | `GITHUB_TOKEN` | `packages: write` | Ephemeral per workflow |
| Runtime pull (Container App) | `GHCR_TOKEN` (PAT) | `read:packages` | Long-lived |

Error `permission_denied: The token provided does not match expected scopes` = using wrong token for push.

## Dev Instance Deployment
- `gh workflow run deploy-dev-ephemeral.yml --ref <branch> -f instance=dev-2 -f action=deploy`
- Sets `COMMISSION_API_URL` on legacy-api automatically
- Commission seeding uses `continue-on-error: true`
- Health check order: deploy all -> health check backend -> DB firewall + migrations -> health check domain-api
- **curl health checks MUST use `--max-time 10`** — without timeout, can hang 50+ minutes

## Platform-Specific Dependencies
- `@nx/nx-darwin-arm64` etc. MUST be `optionalDependencies` (not `dependencies`)
- Regular `dependencies` causes `EBADPLATFORM` error on Linux CI
- Lockfile records `optional: true` flag — `npm ci` treats non-optional as required

## Platform Deploy (platform-deploy.yml)
- Deploys by pushing updated image tags to `gitops/dev` branch (direct push, not PR-based)
- Enterprise policy blocks GITHUB_TOKEN from creating PRs — cannot use PR-based GitOps
- ArgoCD watches `gitops/dev` branch, syncs automatically
- Overlay directory is `dev` not `development` (charts/overlays/dev/)
- Helm `parameters` block overrides `valueFiles` — never set image.tag in parameters
- yq v4.44.1 SHA-256: `6dc2d0cd4e0caca5aeffd0d784a48263591080e4a0895abe69f3a76eb50d1ba3`
- CI SP K8s RBAC: Role/RoleBinding in `argocd` namespace (applied via kubectl --admin, not Terraform)

## Failure Sources (ranked)
1. Security Scan (gitleaks false positives, Trivy CVEs, npm audit)
2. Deploy (health checks, OIDC)
3. CI (frontend test shard 4, TS build)

## Gitleaks
Add to `.gitleaks.toml` `rules.allowlists` regexes

## npm CVEs
Add `"overrides"` in root `package.json` -> `npm install`

## gh CLI Quick Reference
```bash
gh run list --branch main --limit 5
gh run view <id> --json jobs --jq '.jobs[] | "\(.name): \(.status) \(.conclusion)"'
gh run rerun <id> --failed
gh run view <id> --log-failed
```
