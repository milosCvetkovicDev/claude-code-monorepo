# GitHub Actions Patterns — Acme

This document contains VERIFIED, working patterns from the acme repository.
**When writing or modifying GitHub Actions workflows, you MUST use these patterns. Do NOT invent syntax from memory.**

## Action Versions (SHA-Pinned)

NEVER use tag-based references like `actions/checkout@v4`. ALWAYS use the exact SHA pins below.

```yaml
# Checkout
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
  with:
    filter: tree:0  # Treeless clone — faster for CI

# Node.js setup — use composite action instead
- uses: ./.github/actions/setup-node-npm
  with:
    node-version: ${{ env.NODE_VERSION }}

# Docker buildx
- uses: docker/setup-buildx-action@c47758b77c9736f4b2ef4073d4d51994fabfe349 # v3.7.1

# Docker login (GHCR)
- uses: docker/login-action@9780b0c442fbb1117ed29e0efdff1e18412f7567 # v3.3.0

# Docker metadata
- uses: docker/metadata-action@369eb591f429131d6889c46b94e711f089e6ca96 # v5.6.1

# Docker build+push
- uses: docker/build-push-action@4f58ea79222b3b9dc2c8bbdd6debcef730109a75 # v6.9.0
```

## Concurrency Patterns

```yaml
# PRs: cancel in-progress — saves runner time
concurrency:
  group: ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

# Main branch: NEVER cancel — every commit gets full results
concurrency:
  group: platform-ci-${{ github.event.pull_request.number || github.sha }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

# Deployments: exclusive per environment — no concurrent deploys
concurrency:
  group: platform-deploy-${{ inputs.environment || 'development' }}
  cancel-in-progress: false
```

## Trigger Patterns

```yaml
# CI: push + PR + manual, skip docs
on:
  push:
    branches: [main]
    paths-ignore: ['docs/**', '**/*.md', '.gitignore', 'LICENSE']
  pull_request:
    paths-ignore: ['docs/**', '**/*.md', '.gitignore', 'LICENSE']
  workflow_dispatch:

# Platform CI: path-scoped triggers (only run when platform code changes)
on:
  push:
    branches: [main]
    paths:
      - 'apps/platform/**'
      - 'libs/platform/**'
      - 'package.json'
      - 'package-lock.json'
      - '!charts/**'  # Exclude Helm chart changes
  pull_request:
    paths: [same as above]

# Post-build deployment: workflow_run trigger
on:
  workflow_run:
    workflows: ['Platform Build & Push']
    types: [completed]
    branches: [main]
  workflow_dispatch:
    inputs:
      skip_trivy:
        description: 'Skip Trivy security scan'
        type: boolean
        default: false
```

**CRITICAL: `workflow_run` only triggers from the default branch (main). It will NOT trigger from feature branches.**

## Environment Variables

```yaml
env:
  NODE_VERSION: '22'
  NX_DAEMON: 'false'  # ALWAYS disable in CI — prevents daemon issues
  # NX_PARALLEL=6 only on self-hosted runner (8 cores)
```

## Permissions — Least Privilege

```yaml
# CI: read-only
permissions:
  actions: read
  contents: read

# Deploy (kubectl patch ArgoCD Applications, no git commits):
permissions:
  actions: read
  contents: read
  deployments: write
  id-token: write  # OIDC auth to Azure

# Docker build+push to GHCR:
permissions:
  contents: read
  packages: write
```

## Self-Hosted Runner Pattern

```yaml
# Start runner VM (parallel with other jobs, no dependencies)
start-runner:
  runs-on: ubuntu-latest
  timeout-minutes: 6
  environment: development  # Required for Azure OIDC secrets
  steps:
    - uses: azure/login@... # OIDC login
    - run: az vm start --name development-acme-runner --resource-group ...

# Main job: self-hosted runner
main:
  needs: [start-runner]
  runs-on: [self-hosted, ubuntu-latest-8-cores]
  timeout-minutes: 30

# Fallback: GitHub-hosted runners (always() — runs even if start-runner fails)
fallback:
  needs: [start-runner]
  if: always() && needs.start-runner.result == 'failure'
  runs-on: ubuntu-latest
```

