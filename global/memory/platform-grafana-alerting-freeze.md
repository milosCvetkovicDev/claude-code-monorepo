---
name: platform-grafana-alerting-freeze
description: The Platform dev Grafana alerting layer was frozen+false-firing by a 3-layer cascade (fixed 2026-06-05); reload mechanics + the dead-detector gap
metadata: 
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000008
---

The dev-platform Grafana alerting layer (`development-acme-aks`, ns `monitoring`, datasource `uid=mimir`) was **100% non-functional** — all 50 SLO rules `health=error` + permanently `firing` — uncovered + fixed during #669 invasive verification (2026-06-05). A 3-layer cascade, each masking the next:

1. **#1129** — `platform-base` `allow-ingress` NetworkPolicy only let the `monitoring` ns reach port **9464** (metrics), not the app/health port, so the #1124 blackbox `/health` probes were SYN-dropped → all 13 `probe_success=0` (false "everything down"). Fix: least-privilege ingress rule (blackbox-exporter pod → `.Values.service.port`).
2. **#1133** — every rule's threshold node (`refId C`, `__expr__`, `type: threshold`) was **missing `expression: A`** → Grafana 12.3.1 SSE parser failed all 50 (`[sse.parseError] ... no variable specified to reference for refId C`). Because **`execErrState` defaults to `Alerting`**, a parse error FIRES the business alert. Fix: add `expression: A` + `execErrState: Error` + `noDataState: OK` to all 50 (`charts/infrastructure/grafana-provisioning/files/alerts.yaml`).
3. **#1136 + #1137** — the fix above couldn't load because **Grafana alerting provisioning reload is ATOMIC across all files**, and `notifications.yaml`'s Slack contact point was invalid (field was `channel:` not `recipient:`, and chat-API mode also needs a `token` when the webhook URL env is empty). So **every** `/api/admin/provisioning/alerting/reload` returned **HTTP 500**, freezing all rules on their old broken definitions. Fix (per "we're not using Slack"): made `platform-oncall` **email-only → me@initech.example** (removed Slack + PagerDuty — both unconfigured in dev).

**Result (verified):** reload HTTP 200 → 50 rules `ok` + `inactive`, **0 active alerts** (was 50). [[feedback_fix_source_not_alert]] in action.

## Non-obvious mechanics (durable)
- **Reload is atomic** — one invalid contact point in `notifications.yaml` 500s the whole alerting reload and freezes EVERY rule. Validate contact points before touching alert rules.
- **The `grafana-sc-alerts` sidecar's WATCH-reload is unreliable** (inotify-miss on the ConfigMap symlink swap). After a CM change, the rules often DON'T re-provision on their own → trigger `POST http://<user>:<pass>@localhost:3000/api/admin/provisioning/alerting/reload` from the grafana container (classifier-gated: needs user OK), or restart Grafana.
- **`charts/infrastructure/grafana-provisioning` IS an ArgoCD-synced app** (auto-sync+selfHeal) — alert/notification changes deploy via merge→sync→sidecar; not inert.
- **Dev alerting is Grafana-UI-only (decided 2026-06-05). DO NOT re-attempt SMTP/email delivery.** Outbound **SMTP (:587/:25) is platform-blocked** from the dev-platform AKS pods to **every** relay — `smtp.azurecomm.net`, `smtp.office365.com`, `smtp.sendgrid.net`, `smtp-relay.gmail.com` all TIME OUT — while HTTPS (:443) egress works fine (a public DNS resolver, `login.microsoftonline.com`, `api.sendgrid.com`, `global.communication.azure.com` all reachable). This is Azure's outbound-SMTP restriction (standard on Sponsorship/non-EA subs, not liftable). Grafana's email notifier is SMTP-only → **email-via-Grafana is impossible here**; ACS SMTP (smtp.azurecomm.net, Entra-app auth) is a dead path. Any future delivery must be an **HTTPS webhook** channel (Teams Workflow webhook / Logic App→ACS-REST / Function). The org's ACS Email (`infra/modules/communication-services`, single shared `shared-acme-communication-service` in Sub 1, sender `dev.info@acme-example.co.uk`) is **REST/:443**, not reachable via SMTP. `platform-oncall` keeps an email contact point (won't deliver; documents intent) but alerts live in the Grafana UI.

## ⚠️ Bigger open gap — #1135
Even post-fix, **~47 of 50 rules are dead detectors**: their metrics aren't emitted to this Mimir (only the 4 blackbox jobs write to it). `http_server_request_duration_seconds_count` (all 40 RED/burn-rate + AnalysisTemplate), `externalsecret_status_condition`, `argocd_app_info`, `rabbitmq_queue_messages`, `k8s_*`, `time_to_expiry_days` — all absent. Only the 2 `probe_success` blackbox rules work. `platform-service-down` watches `up{job=~"platform-.*"}` which only matches blackbox scrape-health, never the services. **SC-2 is NOT met** until the OTLP app-metrics + exporter pipelines are wired (#1135, Layer-2).
