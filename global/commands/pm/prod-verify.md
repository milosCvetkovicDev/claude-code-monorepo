---
allowed-tools: Bash, Read, LS
---

# Production Verification

Generate and execute a production verification runbook for a deployed epic.

## Usage
```
/pm:prod-verify <epic_name>
```

## Preflight Checklist

1. **Verify PRD exists:**
   ```bash
   test -f .claude/prds/$ARGUMENTS.md || echo "❌ PRD not found: .claude/prds/$ARGUMENTS.md"
   ```

2. **Verify epic exists:**
   ```bash
   test -d .claude/epics/$ARGUMENTS/ || echo "❌ Epic not found: .claude/epics/$ARGUMENTS/"
   ```

## Instructions

### 1. Read Verification Requirements

Read the PRD from `.claude/prds/$ARGUMENTS.md`:
- Extract the "Production Verification" section
- Extract "Success Criteria" for measurable outcomes
- Extract any stakeholder sign-off requirements

Read the epic from `.claude/epics/$ARGUMENTS/epic.md`:
- Check for production verification task
- Get the technical success criteria

### 2. Generate Verification Runbook

Create a step-by-step checklist tailored to the specific feature:

```markdown
# Production Verification: $ARGUMENTS
Generated: {current datetime}

## 1. Infrastructure Health

Run these checks to verify the deployment is healthy:

- [ ] **Backend health**: `curl -s https://api.acme-example.co.uk/api/v1/up/ready`
  Expected: `{"status":"ready","checks":{"database":"healthy","keyVault":"healthy"}}`

- [ ] **Config check**: `curl -s https://api.acme-example.co.uk/api/v1/up/config`
  Expected: `ENVIRONMENT_NAME=production`, correct `ERP_POSTING_ENABLED` value

- [ ] **Commission API reachable**: Verify VNet routing works via legacy proxy
  Expected: 401/403 (auth working), NOT 503 (unreachable)

## 2. Business Logic Smoke Tests

{Generated from PRD acceptance criteria — specific to this feature}

For each key Gherkin scenario, provide a concrete verification step:
- [ ] **{Scenario name}**: {How to verify in production}
  Call: `{specific API endpoint or UI action}`
  Expected: `{specific response or behavior}`

Example patterns:
- [ ] **List {resources}**: `curl -s -H "Authorization: Bearer $TOKEN" https://api.acme-example.co.uk/api/v1/{resource}`
  Expected: HTTP 200, array of items
- [ ] **Create {resource}**: Test via UI or API that creation works
  Expected: Resource appears in list, correct data
- [ ] **Edge case: {from Gherkin}**: {specific verification}
  Expected: {specific result}

## 3. Monitoring (15 minutes)

After deployment, watch for problems:

- [ ] **Application Insights**: No new exceptions in the last 15 minutes
  Check: Azure Portal → Application Insights → Failures blade
  Or via MCP: `azure_errors` tool with `environment: "production"`, `severity: "error"`

- [ ] **Database health**: No failed migrations, pg-boss queue processing normally
  Check via MCP: `db_status` tool

- [ ] **Deployment status**: All slots healthy, no pending restarts
  Check via MCP: `azure_deployment_status` tool

- [ ] **Response times**: No significant latency increase
  Check: Application Insights → Performance blade

## 4. Stakeholder Sign-off

{If PRD specifies stakeholder requirements}

- [ ] **{Stakeholder name/role}** has verified the feature works as expected
- [ ] Feature demo completed (if required)
- [ ] Any manual testing scenarios passed

## 5. Completion

When all checks pass:
- [ ] Update epic status to `completed`
- [ ] Close the production verification GitHub issue
- [ ] Update PRD status to `complete`

Run: `/pm:epic-close $ARGUMENTS`
```

### 3. Execute Automated Checks (if in Claude Code session)

If running interactively, attempt automated verification:

```bash
# Infrastructure health check
echo "Checking backend health..."
curl -s https://api.acme-example.co.uk/api/v1/up/ready | python3 -m json.tool 2>/dev/null || echo "❌ Health check failed"

echo ""
echo "Checking config..."
curl -s https://api.acme-example.co.uk/api/v1/up/config | python3 -m json.tool 2>/dev/null || echo "❌ Config check failed"
```

If Acme MCP tools are available, use them:
- `health_check` — MCP server health
- `azure_errors` — Check for new errors
- `db_status` — Database connectivity and queue health
- `azure_deployment_status` — Slot health

### 4. Report Results

```
## Production Verification Results: $ARGUMENTS

✅ Infrastructure: All health checks passing
✅ Business Logic: {n}/{total} smoke tests passed
✅ Monitoring: No new errors in 15 minutes
⬜ Stakeholder Sign-off: Pending

{If all pass}:
✅ Production verification complete for: $ARGUMENTS
Next: /pm:epic-close $ARGUMENTS

{If any fail}:
❌ Production verification FAILED
  - {what failed}: {details}
  - Action required: {specific fix or rollback instruction}
  - Rollback: Azure slot swap via CI/CD or manual `azure_slot_swap` MCP tool
```

## Error Handling

If PRD has no "Production Verification" section:
```
⚠️ No production verification section in PRD.
Generating basic verification from acceptance criteria...
{Fall back to generating checks from Gherkin scenarios + standard health checks}
```

If health check endpoint is unreachable:
```
❌ Cannot reach production endpoint
  - Check: Is the deployment complete?
  - Check: Is there a network issue?
  - Action: Verify deployment status first, then retry
```

## Agent Skill Integration

Use `agent-skills:shipping-and-launch` for pre-launch checklist, monitoring setup, and rollback planning.
