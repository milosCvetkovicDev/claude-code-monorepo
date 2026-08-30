---
name: appinsights-daily-cap-prod
description: an Application Insights daily data cap silently blackholes telemetry until midnight UTC — SDK sampling cannot beat it, and the right place to verify is the linked Log Analytics workspace
type: project
originSessionId: 00000000-0000-0000-0000-000000000055
---

A classic Application Insights component (ingestion mode `LogAnalytics`) can carry a daily data cap configured as `DataVolumeCap.Cap` on `CurrentBillingFeatures`. Once a day's workspace ingestion crosses it, AI **silently drops everything until midnight UTC** — no error surface, no failed request, just an absence. The failure is worst on deploy days, because those are the days that ingest most and the days you most want telemetry.

The trap is what the absence looks like downstream: a nightly job's completion heartbeat is a trace like any other, so on a capped day it never lands, and any verification built on "did the heartbeat arrive?" reports a broken job when the job ran fine. A cap turns every telemetry-based check into a check of the cap.

The fix is to raise the cap in the API and then align Terraform in the same change (the variable defaults to the lower value, so a live `az rest PUT` alone drifts back on the next apply).

## Why sampling does not help

Bypass-sampling logic for a specific event category lives in the app's telemetry bootstrap and runs **inside the SDK**. The daily cap is enforced **server-side at AI ingestion**. Once the cap is hit, nothing the SDK marks as unsampleable survives — the decision has already been taken upstream of the cap. Only raising the cap (or reducing total volume) fixes it.

The corollary for volume management: sampling reduction compounds and cap raises do not, so if usage keeps climbing toward the new ceiling the next lever is a lower sampling rate or a filter on the noisiest dependency class, not another raise. Raise the cap on the environment that needs it, not in the shared module default.

## How to apply

When investigating a suspected "telemetry blackhole", **don't query through the AI Component API** (`az monitor app-insights query`) — it has been unreliable against capped workspaces. Query the linked Log Analytics workspace directly:

```bash
WS="00000000-0000-0000-0000-000000000003"  # workspace customerId
# Daily billable ingestion — compare against the cap
az monitor log-analytics query --workspace "$WS" \
  --analytics-query 'Usage | where TimeGenerated > ago(7d) | where IsBillable == true | summarize gb=sum(Quantity)/1024 by bin(TimeGenerated, 1d) | order by TimeGenerated desc' \
  --output table

# Is the heartbeat landing? (it lands in AppTraces, NOT AppEvents)
az monitor log-analytics query --workspace "$WS" \
  --analytics-query 'AppTraces | where TimeGenerated > ago(7d) | where Properties.category == "<CATEGORY>" | summarize cnt=count(), lastT=max(TimeGenerated) by tostring(Properties.event_type)' \
  --output table

# Which table is eating the volume?
az monitor log-analytics query --workspace "$WS" \
  --analytics-query 'Usage | where TimeGenerated > ago(2d) | where IsBillable == true | summarize gb=sum(Quantity)/1024 by DataType | order by gb desc' \
  --output table

# Cap state
az rest --method get \
  --url "https://management.azure.com/subscriptions/<sub>/resourceGroups/<rg>/providers/microsoft.insights/components/<component>/CurrentBillingFeatures?api-version=2015-05-01"
```

The volume query is the one that decides the next action: dependency telemetry is usually the top contributor by an order of magnitude, and a filter on noisy polling calls (queue pollers especially) buys more headroom than any cap change.

## Critical: AppTraces vs AppEvents

These are different tables in Log Analytics. Don't confuse them:

- **`AppTraces`** ← `trackTrace()` calls. Most backend telemetry lands here, including anything logged with a `category` property.
- **`AppEvents`** ← `trackEvent()` calls. A codebase may have very few callers, so an empty `AppEvents` is often expected — not a bug.

If an investigation finds `AppEvents` empty, confirm whether a caller has actually been merged and deployed before assuming a telemetry problem. "The table is empty" and "the pipeline is broken" are different claims, and only one of them is worth an incident.
