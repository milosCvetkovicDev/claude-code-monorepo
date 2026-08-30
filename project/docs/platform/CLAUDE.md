# CLAUDE.md — Platform Documentation

> ⚠️ **Migration assessment 2026-05-25**: Multi-vendor cost-focused migration review at [`architecture/migration-assessment.md`](architecture/migration-assessment.md) + interactive HTML. Triggered by Azure quota rejection (#921) + cost directive. Panel recommendation: try Path B (KEDA + nightly shutdown) first; if migration committed, choose **DigitalOcean (DOKS)** (£18,400 5-year TCO). Cloudflare + Neon reviewed and rejected. All existing docs describe current Azure AKS architecture and remain authoritative until migration is committed. _(Update 2026-06-01: uksouth regional vCPU quota self-service-raised 10→20 — eases dev capacity, cost driver unchanged.)_

## Structure

```
docs/platform/
├── architecture/     # System design, API contracts, decisions
├── ddd/              # DDD artifacts: context mapping, events, aggregates, BDD
├── development/      # Developer guides: local setup, testing
├── operations/       # Deployment, security, compliance
├── doc-site/         # CTO specification (READ-ONLY — business requirements source)
```

## Rules

- **doc-site/ is READ-ONLY** — CTO's scraped documentation site. Never modify these files. Use as business requirements source only.
- **architecture/** — System-level docs. Update when services, libraries, or ADRs change.
- **ddd/** — DDD artifacts from architecture planning phases. Update during `/pm:arch-create`.
- **development/** — Developer-facing guides. Update when local dev setup changes.
- **operations/** — Deployment + security docs. Update when infra, CI/CD, or security changes.
- All docs describe what IS implemented, not aspirational designs.
- Cross-reference ADRs at `docs/adr/` for decision rationale.

## Key Documents

| When you need to...         | Read |
| --------------------------- | --------------------------------------- |
| Understand the system | `architecture/architecture-overview.md` |
| Find an API endpoint | `architecture/api-reference.md`         |
| Understand the domain model | `architecture/domain-model.md`          |
| Set up local dev | `development/local-development.md`      |
| Run tests | `development/testing-strategy.md`       |
| Deploy | `operations/deployment-guide.md`        |
| Understand auth/security | `operations/security-architecture.md`   |
| Review migration assessment | `architecture/migration-assessment.md`  |
| Check business requirements | `doc-site/`                             |

## Platform Tech Stack

- **Backend:** NestJS + Fastify, MikroORM, PostgreSQL 16, Redis 7, RabbitMQ 3
- **Testing:** Vitest (not Jest), Testcontainers, Pact V4 CDC
- **Infra:** Docker (distroless), Helm, AKS, GitHub Actions
- **Architecture:** Microservices, DDD, Clean Architecture, CQRS-lite
- **Observability:** OpenTelemetry, structured logging

## Conventions

- Services at `apps/platform/` — gateway (3000), auth-service (3001), tenant-service (3002), user-service (3003), trading-service (3005), inventory-service (3006)
- Libraries at `libs/platform/` — import as `@acme/<name>`
- Per-BC PostgreSQL schemas: `auth`, `identity`, `platform`, `trading`, `inventory`
- All entities: private fields, create()/fromTrusted() factories
- Use cases: `@Injectable()` with single `execute()` method
- Ports: interfaces in `domain/ports/`, implementations in infrastructure
- Tests: Vitest `describe`/`it`/`expect`, `vi.fn()` for mocks
- Docker: single shared `apps/platform/Dockerfile` with build args
