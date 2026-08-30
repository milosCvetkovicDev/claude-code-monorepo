---
name: app-insights-telemetry-architecture
description: App Insights telemetry pipeline verified 2026-04-01 — SDK vs Azure Agent, sampling, alert KQL patterns
type: project
originSessionId: 00000000-0000-0000-0000-000000000063
---
## App Insights Telemetry Architecture (Verified 2026-04-01)

**Why:** Commission webhook failures were invisible despite correct alert infrastructure. Investigation revealed multi-layer telemetry gaps.

### Two ingestion paths

| Path | Mechanism | What it captures | Reliable? |
|------|-----------|-----------------|-----------|
| Azure Agent | Auto-injected into App Service, patches console.log | stdout/stderr → traces table | Partial — drops rare structured JSON events |
| SDK (`applicationinsights` v3.14) | Manual `trackTrace`/`trackException` calls | Explicit telemetry → traces/exceptions tables | Yes, but subject to sampling |

### SDK configuration (bootstrap.ts)

- `.setAutoCollectConsole(false)` — SDK does NOT intercept console.log (Azure Agent handles it)
- `.setAutoCollectRequests(false)` — Azure Agent handles HTTP requests
- `.setAutoCollectExceptions(true)` — SDK catches unhandled exceptions
- `samplingPercentage = 25` in production (cost management)
- Custom telemetry processors: pg-boss filter + commission webhook sampling bypass

### Sampling bypass pattern

For rare critical events (commission webhooks — maybe 2x per month), 25% sampling means 75% drop rate. Solution: telemetry processor sets `envelope.sampleRate = 100` for commission webhook envelopes.

### Alert KQL pattern

Commission alerts query BOTH `traces` (for trackTrace) and `exceptions` (for trackException) via KQL `union`. Threshold: `GreaterThan 0` with `summarize count() by dealId` for deduplication.

### App Insights resource

- Name: `prod-acme-appinsights` (NOT `prod-acme-app-insights`)
- Resource group: `prod-acme-rg`
- Retention: 30 days
- Server-side sampling: 100% (no additional server sampling)
- Linked workspace: `DefaultWorkspace-*-SUK` in `DefaultResourceGroup-SUK`

**How to apply:** When adding observability for rare events, always use explicit `trackTrace`/`trackException` + sampling bypass. Never rely on console.log → Azure Agent for alerting.
