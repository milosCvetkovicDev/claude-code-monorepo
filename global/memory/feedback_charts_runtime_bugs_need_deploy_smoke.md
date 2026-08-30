---
name: feedback_charts_runtime_bugs_need_deploy_smoke
description: Charts/observability PRs pass every static gate yet hide runtime config bugs — deploy + smoke before claiming they work
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

A Platform charts-only PR (#1142, 2C exporter scraper for #1135 SC-2) passed **every** static gate — helm-unittest, helm-template-strict, grafana-alert-rules-guard, Validate Terraform, ci-gate — and an adversarial expert review rated it "approve-with-nits, 0 real high/critical". On deploy it had **four** runtime bugs, each invisible to static checks:

1. **OTel collector invalid key** — `prometheusremotewrite` exporter used `sending_queue` (generic exporterhelper key); the PRW exporter wants `remote_write_queue`. CrashLoopBackOff. Fixed #1157.
2. **NetworkPolicy egress port** — allowed the mimir-gateway **service** port `:80`, but NP egress matches the **destination POD port after kube-proxy DNAT** = `:8080`. Every push blackholed (`context deadline exceeded`). Fixed #1158. (The four scrape ports happened to match svc=pod, so scrapes worked — only the DNAT-remapped push broke.)
3. **az-cli container `/.azure` not writable** — runs non-root with `HOME=/`. Needs `AZURE_CONFIG_DIR=/tmp/.azure`. (#1159)
4. **No Workload Identity** — `az login --identity` → MSI 400; SA had no `azure.workload.identity/client-id` annotation, pod no `use:true` label, no UAMI/federation/grant. (#1159)

**Why:** Use this to remember to ALWAYS deploy + smoke-test an observability/charts PR (run the collector's own `validate`, check pod logs for export errors, confirm the metric series actually lands in Mimir, run any CronJob and read its logs) before declaring it works. Static gates and even adversarial review validate YAML/structure/semantics-on-paper, never the live runtime.

**How to apply:** For any metrics/scraper/alert PR: (a) `docker run otel-collector-contrib:<ver> validate --config=<extracted>`; (b) after deploy, `kubectl logs <scraper> | grep -i error|drop`; (c) query Mimir `count(<metric>)` before claiming a detector is live; (d) for NP egress to a Service, set the port to the **pod containerPort** (check `svc -o jsonpath targetPort`), not the service port; (e) run CronJobs once and read logs (perms/identity). The dead-detector wiring is now live (ESO/argocd/rmq series in Mimir); kv-imminent-expiry detector works but its CronJob producer is inert until #1159 — the rule evaluates, nothing feeds it, so it reads as permanently healthy. Relates to the #669/SC-2 chaos verification that surfaced all four.
