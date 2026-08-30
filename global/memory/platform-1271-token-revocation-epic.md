---
name: platform-1271-token-revocation-epic
description: Platform #1271 AC2 token-revocation — ratified design (P1-P5) + stacked-PR rollout state; read before any revocation/denylist work
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000009
---

**DONE** (closed out 2026-06-18; epic ran 2026-06-17→18): #1271 AC2 — replaced the gateway's mock token-revocation with a real Redis denylist across 5 stacked PRs (#1323/#1324/#1326/#1327/#1329, all merged). Design ratified by a 4-lens expert panel (security/redis/k8s/perf), all evidence-checked against `origin/main`. Remaining = operator/follow-up items only (see end).

**Ratified decisions:**

- **P1 topology** — there is ONE shared Azure Cache for Redis (Basic/Standard); the 9 Platform services are separated only by logical DB index (`infra/modules/platform-key-vault-secrets/locals.tf` `redis_url_template ...:6380/%d`; gateway=DB0, auth=DB1), all sharing the instance-wide key. **Azure Cache Basic/Standard has NO Redis ACLs (Enterprise-tier only)** and `SELECT <db>` is not a security boundary → the revocation keyspace lives on **DB 0**: auth WRITES via a new `REVOCATION_REDIS_URL`; gateway READS via a read-only adapter (only `isRevoked`). Adds zero blast radius (gateway already holds the instance key). True least-privilege (ACL cred scoped to `revoked:*`) = a **Premium-SKU follow-up**, not a blocker.
- **P2 TTL** — keep access-token TTL **900s** (matches denylist entry TTL exactly → no prune-gap); make the revocation WRITE durable+observable (log `revocation_write_failed`, non-fatal — Postgres is authoritative).
- **P5 MFA force-logout** — enable=no; disable/secret-reset/recovery-regen=yes. Implemented as "revoke the user's OTHER active sessions, keep the current one" so verify-and-enable can complete (a refinement of the panel's "revoke all"). Standalone MFA-disable endpoint doesn't exist yet → deferred (needs step-up-auth design).
- Dual-key denylist: `revoked:jti:{jti}` (single token) + `revoked:session:{sessionId}` (bulk), checked together in one gateway pipeline; keys from `@acme/platform-contracts` (`revokedJtiKey`/`revokedSessionKey`). Gateway guard is fail-CLOSED on read (503); auth WRITE is best-effort after the PG revoke commits.

**Rollout (stacked PRs, each built via build→4-lens-review→verify Workflow):**

- PR1 #1323 gateway READ path — **MERGED** `ad30ad30d`.
- PR2 #1324 auth WRITE path (IRevocationStore + DB-0 adapter, wired into logout/session/reset/refresh-reuse) — **MERGED** `0f2be250e`.
- PR3 #1326 MFA force-logout + `findActiveByTenantId` + tenant-suspend — **MERGED** `ce4379adc` (recovered a stacked-overlap conflict via local `git merge -X ours` — update-branch only collapses when parent/child touch disjoint files).
- PR4 #1327 infra TF `platform-revocation-redis-url` KV secret (DB 0) + auth chart wiring + auth.config prod/staging fail-fast — **MERGED** `5c66f9217`. Operator step PENDING: provision the KV secret out-of-band (`az keyvault secret set`) BEFORE the chart syncs, else ESO can't resolve it and auth fails closed (like #1292).
- PR5 #1329 cross-service e2e (real auth write-adapter + gateway read-service over ONE shared in-memory Redis, real use-cases, both-direction asserts) + **repaired the gateway `full-auth-flow.integration.spec.ts` rot** + **repinned the identity-bundle auth rmq env indices** — **MERGED** `f3693e4b` (2026-06-18). The rot: PR2/PR3 inserted ctor args (revocationStore/accessTtl) + `findActiveByTenantId`, shifting the gateway spec's in-memory wiring → 9 RED on main, invisible because the gateway suite only runs when gateway is nx-affected. **LESSON: run `nx test:unit platform-gateway` after ANY auth-service ctor/port change** ([[platform-gateway-integration-suite-rots-undetected]]).
- **helm-index follow-up (folded into PR5):** PR4's REVOCATION_REDIS_URL env insertion repinned the `charts/platform-base/tests/rmq-credential-model_test.yaml` auth indices 6/7→7/8 but MISSED the sibling `charts/bundles/identity-bundle/tests/06-rmq-credential-model_test.yaml` → helm-unittest RED on main (only caught because PR5 re-ran the gate). **LESSON: an auth env-list edit must repin BOTH rmq-credential-model tests (platform-base AND identity-bundle); tenant/user indices stay 6/7 since the new var is auth-only.** Verified locally `helm unittest identity-bundle` 53/53 (plugin v0.7.2).

**Expert-reviewed** (9-lens panel + adversarial verify): only 2 real findings across #1326/#1327 (0.0.0.0/[::] missing from the config fail-fast; a missing test assertion) — both fixed pre-merge. **AC2 DONE** (all 5 PRs merged 2026-06-18); only non-code items left = operator KV provisioning of `platform-revocation-redis-url` (before any prod deploy, like #1292) + the Premium-SKU ACL hardening + standalone MFA-disable endpoint (needs step-up-auth).

CI: `main`/`ci-gate`/`Validate Terraform` green; only the env gateway-image Trivy → `platform-ci-gate` red (admin-mergeable). See [[platform-identity-epic-prep]], [[feedback_stacked_pr_retarget_no_force_push]], [[platform-internal-api-secret-provisioning-pending]].
