---
name: platform-dlq-reprocess-within-service-grants
description: How to reprocess a Platform RabbitMQ DLQ end-to-end (email/discovery pipeline VERIFIED live) — move via a temp exchange inside the service user's own grants, never the default exchange or admin creds
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000009
---

**Email/discovery pipeline is COMPLETE + verified live (2026-07-18).** The four-layer fix chain
(#1707 auth-service `enableRelay:true` → #1715 relay/reaper tenant-filter `{filters:{tenant:false}}`
→ #1717 consumer forked-EM+TenantContext → #1720 SendDeliveryUseCase per-message-EM finalize) shipped
as notification-service `sha-4f7d771` (PR #1722). Reprocessed the 7 stuck
`notification-service.identity.dlq` messages → **all 7 reached DELIVERED**, DLQ 7→0, events queue 0,
DB `notification.notification_delivery` (template_code=`workspace-discovery`) 1→8 DELIVERED, zero
re-failures, clean logs (`Created … delivery` → `[MOCK EMAIL]` → `SendDeliveryUseCase … sent`).
See [[platform-fail-closed-tenant-filter-forked-em]] (OUTBOX-RELAY variant) and
[[platform-required-config-and-test-gaps]] rule 6.

**LIVE via ACS branded sender + correct URLs (2026-07-19) — DONE.** notification-service runs
`NOTIFICATION_EMAIL_PROVIDER=acs`, sends real inbox-deliverable email from the verified custom sender
**`no-reply@dev.platform.acme-example.co.uk`**, discovery links resolve to `slug.dev.platform.acme-example.co.uk/login`.
The historical diagnosis below (kept for the lessons): "email still doesn't work on dev" had THREE
stacked blocks (live-probed): (1) provider=mock (logs only); (2) the
notification-service egress NetworkPolicy is a **default-deny allow-list** (`platform-comms-notification-service-egress`,
in-cluster infra only) with NO 443 rule → ALL external egress `ETIMEDOUT` (even 443 to microsoft.com);
(3) **Azure blocks outbound port 25** platform-wide. So the earlier **M365-connector-on-25 plan is DEAD**
(the `203.0.113.11`/`email-dns.tf`/accepted-domain approach can't work from this cluster). **Chosen path
= Azure Communication Services (ACS)** — HTTPS/443, no port-25, managed SPF/DKIM/DMARC, provider-neutral
via the `IEmailProvider` port. The ACS code+wiring is ALREADY BUILT on main: `AcsEmailProvider`
(`@azure/communication-email`), fail-closed config schema (`notification.config.ts` superRefine),
comms-bundle ESO `acs-connection-string` entry, count-gated TF `module.platform_acs_email`
(`infra/environments/development-platform`, outputs connection_string+sender_address). **The hidden gap was
the missing 443 egress rule — fixed + LIVE: PR #1735 (`8913a339`) added `0.0.0.0/0 except RFC1918 :443`
to the egress netpol (merged 2026-07-19, verified: pod 443 probe now OPEN, PR #1735).** Go-live DONE
(full runbook `docs/platform/operations/email-delivery-acs.md`): flip `mock→acs` + sender ESO/env = PR #1736;
`PLATFORM_BASE_DOMAIN=dev.platform.acme-example.co.uk` (else discovery links fall back to placeholder
`acme.trade`) = PR #1737. **ACS provisioned via az-bypass (NOT TF — dev-platform `terraform apply` blocked
by the operator var-wall + a RETIRED `development-acme-runner` VM so `runner_identity_principal_id`
can't be derived).** Resources: Communication Service `development-acme-acs-platform` + Email Service
`development-acme-acs-email-platform` (RG `development-acme-rg`), custom domain `dev.platform.acme-example.co.uk`
(CustomerManaged, Domain/SPF/DKIM/DKIM2 all Verified — DNS records on the `acme-example.co.uk` zone in
**SHARED sub `00000000…`, RG `shared-acme-rg`**), sender username `no-reply`. KV `development-acme-kv`
secrets `platform-notification-acs-{connection-string,sender-address}` set MANUALLY. **HAZARD: the
sender secret is manual — if `module.platform_acs_email` is ever enabled + applied, its
`platform_acs_email_sender_address` output is the AzureManaged `donotreply@…azurecomm.net`, which piped to
KV would REGRESS deliverability (M365 quarantines azurecomm.net; the branded domain passes SPF/DKIM →
inbox). Re-set the branded sender after any such apply.** ESO won't restart the Rollout on a KV change
(Reloader ignores Rollouts) — `annotate externalsecret … force-sync` + delete the pod. Verify a send:
inject an `identity.workspace.discovery-requested` DomainEvent (temp-exchange trick above) → log
`[AcsEmailProvider] ACS accepted email (operation <id>)` → `az communication email status get
--operation-id <id>` = `Succeeded`; ACS-Succeeded-but-no-inbox = M365-side (Exchange message-trace/quarantine).
Follow-up: `workspace-discovery` NotificationTemplate row isn't seeded → benign WARN
`No active NotificationTemplate … using nil UUID fallback`; the code-level `renderDiscoveryEmail`
(Claude-Design `discovery-email-template.html`) renders it, so delivery works — seed the row later
for DB-driven overrides.

**DLQ REPROCESS TECHNIQUE (reusable for any Platform BC DLQ).** RabbitMQ = `rabbitmq-0` ns `rabbitmq`,
vhost `acme`. Per-service users are tightly scoped (`rabbitmqctl list_permissions -p acme`):
`notification_user` write = `^(acme\.communication(\..*)?|acme\.audit-feed(\..*)?|notification-service\..*)$`
— so it is **REFUSED write to `acme.identity`** (that's `auth_user`, the producer) **AND refused
write to the default exchange `amq.default`** (403 ACCESS_REFUSED — the empty-name resource matches no
per-service regex). And no single service user can both READ the `notification-service.*` DLQ and
WRITE `acme.identity`. `guest` does not exist; `platform` is the only admin (`.* .* .*`).

**Key enabler: the Platform notification consumer dispatches on the message BODY `event.eventType`, NOT
the AMQP routing key** (`notification-event-consumer.ts` `dispatchEvent`: `ROUTING_KEYS[event.eventType]`).
So a reprocessed message reaches the right handler regardless of what exchange/routing-key you use to
re-inject it — you only need ANY path back into the consumer's queue.

**The move (no admin creds, no default exchange, no message loss)** — run a `node -e` inside the
service's OWN pod using its OWN `RABBITMQ_URI` env (`amqplib` is resolvable in the dist; distroless =
no `sh`/`printenv`, use `/nodejs/bin/node`). Declare a TEMP direct exchange in the service's own
namespace, bind the events queue to it, drain the DLQ through it, tear it down — all within the service
user's configure/write/read grants:

```js
const EX = "notification-service.reprocess",
  RK = "reprocess",
  Q = "notification-service.identity.events",
  DLQ = "notification-service.identity.dlq";
const c = await amqp.connect(process.env.RABBITMQ_URI);
const ch = await c.createConfirmChannel(); // CONFIRM channel — publish-confirm before ack
await ch.assertExchange(EX, "direct", { durable: false });
await ch.bindQueue(Q, EX, RK);
for (;;) {
  const m = await ch.get(DLQ, { noAck: false });
  if (!m) break;
  const h = { ...(m.properties.headers || {}) };
  for (const k of Object.keys(h))
    if (/^x-(death|first-death|last-death|delivery-count)/.test(k)) delete h[k]; // strip DLX headers → looks fresh
  ch.publish(EX, RK, m.content, {
    contentType: "application/json",
    headers: h,
    persistent: true,
  });
  await ch.waitForConfirms();
  await ch.ack(m);
} // ack ONLY after broker confirm → 403/failure leaves msg safe in DLQ
await ch.unbindQueue(Q, EX, RK);
await ch.deleteExchange(EX);
```

Confirm-then-ack is the safety property: if the publish is refused (or anything throws), the `get`
message was never acked → RabbitMQ redelivers it to the DLQ → zero loss. DLQ messages carry routing
key `dead-letter` (rewritten by the queue's `x-dead-letter-routing-key`) and exchange
`<svc>.<bc>.dlx`; the ORIGINAL key lives in `x-death[0]`/`x-first-death-*` headers (irrelevant here
since dispatch is body-driven). Verify after: `rabbitmqctl list_queues -p acme name messages`
(DLQ→0, events→0) + query the delivery DB (statuses) + `kubectl logs` for per-message success and
NO global-EM/tenant-filter/nack lines. Idempotency: the discovery handler counts existing deliveries
by `source_event_id`+`template_code` and SKIPS if present — so check the DB first
(reprocess vs operator `POST /api/v1/deliveries/:id/retry`); here 6-7 of 7 were fresh so reprocess
was correct. Never print `RABBITMQ_URI`/secret values — parse+redact in-process (mirror SSO pod-probe
discipline).