## Nx Cache Health Check Pattern

```yaml
- name: Verify cache connection
  id: cache-check
  uses: ./.github/actions/nx-cache-check
  with:
    cache-server-url: ${{ vars.NX_CACHE_SERVER_URL }}
    access-token: ${{ secrets.NX_CACHE_READ_TOKEN }}

# Use outputs in subsequent steps
env:
  NX_SELF_HOSTED_REMOTE_CACHE_SERVER: ${{ steps.cache-check.outputs.server-url }}
  NX_SELF_HOSTED_REMOTE_CACHE_ACCESS_TOKEN: ${{ steps.cache-check.outputs.access-token }}
```

## Matrix Strategy for Platform Services

```yaml
strategy:
  matrix:
    service:
      - { dir: gateway, project: platform-gateway, name: gateway }
      - { dir: auth-service, project: platform-auth-service, name: auth-service }
      - { dir: tenant-service, project: platform-tenant-service, name: tenant-service }
      - { dir: user-service, project: platform-user-service, name: user-service }
      - { dir: trading-service, project: platform-trading-service, name: trading-service }
      - { dir: inventory-service, project: platform-inventory-service, name: inventory-service }
      - { dir: accounting-service, project: platform-accounting-service, name: accounting-service }
      - { dir: commission-service, project: platform-commission-service, name: commission-service }
      - { dir: document-service, project: platform-document-service, name: document-service }
      - { dir: notification-service, project: platform-notification-service, name: notification-service }
```

## Deployment Gate Pattern

```yaml
deployment-gate:
  runs-on: ubuntu-latest
  timeout-minutes: 5
  if: >
    github.event_name == 'workflow_dispatch' ||
    (github.event_name == 'workflow_run' && github.event.workflow_run.conclusion == 'success')
  outputs:
    proceed: ${{ steps.gate.outputs.proceed }}
    environment: ${{ steps.resolve.outputs.environment }}
  steps:
    - name: Resolve environment
      id: resolve
      run: |
        if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
          echo "environment=${{ inputs.environment }}" >> "$GITHUB_OUTPUT"
        else
          echo "environment=development" >> "$GITHUB_OUTPUT"
        fi

    - name: Check deployment freeze
      run: |
        if [ "${{ vars.DEPLOYMENT_FREEZE }}" == "true" ]; then
          echo "::error::Deployment freeze is active"
          exit 1
        fi
```

## Composite Action Pattern (existing actions to reuse)

Instead of inlining complex logic, USE these composite actions:
- `.github/actions/setup-node-npm` — Node.js + npm cache
- `.github/actions/docker-build-push` — Docker build + GHCR push
- `.github/actions/container-app-deploy` — Azure Container App deployment
- `.github/actions/azure-login-oidc` — OIDC login to Azure
- `.github/actions/nx-cache-check` — Nx remote cache health check
- `.github/actions/health-check-retry` — HTTP health check with retries
- `.github/actions/staging-smoke-test` — Post-deploy smoke test

## Common Mistakes to Avoid

1. **NEVER use `actions/checkout@v4`** — always SHA-pinned
2. **NEVER set `NX_DAEMON: true` in CI** — causes stuck processes
3. **NEVER use `cancel-in-progress: true` on main branch** — loses CI results
4. **NEVER use `cancel-in-progress: true` on deployments** — can corrupt state
5. **NEVER add `--repo` flag to `gh` CLI** — repo context comes from checkout
6. **NEVER hardcode secrets** — use `${{ secrets.X }}` or `${{ vars.X }}`
7. **NEVER use `npm install` in CI** — use `npm ci` (deterministic)
8. **NEVER skip `filter: tree:0`** on checkout — wastes bandwidth
9. **`workflow_run` only fires from main** — not from feature branches
10. **OIDC requires `id-token: write` permission** — missing it causes silent auth failures
