# Application Insights Queries

## Azure CLI

```bash
AI_RESOURCE="appi-acme-prod-sp-uks-001"
RESOURCE_GROUP="rg-acme-prod-uks"

az monitor app-insights query \
  --app "$AI_RESOURCE" \
  --resource-group "$RESOURCE_GROUP" \
  --analytics-query '<KQL query>'
```

## KQL Queries

### Recent Errors

```kql
exceptions
| where timestamp > ago(1h)
| project timestamp, type, outerMessage, operation_Name, customDimensions
| order by timestamp desc
```

### Failed API Requests

```kql
requests
| where timestamp > ago(1h)
| where success == false
| project timestamp, name, resultCode, duration, customDimensions
| order by timestamp desc
```

### ERP Integration Errors

```kql
traces
| where timestamp > ago(24h)
| where message contains "ERP"
| where severityLevel >= 3
| order by timestamp desc
```

### Traces by Severity

```kql
trace
| where timestamp > ago(1h)
| where severityLevel >= 3
| project timestamp, message, severityLevel, operation_Name, customDimensions
| order by timestamp desc
| take 50
```
