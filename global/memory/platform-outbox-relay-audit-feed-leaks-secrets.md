---
name: platform-outbox-relay-audit-feed-leaks-secrets
description: "OutboxRelay dual-publishes every payload verbatim to acme.audit-feed → audit-service persists it to audit_entry.new_state; raw secrets (invite/reset tokens) in an event payload leak at-rest, defeating"
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000009
---

The Platform transactional OutboxRelay (`libs/platform/event-bus/src/lib/outbox-relay.ts`)
dual-publishes EVERY relayed row's payload buffer to BOTH the BC topic exchange
(`acme.{bc}`) AND the `acme.audit-feed` fanout (ADR-0026). `audit-service`
(`audit/infrastructure/audit-event.consumer.ts`) writes the inner payload
**verbatim** into `audit_entry.new_state` (NOT-NULL jsonb) — there is NO field
redaction anywhere on the relay or audit path.

**Consequence:** any raw secret carried in a domain-event payload (e.g. the RAW
invitation accept token in `platform.user.invited`, a password-reset token) lands
unredacted, at rest, in the **platform-wide** audit store (audit-feed is a fanout;
one DB holds all tenants' events). A DBA / operator / log-shipper with SELECT on
audit can read the bearer token and, within its TTL, take over the account
(`POST /invitations/accept {token,password}` → ACTIVE user with the invited role;
for `platform.tenant.created` that role is ADMIN). This directly defeats the
#1271 Gap-C control ("a DB read never exposes a usable token").

**Why:** found by the maker≠checker security review of the first-admin invite
pipeline when we flipped `enableRelay: true` on user-service. The relay flip is
docs-correct (identity-platform.md L304: `platform.user.invited` → notification
sends email) BUT ships this leak unless the token is kept off the audit lane.

**FIXED (PR #1755, merged `cf4c224`):** `OutboxRelayConfig.auditSecretFields` — an
OFF-BY-DEFAULT per-eventType denylist of dotted payload paths, stripped from the
`AUDIT_FEED_EXCHANGE` copy ONLY (BC lane keeps them, the legit consumer needs them).
`buildAuditBuffer` deep-clones + `deleteAtPath`; empty config → returns the original
buffer byte-identical (no clone). Threads via `eventBus.relay` (ServiceModule →
EventBusModule → `{...options.relay}` → `new OutboxRelay`). user-service declares
`{ 'platform.user.invited': ['payload.token'] }`; only the declaring relay is affected.

**How to apply to a future secret-bearing event:**

- Add `eventType → ['payload.<field>']` to that service's `eventBus.relay.auditSecretFields`.
- ALSO scrub at the delivery sink: the notification handler redacts the token from
  `notification_delivery.body_rendered`/`context_data` AFTER a DELIVERED send
  (`NotificationDelivery.redactRenderedSecret`); a FAILED send keeps it for retry.
- Remaining at-rest residuals (bounded, tracked): outbox PUBLISHED row payload =
  **#1756 (M1)**; notification DLQ on DB-error redelivery = **#1757 (M2)**; DLX
  `x-acme-original-payload` header (can't fire for v1 invites). Strategic umbrella:
  converge on auth's "no secret travels in outbox events" (token reference, mint OOB).

Related: [[platform-1271-token-revocation-epic]], [[platform-tenant-provisioning-epic]],
[[platform-dlq-reprocess-within-service-grants]] (notification email pipeline),
[[platform-reconnect-consumer-helper-hardened]].
