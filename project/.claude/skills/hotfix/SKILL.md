---
name: hotfix
description: "Fast-track a critical production fix through the P1/P2 deployment pipeline. Use when production is broken and the user needs an urgent fix bypassing normal review cycles. Do not use for non-critical bugs (use bug-fix) or planned deployments."
model: sonnet
---

# Hotfix Workflow

You are orchestrating an **urgent production fix** with streamlined process.

**USE THIS ONLY FOR:**
- P1: Service down, data at risk
- P2: Major feature broken

For non-urgent bugs, use `/bug-fix` instead.

## Workflow Steps

### Step 1: Confirm Severity
Before proceeding, confirm this is truly urgent:
- [ ] Production is affected (not just dev)
- [ ] Users are impacted NOW
- [ ] Cannot wait for normal release cycle

**If not urgent, STOP and use `/bug-fix` instead.**

### Step 2: Quick Investigation
Rapidly identify the issue:
```bash
# Check recent deployments
gh run list --workflow=deploy.yml --limit=5

# Check production health
curl -s https://api.acme-example.co.uk/api/v1/up/ready
```

- What changed recently? (deployment, config, external service)
- Can we rollback immediately?

### Step 3: Decide: Rollback or Fix Forward?

**Rollback (Preferred if possible):**
```bash
# Instant rollback via slot swap (< 1 minute)
az webapp deployment slot swap \
    --name legacy-api-prod \
    --resource-group prod-acme-rg \
    --slot staging \
    --target-slot production
```
If rollback resolves the issue, document and create follow-up ticket.

**Fix Forward (If rollback won't help):**
Continue to Step 4.

### Step 4: Minimal Fix
Implement the **smallest possible fix**:
- Fix ONLY the immediate issue
- No refactoring
- No "while we're here" improvements
- No new features

```typescript
// GOOD - Minimal fix
if (value === null) {
    return defaultValue;  // Handle null case that was crashing
}

// BAD - Scope creep
if (value === null) {
    logger.warn('Null value detected', { context });  // Added logging
    metrics.increment('null_values');  // Added metrics
    return this.computeDefaultValue();  // Refactored default logic
}
```

### Step 5: Quick Test
Run focused tests only:
```bash
# Test the specific fix
nx run legacy-api:test -- --testPathPattern="affected-file"

# Quick smoke test
nx run legacy-api:test -- --testPathPattern="critical"
```

### Step 6: Fast Review
Get **one quick review** from available team member:
- Focus on: Does it fix the issue? Does it break anything else?
- Skip: Code style, naming, minor improvements
- Document any shortcuts for follow-up

### Step 7: Deploy
Deploy via normal CI/CD (uses deployment slots for safety):
```bash
# Push to main triggers deploy
git push origin main

# Monitor deployment
gh run watch
```

### Step 8: Verify Production
```bash
# Check health
curl -s https://api.acme-example.co.uk/api/v1/up/ready

# Monitor for 10-15 minutes
# Watch Application Insights for errors
```

### Step 9: Document
Create incident report using **incident-responder agent**:
- Timeline of events
- Root cause
- Fix applied
- Follow-up items (proper fix, tests, etc.)

## Post-Hotfix Required Actions
- [ ] Create ticket for proper fix (if hotfix was a workaround)
- [ ] Add missing tests
- [ ] Update runbooks if new failure mode
- [ ] Schedule post-mortem for P1 incidents

## What NOT to Do
- ❌ Don't skip deployment slots (they enable instant rollback)
- ❌ Don't deploy directly to production
- ❌ Don't make unrelated changes
- ❌ Don't skip the incident report

## Output
Provide:
- Issue summary
- Fix applied (with code diff)
- Deployment confirmation
- Production verification
- Follow-up tickets created
