# Architecture

The system the Claude Code setup in this repository was used to build: a multi-tenant
commodity-trading platform — an API gateway plus twelve microservices across nine
bounded contexts, a React front end on a 98-component design system, deployed to
Kubernetes by GitOps with canary releases and automatic rollback, alongside the
Express/TypeORM monolith it is replacing.

**40 documents · 239 diagrams · ~32,000 lines.** Every diagram is mermaid and renders
natively on GitHub. All identifiers are fictional — see [`../../SANITIZATION.md`](../../SANITIZATION.md).

---

## Read in this order

New to the system? Four documents give you the whole shape in about twenty minutes:

1. [`00-system-context.md`](00-system-context.md) — who uses it, what it talks to, where the trust boundaries are
2. [`01-container-view.md`](01-container-view.md) — the runnable pieces and how they connect
3. [`platform/bounded-contexts.md`](platform/bounded-contexts.md) — why the services are split the way they are
4. [`devops/01-gitops-topology.md`](devops/01-gitops-topology.md) — how a merge becomes a running pod

Then follow whichever leg you care about. When you need mechanism rather than shape — how an
event actually reaches a consumer, what the broker does when it breaks, how tenant isolation is
enforced at query time — go to [`deep-dives/`](deep-dives/README.md).

---

## Catalogue

### Whole system

| Document                                       | What it shows                                                | Diagrams                      |
| ---------------------------------------------- | ------------------------------------------------------------ | ----------------------------- |
| [`00-system-context.md`](00-system-context.md) | Actors, external systems, trust zones, legacy coexistence    | 3 — C4Context, flowchart ×2   |
| [`01-container-view.md`](01-container-view.md) | Gateway + 12 services + SPA + data + bus, grouped by context | 4 — C4Container, flowchart ×3 |

### Platform — domain and integration

| Document                                                               | What it shows                                                       | Diagrams                                        |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------- |
| [`platform/bounded-contexts.md`](platform/bounded-contexts.md)         | 9 contexts, relationship patterns, schema-per-role data tier        | 4 — C4Context, flowchart ×3                     |
| [`platform/domain-model.md`](platform/domain-model.md)                 | Aggregates, entities, value objects, lifecycle state machines       | 9 — stateDiagram ×5, erDiagram ×3, classDiagram |
| [`platform/event-catalog.md`](platform/event-catalog.md)               | Event taxonomy, envelope, exchange topology, versioned routing keys | 3 — flowchart ×2, sequenceDiagram               |
| [`platform/integration-patterns.md`](platform/integration-patterns.md) | Outbox, inbox idempotency, saga, CQRS projections, DLQ replay       | 8 — sequenceDiagram ×6, stateDiagram, erDiagram |

### Backend

| Document                                                             | What it shows                                                         | Diagrams                                                                    |
| -------------------------------------------------------------------- | --------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [`backend/01-service-anatomy.md`](backend/01-service-anatomy.md)     | Shared bootstrap, module/DI layering, shared-library graph            | 9 — flowchart ×5, stateDiagram ×2, sequenceDiagram, C4Container             |
| [`backend/02-api-architecture.md`](backend/02-api-architecture.md)   | Response envelope, cursor pagination, filter grammar, error taxonomy  | 8 — flowchart ×5, sequenceDiagram ×2, stateDiagram                          |
| [`backend/03-data-architecture.md`](backend/03-data-architecture.md) | Per-context schema isolation, MikroORM UoW, fail-closed tenant filter | 8 — flowchart ×4, sequenceDiagram ×2, erDiagram, stateDiagram               |
| [`backend/04-authn-authz.md`](backend/04-authn-authz.md)             | Login+MFA, refresh-family reuse detection, OIDC/SSO, JWKS, RBAC       | 11 — sequenceDiagram ×4, flowchart ×4, C4Container, stateDiagram, erDiagram |
| [`backend/05-messaging.md`](backend/05-messaging.md)                 | Exchange/queue topology, DLX chain, message lifecycle, reprocess      | 6 — flowchart ×3, stateDiagram ×2, sequenceDiagram                          |
| [`backend/06-caching.md`](backend/06-caching.md)                     | Redis keys, TTL strategy, invalidation, tenant-scoped counters        | 5 — flowchart ×2, sequenceDiagram ×2, stateDiagram                          |

