---
name: incident
description: 'Respond to a production incident: assess severity, investigate root cause, coordinate fix, and document resolution. Use when production is impacted and the user needs structured incident response. Do not use for non-production bugs (use bug-fix) or planned maintenance.'
model: sonnet
disable-model-invocation: true
---

# Incident Response Workflow

You are orchestrating incident response for a production issue.

## Workflow Steps

### Step 1: Initial Triage

Use the **incident-responder agent** to:

- Assess severity (P1/P2/P3/P4)
- Check service health endpoints
- Review recent deployments
- Identify affected users/features

**Immediate health checks:**

```bash
# Production health
curl -s https://api.acme-example.co.uk/api/v1/up/ready

# Recent deployments
gh run list --workflow=deploy.yml --limit=5
```

### Step 2: Diagnosis

Continue with **incident-responder agent** to:

- Analyze error patterns
- Check Azure logs and Application Insights
- Review pg-boss job status if background jobs affected
- Identify root cause

### Step 3: Mitigation

Based on severity and root cause:

**If deployment caused the issue:**

```bash
# Instant rollback via slot swap (< 1 minute)
az webapp deployment slot swap \
    --name legacy-api-prod \
    --resource-group prod-acme-rg \
    --slot staging \
    --target-slot production
```

**If code fix needed:**

- Implement fix following project conventions
- Fast-track through minimal review
- Deploy via CI/CD pipeline

### Step 4: DevOps Review

Use the **review-devops-architect agent** to verify:

- Fix doesn't introduce new risks
- Deployment is safe
- Monitoring will catch recurrence

### Step 5: Documentation

Use the **documentation-writer agent** to create incident report:

Location: `docs/runbooks/incidents/YYYY-MM-DD-incident-{name}.md`

Include:

- Timeline of events
- Root cause analysis
- Resolution steps
- Lessons learned
- Action items

### Step 6: Follow-up

- Create tasks for preventive measures
- Schedule post-mortem if P1/P2
- Update runbooks if new failure mode discovered

## Severity Guidelines

| Level | Description | Response |
| ----- | ---------------------------- | -------------------- |
| P1    | Service down, data loss risk | Immediate, all hands |
| P2    | Major feature broken | < 1 hour response |
| P3    | Minor feature affected | < 4 hours response |
| P4    | Cosmetic/minor | Next business day |

## Output

Provide:

- Incident severity and status
- Root cause summary
- Resolution steps taken
- Incident report (for P1/P2)
- Follow-up action items

---

## Platform Incident Response (Kubernetes + Grafana)

**Detection:** If the affected service is under `apps/platform/`, use Platform diagnostics.

### Grafana Observability

- **Logs**: Grafana → Explore → Loki: `{service="{service}"} |= "error"`
- **Traces**: Grafana → Explore → Tempo: search by `correlation_id` or `trace_id`
- **Metrics**: Grafana → Dashboard → Service Overview

### Kubernetes Diagnostics

```bash
kubectl get pods -n platform-{bc} -l app={service}
kubectl logs -f {pod} -n platform-{bc} --tail=100
kubectl describe pod {pod} -n platform-{bc}
kubectl top pod -n platform-{bc}
```

### RabbitMQ Diagnostics

```bash
# Queue depth (high = consumers lagging)
rabbitmqadmin list queues name messages consumers
# Dead letter queues (failed messages)
rabbitmqadmin list queues name messages | grep dlq
```

### Redis Diagnostics

```bash
redis-cli INFO memory | grep used_memory_human
redis-cli INFO stats | grep keyspace
```

### Rollback

```bash
argocd app rollback platform-{service} {revision}
```

See `incident-responder` agent for full K8s troubleshooting guide and common issue table.
