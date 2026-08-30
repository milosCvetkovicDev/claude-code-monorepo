---
name: launch-readiness
description: 'Run structured 6-area readiness checklist before deploying. Evaluates Code Quality, Security, Performance, Accessibility, Infrastructure, and Documentation. Creates audit trail. Enforced by pre-deploy gate hook.'
---

# Launch Readiness

Run a structured 6-area readiness check before any production deploy. Results create a breadcrumb that the pre-deploy gate hook checks.

## Invocation

Run before deploying: `/launch-readiness [target]`

Where target is: `prod-acme-legacy`, `development`, or `staging` (default: auto-detect from branch).

## Workflow

### Step 1: Detect Changed Files

```bash
# Determine what changed since main
CHANGED=$(git diff --name-only main...HEAD)
HAS_FRONTEND=$(echo "$CHANGED" | grep -c "apps/legacy-web\|apps/domain-web" || true)
HAS_BACKEND=$(echo "$CHANGED" | grep -c "apps/legacy-api\|apps/platform\|libs/" || true)
HAS_INFRA=$(echo "$CHANGED" | grep -c "infra/\|charts/\|.github/" || true)
```

### Step 2: Run 6-Area Check

Load detailed checklist from `.claude/references/review/launch-checklist.md`.

#### Area 1: Code Quality

```bash
nx affected -t lint --base=main
nx affected -t build --base=main
nx affected -t test --base=main
```

- PASS: All commands exit 0
- FAIL: Any command exits non-zero

#### Area 2: Security

```bash
gitleaks detect --source . --no-git
npm audit --production --audit-level=high
```

- PASS: Zero leaks, zero high/critical vulnerabilities
- FAIL: Any leak or vulnerability found

#### Area 3: Performance

- Review changed files for N+1 query patterns
- If frontend changed: check bundle size delta
- PASS: No N+1 patterns, bundle size increase < 50KB
- N/A: No query or frontend changes

#### Area 4: Accessibility

- Only if `HAS_FRONTEND > 0`
- Run axe-core scan on changed components
- PASS: Zero critical/serious violations
- N/A: No frontend changes (backend-only deploy)

#### Area 5: Infrastructure

- Only if `HAS_INFRA > 0`
- Run `terraform validate` if Terraform files changed
- Verify env vars configured in target environment
- PASS: Validation passes, env vars set
- N/A: No infrastructure changes

#### Area 6: Documentation

- Check for ADR if architecture decision detected
- Check API docs if new endpoints added
- PASS: Required docs exist
- N/A: No architectural or API changes

### Step 3: Present Results

```
=== Launch Readiness: {target} ===

1. Code Quality:    ✅ PASS
2. Security:        ✅ PASS
3. Performance:     ✅ PASS
4. Accessibility:   ⬜ N/A (backend-only)
5. Infrastructure:  ✅ PASS
6. Documentation:   ✅ PASS

Result: ALL CHECKS PASSED — deploy authorized
```

Or if any fail:

```
Result: BLOCKED — 1 area failed

❌ Security:
  - npm audit found 2 high vulnerabilities
  - Fix: Run `npm audit fix` or review advisories
```

### Step 4: Create Breadcrumb

On all-pass:

```bash
mkdir -p .claude/
touch .claude/.launch-readiness-passed
```

The pre-deploy gate hook checks for this file. It is cleaned up after deploy or session end.

### Step 5: Save Audit Trail

```bash
mkdir -p .claude/launch-readiness/
# Save results with timestamp
cat > ".claude/launch-readiness/$(date +%Y%m%d)-${target}.md" << EOF
# Launch Readiness: ${target}
Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Branch: $(git branch --show-current)
Result: PASS/FAIL

## Results
{area results}
EOF
```

## Hotfix Path

For critical hotfixes (branch name contains `hotfix/` or `--hotfix` flag):

- Only Code Quality + Security checks required
- Performance, Accessibility, Infrastructure, Documentation show as N/A
- Audit trail notes hotfix exemption

## Force Override

If a check fails but deploy is critical:

1. User must provide `--force` with a reason
2. Reason is logged in audit trail
3. Breadcrumb is created with force flag
4. Follow-up issue should be created for skipped checks

## Hook Enforcement

The pre-deploy gate hook (`.claude/hooks/launch-readiness-gate.sh`) blocks deploy commands unless `.claude/.launch-readiness-passed` exists. See the hook for details.