### Frontend

| Document                                                               | What it shows                                                      | Diagrams                                          |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------- |
| [`frontend/01-app-architecture.md`](frontend/01-app-architecture.md)   | App structure, provider composition, same-origin deployment        | 5 — flowchart ×2, sequenceDiagram ×2, C4Container |
| [`frontend/02-design-system.md`](frontend/02-design-system.md)         | Token → primitive → domain → screen layering, theming, policy AD-7 | 4 — flowchart ×3, sequenceDiagram                 |
| [`frontend/03-state-and-data.md`](frontend/03-state-and-data.md)       | Server/client state split, query keys, caching, typed API layer    | 5 — flowchart ×3, sequenceDiagram ×2              |
| [`frontend/04-routing-and-shell.md`](frontend/04-routing-and-shell.md) | Route tree, guards, permission gating, nav shell                   | 6 — flowchart ×4, stateDiagram, sequenceDiagram   |

### DevOps and infrastructure

| Document                                                                 | What it shows                                                               | Diagrams                                               |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------- | ------------------------------------------------------ |
| [`devops/01-gitops-topology.md`](devops/01-gitops-topology.md)           | Single branch, self-managing root app, 7 children from 2 ApplicationSets    | 5 — flowchart ×2, graph, sequenceDiagram, stateDiagram |
| [`devops/02-progressive-delivery.md`](devops/02-progressive-delivery.md) | Canary 10→50→100 gated by SLO analysis, automatic rollback                  | 4 — flowchart ×2, sequenceDiagram ×2                   |
| [`devops/03-ci-pipeline.md`](devops/03-ci-pipeline.md)                   | PR → merge → build → deploy → smoke → rollback; ARC runners, BuildKit       | 5 — flowchart ×3, sequenceDiagram, stateDiagram        |
| [`devops/04-infrastructure.md`](devops/04-infrastructure.md)             | Cluster topology, node pools, network path, ingress + TLS, Terraform layout | 5 — C4Deployment, flowchart ×4                         |
| [`devops/05-secrets-and-identity.md`](devops/05-secrets-and-identity.md) | Key Vault → ESO → Secret → pod with federated identity; rotation            | 6 — sequenceDiagram ×3, flowchart ×2, stateDiagram     |
| [`devops/06-observability.md`](devops/06-observability.md)               | Three signals into one store; trace propagation; detector liveness          | 4 — flowchart ×2, sequenceDiagram, stateDiagram        |
| [`devops/07-environments.md`](devops/07-environments.md)                 | Local → dev → production, promotion path, per-env config sources            | 4 — flowchart ×2, sequenceDiagram, stateDiagram        |

### Legacy and migration

| Document                                                               | What it shows                                                          | Diagrams                                                          |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------- |
| [`legacy/01-legacy-architecture.md`](legacy/01-legacy-architecture.md) | The Express/TypeORM monolith: layering, jobs, ERP client, hosting      | 11 — flowchart ×5, stateDiagram ×3, sequenceDiagram ×2, erDiagram |
| [`legacy/02-strangler-migration.md`](legacy/02-strangler-migration.md) | Coexistence, migration waves, ownership handover, cutover and rollback | 6 — flowchart ×3, sequenceDiagram ×2, stateDiagram                |

### Deep dives

Three mechanisms explained below the level of the survey documents above — the event backbone,
the broker under it, and multi-tenant isolation. Index and reading order in
[`deep-dives/README.md`](deep-dives/README.md).

