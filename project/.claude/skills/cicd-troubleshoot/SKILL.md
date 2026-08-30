---
name: cicd-troubleshoot
description: "Diagnose and fix CI/CD pipeline failures: GitHub Actions, deployment workflows, red main branch, Terraform, and E2E test failures. Use when a workflow run fails or main is red. Do not use for local development issues (use dev-troubleshoot) or code-level bugs (use bug-fix)."
model: sonnet
---

# CI/CD Troubleshooting Workflow

You are diagnosing a CI/CD pipeline failure and guiding the fix.

## Workflow Steps

### Step 1: Identify the Failure

Get recent workflow run status:

```bash
# List recent failed runs
gh run list --status=failure --limit 10

# Or check a specific workflow
gh run list --workflow=ci.yml --limit 5
gh run list --workflow=deploy.yml --limit 5
```

Ask the user:
- Which workflow failed? (CI, Deploy, Terraform, Security, E2E)
- Is this blocking deployment or development?
- Is this on main or a feature branch?

### Step 2: Get Failure Logs

```bash
# View run summary
gh run view <run-id>

# Get failed job logs (most useful)
gh run view <run-id> --log-failed

# If you need a specific job's full logs
gh run view <run-id> --job=<job-id> --log
```

### Step 3: Diagnose by Workflow Type

#### CI Failures (`ci.yml`)

**Common patterns and fixes:**

| Error | Cause | Fix |
|-------|-------|-----|
| `nx affected` returns nothing | Wrong base SHA | Check `NX_BASE` and `NX_HEAD` |
| OOM during frontend tests | Missing sharding | Ensure `--shard` flag is used |
| `Cannot find module` | Missing dependency | Run `npm ci` or check `tsconfig.base.json` paths |
| Type errors | Breaking change in shared lib | Check `@acme/domain-types` changes |
| Lint failures | Formatting | Run `nx run-many -t lint` locally |
| `Nx detected a change in lock file` | Missing `npm ci` step | Ensure setup-node-npm action runs first |

**Quick local reproduction:**
```bash
# Run exactly what CI runs
nx affected -t test --base=origin/main --head=HEAD
nx affected -t lint --base=origin/main --head=HEAD
nx affected -t build --base=origin/main --head=HEAD
```

#### Deploy Failures (`deploy.yml`)

**Common patterns and fixes:**

| Error | Cause | Fix |
|-------|-------|-----|
| `denied: permission_denied` | GHCR auth | Check `packages: write` permission |
| Health check failed | App crash | Check container logs in Azure |
| Slot swap failed | Staging unhealthy | Check `/api/v1/up/ready` endpoint |
| `Resource not accessible` | Missing OIDC | Verify federation config in Azure |
| Deploy skipped | Nx affected says unchanged | Check if dependencies changed |
| Image not found | Build didn't push | Verify docker-build-push step succeeded |

**Deployment slot debugging:**
```bash
# Check production health
curl -s https://api.acme-example.co.uk/api/v1/up/ready

# Check if staging slot is running (it should be stopped normally)
az webapp show --name acme-prod-acme-legacy-backend --slot staging --query state
```

#### Terraform Failures (`terraform-validate.yml` / `terraform-deploy.yml`)

**Common patterns and fixes:**

| Error | Cause | Fix |
|-------|-------|-----|
| `Error acquiring the state lock` | Stale lock | `terraform force-unlock <lock-id>` |
| `Provider produced inconsistent result` | Azure API issue | Retry or `terraform refresh` |
| `Resource already exists` | Resource not in state | `terraform import` |
| `Cycle detected` | Circular dependency | Review module dependencies |
| `Invalid reference` | Typo or missing output | Check module `outputs.tf` |
| OIDC auth failed | Subject claim mismatch | Verify federated credential config |

**Local reproduction:**
```bash
npx nx run infra:validate:<environment>
npx nx run infra:plan:<environment>
```

#### Security Scan Failures (`security-scan.yml`)

**Common patterns and fixes:**

| Error | Cause | Fix |
|-------|-------|-----|
| Gitleaks finding | Secret in code | Add to `.gitleaks.toml` allowlist if false positive, otherwise remove secret |
| npm audit high severity | Vulnerable dependency | Add `overrides` in root `package.json` |
| Trivy critical CVE | Container vulnerability | Update base image or add `.trivyignore` |

#### E2E Test Failures (`e2e-tests.yml`)

**Common patterns and fixes:**

| Error | Cause | Fix |
|-------|-------|-----|
| Strict mode violation | `getByText` matches multiple | Use `getByRole` with name for specificity |
| Timeout waiting for element | Slow render or missing data | Add `waitFor` / increase timeout |
| Network error | API not running | Check test server health |
| Flaky on specific shard | Race condition | Review test isolation |

### Step 4: Apply Fix

Based on diagnosis:

1. **If it's a code issue**: Fix the code, run tests locally, push
2. **If it's a workflow issue**: Use the **github-actions-expert agent** to fix the YAML
3. **If it's an infrastructure issue**: Use the **terraform-expert agent** to fix the config
4. **If it's a flaky test**: Fix test reliability, don't just re-run

### Step 5: Verify Fix

```bash
# Re-run the failed workflow
gh run rerun <run-id>

# Or re-run only failed jobs
gh run rerun <run-id> --failed

# Watch the run
gh run watch <run-id>
```

### Step 6: Document if Novel

If this is a new failure pattern not covered above:
- Update memory files with the pattern and fix
- Consider adding to `infra/CLAUDE.md` lessons learned
- If it was a close call (almost broke production), document in runbook

## Known Project-Specific Issues

### Deploy workflow triggers
- Deploy (`deploy.yml`) triggers via `workflow_run` after CI passes **on main only**
- Feature branch CI success does NOT trigger deploy
- Deploy workflow ID: 000000000

### Concurrency behavior
- CI uses `cancel-in-progress: true` (new pushes cancel old runs)
- Deploy uses `cancel-in-progress: false` (never cancel mid-deploy)

### Nx affected detection
- Uses `NX_BASE` (last successful main commit) and `NX_HEAD` (current)
- If base is wrong, it may build everything or nothing
- Check with: `nx show projects --affected --base=origin/main --head=HEAD`

### Frontend test sharding
- Frontend tests split across 4 shards to avoid OOM
- If one shard fails, `fail-fast: false` lets others complete
- Each shard runs: `nx run legacy-web:test -- --shard=N/4`

## Emergency: Main is Red

If main branch CI is failing:

1. **Don't panic** — deploys won't happen while CI is red
2. Identify the breaking commit: `gh run list --workflow=ci.yml --branch=main --limit 10`
3. Fix forward (preferred) or revert: `git revert <sha>`
4. If deploy already happened before failure was caught, check production health immediately

## Output

Provide a summary including:
- Which workflow/job failed and why
- Root cause analysis
- Fix applied (with file references)
- Verification that fix works
- Whether this is a recurring pattern that needs a systemic fix
