---
name: platform-architecture-stack
description: Complete Platform tech stack — 36 confirmed decisions, 28 shared libs, 13 expert reviews, 5 ADRs, READY TO IMPLEMENT
type: project
---

## Platform Complete Tech Stack (2026-03-24)

**36 decisions confirmed. 28 shared libs. READY TO IMPLEMENT.**
Full details at `docs/platform/context-mapping/architecture-decisions.md`.

### Application Layer
- NestJS + Fastify + MikroORM (not Prisma) + PostgreSQL 16+
- RabbitMQ for events AND jobs (replaces Redis Streams + BullMQ from CTO spec)
- Redis 7+ cache-only (single responsibility — no jobs, no events)
- Vitest + Fastify inject() + Testcontainers + @cucumber/cucumber + Playwright + Pactum
- 28 shared libs (19 platform + 9 BC) — includes @acme/specifications, @acme/exceptions, @acme/platform-contracts
- Frontend: TanStack Query (server state) + Zustand (UI state) — NOT Redux
- Auth: local credentials + OIDC per-tenant (complementary, not alternatives) — Decision #36

### K8s Infrastructure (from enterprise + K8s expert reviews)
- AKS managed, private cluster, Azure CNI + Calico
- PSS Restricted + Kyverno admission + Workload Identity
- 3 node pools: system/trading (on-demand), batch (spot M4+)
- CloudNativePG 3-node + PgBouncer (transaction pooling, per-schema routing)
- RabbitMQ 3-node quorum queues + Topology Operator
- Redis Sentinel cache-only (no persistence needed)
- Traefik 2-replica + PDB + Azure LB

### Operations
- GitHub Actions (CI) → ArgoCD + ApplicationSet (CD)
- Helm Charts (one base chart, per-service values)
- Grafana + Prometheus + Loki + Tempo (observability)
- Fluent Bit (log collector), OpenTelemetry (instrumentation)
- ESO + Key Vault (secrets), SOPS for config only
- Cosign (image signing M2), Falco (runtime M2), Argo Rollouts (canary M4)
- Tilt (local K8s dev Sprint 2), KEDA (autoscaling M3), Velero (backup)

### Key Deviations from CTO Spec
- MikroORM not Prisma (confirmed by Milos)
- RabbitMQ not Redis Streams + BullMQ (enterprise review recommendation)
- Full Grafana stack not just "OpenTelemetry" (enterprise review)
- 35 decisions vs spec's ~10 tech choices (comprehensive infrastructure design)
- 4 architecture board reports at `docs/platform/context-mapping/`

## All Board Issues Resolved (2026-03-24)

- **34/34 resolved:** 9 critical + 13 high + 12 medium
- **5 ADRs:** ADR-0012 (stock saga), ADR-0013 (schema isolation), ADR-0014 (separate binaries), ADR-0015 (zero-downtime deploy), ADR-0016 (BDD+Vitest)
- **3 completeness audit blockers fixed:** Redis→RabbitMQ in BC map, K8s decisions #24-36 added, auth model documented
- **13 expert reviews** across 3 board sessions (enterprise, software, devops, QA, solutions, K8s security, K8s HA, modern devops, message bus, Helm)

## Key ADR Decisions

- **ADR-0012:** Stock reservation via saga (advisory lock eliminates TOCTOU)
- **ADR-0013:** Per-BC PostgreSQL schemas, no cross-schema FKs, UUID references only
- **ADR-0014:** Separate binaries from day one (monolith boundary = shared DB, not shared process)
- **ADR-0015:** Rolling update + init container migrations + expand-contract pattern
- **ADR-0016:** Cucumber standalone (not wrapped in Vitest), injectable Clock for time manipulation

## M1 Sprint 1 Implementation Progress (2026-03-24)

- **#199 Nx scaffold:** DONE — 12 ESLint rules, 28 path aliases, @nx/nest
- **#200 Shared libraries:** DONE — 18 libs scaffolded (127 files), all detected by Nx
- **#201 Vitest spike:** DONE — CRITICAL: unplugin-swc required for NestJS decorator metadata in Vitest
- **#202-#206:** Open (gateway pipeline, Docker Compose, CI/CD, Dockerfile, MikroORM)
- **#207-#211:** Sprint 2 (auth, tenant, user, isolation, integration tests)
- **Epic #198** on GitHub, 13 task files decomposed (.claude/epics/platform-m1-platform-foundation/)

## Key Implementation Gotchas

- **esbuild does NOT support emitDecoratorMetadata** — use `unplugin-swc` in Vitest, `@nx/js:swc` for build
- **Shared-kernel libs use @nx/js:tsc** (no decorators, pure TS). Platform libs use @nx/js:swc.
- **NestJS v10** is the current version — v11 packages conflict. Pin @nestjs/*@^10, @mikro-orm/nestjs@^6.1
- **PM plugin ceremony required** for all Platform work — epic-sync → issue-start → issue-close

**How to apply:** Reference `architecture-decisions.md` for any tech choice question. All decisions are numbered (#1-#36) and dated. ADRs in `docs/adr/`.
