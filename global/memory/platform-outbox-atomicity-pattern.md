---
name: platform-outbox-atomicity-pattern
description: Platform identity-service transactional-outbox convention — thread caller EM through em.transactional; the
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000052
---

Platform identity services (tenant, user) now use a **fully-atomic transactional
outbox**: every domain write + outbox publish runs inside ONE
`em.transactional(async (em) => { await repo.save(entity, em); await publisher.publish(event, em); })`.

**Binding convention (follow for any new outbox write path):**

- `IEventPublisher.publish(event, em)` — the `EntityManager` is REQUIRED. The
  `OutboxEventPublisherAdapter` only `em.persist(entry)` — it NEVER forks or
  flushes. The caller's transaction owns the commit. Mirrors the shared
  `@acme/event-bus` `EventPublisher.publish(em, event)`.
- Repo read+write methods take an optional `callerEm?: EntityManager`; `const em
= callerEm ?? this.em; em.persist(x); if (!callerEm) await em.flush();`. The
  READ (`findById`/`findByEmail`/`findByToken`) must also accept `em` so the
  loaded entity is in the same UoW it's later saved from (MikroORM identity-map:
  an entity loaded on em A then persisted on tx-fork em B would INSERT/throw).
- Orchestrators (use-cases/services/crons/processors) inject `EntityManager` and
  wrap the flow. Crons/processors wrap each standalone publish too (trivially
  atomic). Pre-existing accepted coupling: EM crosses into domain ports as the
  transaction handle (same as the shared EventPublisher) — don't fight it.
- The typed wrapper publishers (`TenantEventPublisher`/`UserEventPublisher`)
  thread `em` through to the underlying publisher.

**Why:** the bespoke adapter forked + flushed independently, so a crash between
the domain commit and the outbox flush durably committed the state change but
LOST the event. Surfaced by epic-review of #1260; user chose "full atomicity
everywhere" (durable, no short-term fix) — see [[feedback_align_initech_epic_scope]].

**The review-hardening PRs (epic #1247 M2 identity):**

- **#1260** (tenant, `feat/platform-1247-tenant-real-infra-2`): 3 capstone commits +
  3 review-fix commits — (#2) atomicity, (#1) wire DB-backed SUPERADMIN audit
  (`AUDIT_LOG_REPOSITORY` → `MikroOrmSuperadminAuditRepository`, dropped the
  restart-volatile ring buffer), (#3) migrator-execution tc spec + Migration_003
  hardening (align `idx_outbox_pending` to the entity's plain composite, `IF NOT
EXISTS` guards, `created_at DEFAULT now()`, `down()` drops table not shared
  schema). 244 tests green. All 3 required checks PASS.
- **#1262** (user, `fix/platform-1247-user-outbox-atomicity`): (#2) atomicity + (#3)
  migrator tc spec. 181 unit + 77 integration green. (#1 is tenant-only — user's
  `SuperadminAuditService` is a pre-existing M1 ring-buffer scaffold with NO
  built-but-unwired DB repo, so nothing to wire.)

**#3 detail:** tc `setup.ts` builds schema via `createSchema()` (entity metadata),
NOT the migrator — so hand-written migrations were untested. The new
`migrations.tc.spec.ts` runs `getMigrator().up()` (via `migrations.migrationsList`
with imported migration classes) and asserts the real schema. `to_regclass('identity.user')`
returns `identity."user"` (reserved word, quoted) — assert truthiness, not exact string.

Review method: 6-dimension adversarial workflow on the #1260 diff → 31 raw → 16
confirmed (15 refuted). See [[platform-testing-harness-epic]], [[platform-dev-stabilization-epic]].

**platform_outbox is a SHARED schema/table in the shared `platform` DB** (@acme/
event-bus pins `@Entity({ schema: 'platform_outbox' })`), so EVERY outbox service
runs the same migration DDL against ONE schema. `platform-pg-bootstrap` (per-service
schemas only) never provisioned it → whichever service migrated FIRST owned the
schema+table, others failed (auth-service Migration_002): first `permission
denied for schema platform_outbox`, then after the schema grant `must be owner of
table outbox_entry` on `CREATE INDEX` — **PG checks table OWNERSHIP before `IF NOT
EXISTS`; DML grants are NOT enough**. **Durable fix (PRs #1332→#1334→#1335, on
`main` 2026-06-19):** a NOLOGIN group role `platform_outbox` OWNS the schema + every
table/sequence; all service roles are members → any service runs the shared-table
DDL as the group owner. 3-step bootstrap order: (1) create group+schema; (2) loop
— admin `GRANT <role> TO CURRENT_USER` (portable, not azure_pg_admin) + role joins
group + default-privs; (3) reconcile — `ALTER SCHEMA/TABLE/SEQUENCE OWNER TO
group` (admin must join roles BEFORE reassigning, else "must be owner"). **Lessons:**
(1) verify DB-grant SQL against real PG16 (docker) modelling the FULL migration
run by 2 services — greenfield-only testing missed the reconcile-order +
table-ownership layers (3 PRs, each a deploy-found layer); (2) **ArgoCD did NOT
re-run the helm `post-upgrade` hook Job on a git-sync** — run it manually:
`helm template <rel> charts/platform-pg-bootstrap -n platform-identity --show-only
templates/job.yaml | kubectl apply -f -` (unique release name so ArgoCD ignores
it). Greenfield-first-deploy still races (first service owns new tables until the
next bootstrap re-run); per-BC DBs (CNPG #693) retire the sharing. auth also
needed KV `platform-revocation-redis-url` provisioned first (#1327 ordering — copy
`platform-gateway-redis-url`'s DB-0 value; sibling of [[platform-internal-api-secret-provisioning-pending]]).
