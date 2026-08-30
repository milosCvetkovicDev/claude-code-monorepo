# 13 · The system it built

> Part IV — What It Built · [← Running many at once](12-running-many-at-once.md) · [Contents](README.md) · [Appendices →](appendix-a-install.md)

---

A methodology's only honest credential is its output. Twelve chapters of loops,
layers, gates and ceremony would be theater if the thing they produced were a demo —
so the final part of this book points at the thing itself.

## The platform, in one paragraph

A multi-tenant commodity-trading platform: an API gateway plus twelve microservices
across nine bounded contexts, communicating over RabbitMQ with a transactional outbox
and versioned routing keys; a React front end on a 98-component design system with a
full configuration matrix (six accents, light/dark/system, density, reduced motion);
per-context PostgreSQL schemas behind a fail-closed tenant filter; deployed to
Kubernetes by GitOps — ArgoCD app-of-apps, Argo Rollouts canaries with automatic
rollback, workload identity, external secrets — all built and operated *alongside*
the Express/TypeORM monolith it is strangling, which still serves production while
its capabilities migrate.

Every architectural noun in that paragraph appeared earlier in this book as a
*ceremony artefact*: the inbox/idempotency conventions were ADR-0068 in
[chapter 11](11-an-epic-start-to-finish.md); the fail-closed tenant filter and its
forked-EntityManager exemption are a memory-tree entry in [chapter 9](09-memory.md);
the event-contract discipline is a PostToolUse validator in [chapter 7](07-hooks.md).
The configuration and the system co-evolved — which is the deepest sense in which
this repository is "real."

## Volume II: the architecture set

The platform is documented in [`docs/architecture/`](../docs/architecture/) — **40
documents, 239 mermaid diagrams, ~32,000 lines**, every diagram rendering natively on
GitHub. It is organized as its own book, so this chapter hands over rather than
duplicates. The recommended twenty-minute entry, from its
[own index](../docs/architecture/README.md):

1. [`00-system-context.md`](../docs/architecture/00-system-context.md) — who uses it,
   what it talks to, where the trust boundaries are
2. [`01-container-view.md`](../docs/architecture/01-container-view.md) — the runnable
   pieces and how they connect
3. [`platform/bounded-contexts.md`](../docs/architecture/platform/bounded-contexts.md)
   — why the services are split the way they are
4. [`devops/01-gitops-topology.md`](../docs/architecture/devops/01-gitops-topology.md)
   — how a merge becomes a running pod

From there, four legs — [`backend/`](../docs/architecture/backend/) (service anatomy,
API grammar, data, authn/authz, messaging, caching),
[`frontend/`](../docs/architecture/frontend/),
[`devops/`](../docs/architecture/devops/) (GitOps, progressive delivery, CI,
infrastructure, secrets, observability, environments), and
[`legacy/`](../docs/architecture/legacy/) (the monolith and the strangler migration)
— plus [`platform/`](../docs/architecture/platform/) for the domain model and event
catalog. When you need mechanism rather than shape, the
[`deep-dives/`](../docs/architecture/deep-dives/) go one level further down: the life
of one event, the broker's failure atlas, and how tenant isolation is enforced at
query time, threat model included.

## Reading it as evidence

Three suggestions for reading Volume II *as the output of Volume I*, rather than as
generic architecture docs:

**Look for the conventions the ceremony froze.** The `{data, meta}` envelope, the
`{DOMAIN}_{ERROR}` code grammar, the bracket-filter syntax, the outbox caller-EM
rule — these recur across all 40 documents because they were decided once (as ADRs,
via `arch-create`) and then *enforced by generators and validators* rather than by
vigilance. Consistency at this scale is not a personality trait; it is tooling.

**Notice what the diagrams are careful about.** The event deep-dives distinguish
delivery guarantees precisely (at-least-once transport, effectively-once processing)
because imprecision there cost real incidents — the memory tree holds the receipts.
The multi-tenancy pages document the *enforcement point* of every isolation claim,
a discipline sharpened by an audit finding that "documented" and "enforced" had
diverged ([`SANITIZATION.md`](../SANITIZATION.md), stage 5, records the class).

**And know how the docs themselves were verified.** The architecture set was
authored by agents reading the real source — then adversarially audited for
identifier leaks, technical accuracy and diagram renderability. The audit found nine
accuracy defects, two of which misdescribed security posture; and the diagrams are confirmed
to render by running the real mermaid parser — after a hand-written validator had
passed four that GitHub would have shown as red error boxes.
Maker ≠ checker applies to documentation too, and the checker earned its keep.

## The numbers, one last time

Seven months. ~250k lines. ~780 merged PRs. Largely one engineer — plus 71 skills,
34 hooks, 31 agents, 172 memories, a 13-step ceremony and two loops that never
merge. The claim this book has been making, chapter by chapter, is that the second
list is what makes the first list possible. The evidence is the repository you are
standing in.

## Primary sources

- [`docs/architecture/README.md`](../docs/architecture/README.md) — Volume II's own index and reading order
- [`docs/architecture/deep-dives/`](../docs/architecture/deep-dives/) — events, broker, multi-tenancy, at mechanism level
- [`SANITIZATION.md`](../SANITIZATION.md) — how 40 documents about a real system were made publishable, and what that process kept finding

---

> **The appendices:** [A — Installing this setup](appendix-a-install.md) ·
> [B — Attribution and lineage](appendix-b-attribution-and-lineage.md) ·
> and the sanitization story itself, [`SANITIZATION.md`](../SANITIZATION.md), which
> doubles as this book's chapter on operational security.
