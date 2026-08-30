---
name: deploy
description: Deploy to Azure development environment with full validation workflow
model: sonnet
---

# Deploy to Development Environment

Guided deployment workflow for the Azure development environment. Validates each step before proceeding.

## Arguments

- `$ARGUMENTS` - Optional: environment name (default: `development`), or specific app to deploy

## Step 1: Pre-Deployment Checks

### Check CI Status

```bash
# Check latest CI run on main
gh run list --branch main --workflow ci.yml --limit 3 --json status,conclusion,displayTitle,createdAt
```

If the latest CI run is not successful, **warn the user** and ask whether to proceed.

### Check for Uncommitted Changes

```bash
git status --short
```

If there are uncommitted changes, warn the user — deployments should be from committed code.

### Check Current Branch

```bash
git branch --show-current
```

Deployments typically happen from `main`. If on a different branch, confirm with the user.

## Step 2: Identify What to Deploy

```bash
# Check which apps are affected
npx nx show projects --affected --base=HEAD~5 --type=app 2>/dev/null
```

Report which apps will be deployed and which will be skipped.

## Step 3: Validate Infrastructure (if infra/ changed)

```bash
# Only if Terraform files changed
git diff HEAD~5 --name-only | grep -q "^infra/" && echo "Infrastructure changes detected"
```

If infrastructure changed:

```bash
npx nx run infra:validate:development
```

## Step 4: Trigger Deployment

### Option A: Deploy via CI/CD (recommended)

```bash
# Check if deploy workflow exists and is enabled
gh workflow view deploy.yml

# Trigger deployment
gh workflow run deploy.yml
```

### Option B: Manual Deploy (if CI/CD is down)

Ask the user which approach they prefer before proceeding.

## Step 5: Monitor Deployment

```bash
# Watch the deployment run
gh run list --workflow deploy.yml --limit 1 --json status,conclusion,databaseId
```

Poll every 30 seconds until complete:

```bash
gh run view <run-id> --json status,conclusion,jobs
```

## Step 6: Health Check

After deployment completes:

```bash
# Check health endpoint (replace with actual URL)
curl --max-time 30 -s -o /dev/null -w "%{http_code}" https://<app-url>/api/v1/up/ready
```

## Step 7: Post-Deployment Verification

Report:

- Deployment status (success/failure)
- Which apps were deployed
- Health check results
- Any warnings or issues

## Critical Rules

- **Never replace Container App env vars** — always use incremental updates or merge
- **Never force-push to main** — deployments come from the main branch
- If a deployment fails, check logs with `gh run view <id> --log-failed` before retrying
- If health checks fail after deployment, check the staging slot first — rollback is instant via slot swap