| Document                                                                                                         | What it shows                                                                        | Diagrams |
| ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | -------- |
| [`deep-dives/events/01-event-anatomy.md`](deep-dives/events/01-event-anatomy.md)                                 | The envelope field by field: what writes each, what reads it, what breaks without it | 4        |
| [`deep-dives/events/02-event-families.md`](deep-dives/events/02-event-families.md)                               | Counted index of every event — owner, exchange, routing key, consumers               | 7        |
| [`deep-dives/events/03-the-life-of-one-event.md`](deep-dives/events/03-the-life-of-one-event.md)                 | One event, twelve hops, end to end, each with its failure mode                       | 13       |
| [`deep-dives/events/04-event-evolution.md`](deep-dives/events/04-event-evolution.md)                             | Versioned routing keys, dual-publish windows, contract tests as enforcement          | 4        |
| [`deep-dives/events/05-choreography-decisions.md`](deep-dives/events/05-choreography-decisions.md)               | Choreography over orchestration, sagas, and the cost of eventual consistency         | 4        |
| [`deep-dives/rabbitmq/01-topology.md`](deep-dives/rabbitmq/01-topology.md)                                       | Every exchange, queue, binding and DLX chain — and who declares each, when           | 9        |
| [`deep-dives/rabbitmq/02-publishing.md`](deep-dives/rabbitmq/02-publishing.md)                                   | The outbox relay: caller-owned transactions, advisory lock, confirms, audit lane     | 5        |
| [`deep-dives/rabbitmq/03-consuming.md`](deep-dives/rabbitmq/03-consuming.md)                                     | Consumer lifecycle, the hardened reconnect helper, ack strategy, the inbox pattern   | 5        |
| [`deep-dives/rabbitmq/04-failure-atlas.md`](deep-dives/rabbitmq/04-failure-atlas.md)                             | Nine failure modes as uniform map sheets, plus the dead-letter replay runbook        | 11       |
| [`deep-dives/rabbitmq/05-testing-the-broker.md`](deep-dives/rabbitmq/05-testing-the-broker.md)                   | What is provable before production, and what only a deployed environment proves      | 3        |
| [`deep-dives/multi-tenancy/01-tenant-model.md`](deep-dives/multi-tenancy/01-tenant-model.md)                     | What a tenant is as rows and columns: aggregate, lifecycle, four identity handles    | 4        |
| [`deep-dives/multi-tenancy/02-resolution.md`](deep-dives/multi-tenancy/02-resolution.md)                         | How an anonymous request finds its tenant before authentication is possible          | 4        |
| [`deep-dives/multi-tenancy/03-propagation.md`](deep-dives/multi-tenancy/03-propagation.md)                       | Six carriers that must all agree — header, claim, ALS, envelope, job, cache key      | 4        |
| [`deep-dives/multi-tenancy/04-enforcement.md`](deep-dives/multi-tenancy/04-enforcement.md)                       | The fail-closed filter, the forked-EM problem, every exemption argued individually   | 4        |
| [`deep-dives/multi-tenancy/05-isolation-threat-model.md`](deep-dives/multi-tenancy/05-isolation-threat-model.md) | Nine attack paths, the control that stops each, the test that proves it              | 10       |

---

## Coverage and gaps

Written to be honest rather than complete. Each author verified claims against source and
recorded what they could not confirm; those caveats are stated inline in the documents,
not hidden here. The material ones:

**Documented as intent, not observed behaviour**

- Node-pool topology is what Terraform declares; the live cluster has been observed to differ, and the migration needs a manual blue/green.
- Workload Identity for secrets is built but not adopted — the live secret store still uses a managed-identity auth type, and no overlay selects the per-namespace path.
- The AI context's consumers bind exchanges and routing keys that do not exist. It is drawn with dashed edges and described as inert.
- The per-BC managed-Postgres data tier and in-cluster Redis Sentinel are present in charts but referenced by no Application.

**Contradictions found and resolved during authoring**

- The platform's own architecture overview still described a 4-service milestone state; the container view documents the real 12-service topology and says so.
- Source docs described a hybrid single-process server behind feature flags. No such flag or router exists — the rebuild is a separate cluster behind an enforced module boundary. Called out rather than reproduced.
- One document claimed the legacy stack runs on Container Apps; Terraform shows App Service, with only the commission service containerised. Corrected.

**Thinner than the rest**

- The frontend section was authored from source rather than ported, because the original documentation barely covered it. It is accurate to the code but less battle-tested as an explanation than the backend and devops material.
- Production database and cache sizing is unspecified anywhere in source; left as "sized at cutover" rather than invented.

**Not included**

- Per-endpoint API reference (belongs with the code).
- Anything requiring live cluster state to verify — cardinality, retention, real traffic shapes.

---

## Conventions

- **Mermaid only**, validated structurally: balanced fences and subgraphs, quoted labels, every arrow endpoint declared, no reserved words as node ids.
- **ASCII is kept** where it beats a diagram — directory trees, file layouts, wire formats.
- **Every diagram carries prose.** The diagram illustrates; the text is the deliverable.
- **Decisions cite their ADR** by number and title.
