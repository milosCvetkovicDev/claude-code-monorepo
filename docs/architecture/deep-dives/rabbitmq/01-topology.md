# Broker Topology — exchanges, queues, bindings, dead letters

This document is the object-by-object inventory of the Acme platform's RabbitMQ broker: every
exchange and queue that exists at runtime, which component declares it, at which moment, with
which arguments, and what happens when two declarers disagree. It answers the questions a survey
cannot — "if I add a service, what exactly must I create and in what order?", "why does this pod
CrashLoop at boot on an AMQP 403?", "where does a nacked message physically end up, and who takes
it out again?". Read it if you are onboarding a service onto the bus, debugging a topology or
permission failure, or planning the migration to the RabbitMQ Cluster Operator. It assumes you
have already read [`../../backend/05-messaging.md`](../../backend/05-messaging.md), which
establishes the outbox/relay/consumer shape this document dissects.

Everything below was read out of `charts/platform-rmq-bootstrap` (chart + rendered output),
`libs/platform/event-bus/src/lib`, the ten consumer classes under `apps/platform/*`,
`charts/infrastructure/rabbitmq-values.yaml`, `scripts/platform/cluster-bootstrap.sh`,
`scripts/platform/rabbitmq-definitions.json`, `infra/modules/platform-key-vault-secrets`, and
ADRs 0017, 0026, 0028, 0036, 0038, 0049 and 0072. Counts were produced by rendering the chart
(`helm template`) and by enumerating every `assertExchange` / `assertQueue` / `bindQueue` /
`checkExchange` call site outside test files. Where the chart, the code and the ADRs disagree,
the disagreement is stated, not reconciled.

---

## 1. Three declaring authorities, one broker

The single most confusing property of this topology is that **no single component owns it**.
Three independent authorities write to the same broker, and each knows only part of the picture.

| Authority                                    | What it declares                                                                                                                                                                                  | When it runs                                           | Mechanism                                                                                              |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| `charts/platform-rmq-bootstrap` (CRDs)       | 1 vhost, 10 exchanges (9 bounded-context topic exchanges plus the `acme.audit-feed` fanout), 10 dead-letter exchanges, 10 retention dead-letter queues, 10 DLQ bindings, 12 users, 12 permissions | On every ArgoCD sync of the `platform-identity` bundle | `rabbitmq.com/v1beta1` CRDs reconciled by the Messaging Topology Operator over the management HTTP API |
| Service code (`@acme/event-bus` + consumers) | 14 service-owned dead-letter exchanges, 31 queues, 45 bindings                                                                                                                                    | At pod boot, inside `OnModuleInit`, over AMQP          | `amqplib` `assertExchange` / `assertQueue` / `bindQueue` on a confirm channel                          |
| `scripts/platform/rabbitmq-definitions.json` | 13 exchanges, 2 queues, 2 bindings, 1 user — **local Docker Compose only**                                                                                                                        | At broker container start                              | `management.load_definitions` preload                                                                  |

The declared totals across the cluster path (authorities 1 and 2, which share a broker) come to
**34 distinct exchanges, 41 distinct queues and 55 distinct bindings** on the `acme` vhost. Those
numbers are enumerated exhaustively in sections 4 and 5.

The split exists for a specific reason. Under ADR-0017's bounded-context isolation, a service's
AMQP user has `configure` permission only over its own namespace. A consumer that binds to another
context's exchange therefore _cannot declare that exchange_ — an active `assertExchange` returns
`403 ACCESS_REFUSED - configure access to exchange '<x>' refused`. So the shared, cross-context
objects (the BC exchanges and the audit fanout) had to move out of service code and into
operator-reconciled CRDs, leaving service code to declare only what its own permission regex
covers. The shared consumer helper documents exactly this:

```ts
// The source exchange is owned by the PUBLISHING bounded context, not this
// consumer. Verify it exists PASSIVELY (checkExchange -> exchange.declare with
// passive=true): this needs no `configure` permission ...
await channel.checkExchange(config.exchange);
```

That passive check only succeeds if something else created the exchange first — which is precisely
what the chart guarantees, and which is why boot ordering (section 9) matters so much.

---

## 2. The naming grammar, stated as rules

Nine rules govern every name on the broker. Each is load-bearing: breaking one produces either a
403 at bind time, a `PRECONDITION_FAILED` on redeclare, or silent message loss.

**Rule 1 — one topic exchange per bounded context, named `acme.<bc>`.**
The exchange name is derived, never configured. Both the publisher and the consumer derive it from
the first dotted segment of the event type:

```ts
// libs/platform/event-bus/src/lib/outbox-relay.ts
private deriveExchange(eventType: string): string {
  const dotIndex = eventType.indexOf('.');
  if (dotIndex <= 0) throw new Error(`Invalid eventType format: '${eventType}'`);
  return `acme.${eventType.substring(0, dotIndex)}`;
}
```

So `trading.deal.locked` publishes to `acme.trading`, and `platform.tenant.created` publishes to
`acme.platform`. The identical derivation lives in `event-handler-explorer.ts` as
`deriveExchangeFromEventType`, deliberately duplicated with a cross-reference comment so the two
sides cannot drift silently.

**Rule 2 — the routing key _is_ the event type at version 1, and gains a `.vN` suffix from
version 2.** `buildVersionedRoutingKey('trading.deal.locked', 1)` returns the bare key;
`(…, 2)` returns `trading.deal.locked.v2`. This is ADR-0036. The relay validates the suffix against
the entry's `version` field before publishing and dead-letters a mismatch.

**Rule 3 — the dead-letter exchange is keyed off the _exchange_, never off the service:
`<exchange>.dlx`.** `acme.trading.dlx`, `acme.identity.dlx`. The chart's `dlx-exchange.yaml`
carries an explicit warning about why:

> Therefore the DLX is keyed off EXCHANGES (`acme.identity.dlx`, …), NOT off the per-service list.
> A per-service `<svc>.dlx` would never be the runtime target and the retention DLQ below would
> catch nothing.

**Rule 4 — the retention dead-letter queue is `<exchange>.dlq`, bound to `<exchange>.dlx` with the
literal routing key `dead-letter`.** That literal string appears in four places that must agree
character-for-character: the chart's `dlq-binding.yaml` (`routingKey: dead-letter`), the queue
argument `x-dead-letter-routing-key: 'dead-letter'` in `setup-rabbit-consumer.ts`, the same
argument in `event-handler-explorer.ts`, and every hand-rolled consumer's `bindQueue(dlq, dlx,
'dead-letter')`.

**Rule 5 — a consumer queue is named `<service>-service.<source-bc>`.**
`commission-service.trading`, `accounting-service.trading`, `reporting-service.inventory`. Two
documented deviations exist: `notification-service.<bc>.events` appends `.events` because
notification consumes five contexts, and `user-service.platform.tenant.created` names the full
routing key because that consumer is single-purpose.

**Rule 6 — a service-owned dead-letter pair is `<service>-service.<source-bc>.dlx` / `.dlq`.**
This is the rule that Rule 3 does _not_ cover, and the tension between them is real. A consumer
reading a foreign context cannot declare `acme.<foreign-bc>.dlx` (no `configure` there), so it
declares one inside its own namespace instead. `notification-event-consumer.ts` states the
reasoning inline:

```ts
// Notification-owned DLX per source BC. `notification-service.*` is this user's
// configure namespace; the previous `acme.<bc>.dlx` is FOREIGN for the
// commission/accounting BCs and cannot be declared by notification.
const DLX_NAME = (bc: SourceBC): string => `notification-service.${bc}.dlx`;
```

The consequence, quantified in section 8: most of the chart-declared `acme.<bc>.dlq` retention
queues receive nothing, because the consumers dead-letter into their own private DLQs instead.

**Rule 7 — the audit fanout is `acme.audit-feed`, and the audit queue is the bare name
`audit.events`.** No service prefix. `audit_user`'s `configure` regex is
`^(audit\.events|audit-service\..*)$` — an exact match on the queue name plus a dotted namespace —
which is why the audit consumer's dead-letter pair had to be renamed from `audit.events.dlx` to
`audit-service.events.dlx`: the first alternative is an exact match and does not permit a `.dlx`
suffix.

**Rule 8 — work queues are `jobs.<context>.<purpose>`.** The only one that exists at runtime is
`jobs.communication.document-generation`. ADR-0017 specifies `jobs.{service}.{purpose}`; the
shipped name uses the _context_ (`communication`), not the service (`document`). Both the chart's
permission regex (`jobs\.communication(\..*)?`) and the worker code agree on the context form, so
the ADR text is the outlier.

**Rule 9 — the AI service names queues `ai.signals.<source>-<event>`.** Per ADR-0028 there are no
wildcard bindings for AI: one named queue per consumed event type. Eleven such queues appear in
code. None of them exist on the broker — see section 12, defect D3.

Everything else follows mechanically. The queue prefix is not cosmetic: RabbitMQ checks `configure`
against the queue name on `assertQueue`, and `queue.bind` checks **write on the destination queue**
and **read on the source exchange**. That asymmetry is the source of a recurring class of boot
failure documented in section 10.

---

## 3. The vhost and how the broker is actually deployed

### One vhost, `acme`

There is exactly one logical vhost for all platform services. `templates/vhost.yaml` renders a
single `Vhost` CRD and the comment is explicit about the alternative that was rejected:

> Per ADR-0017 there is one shared vhost (`acme`) for all platform services — per-tenant vhost
> isolation is explicitly rejected.

Tenant isolation is therefore a payload/consumer concern (every event envelope carries `tenantId`,
and consumers run under the tenant filter), not a broker-topology concern. The AMQP URI every
service composes ends in `/acme`:

```text
amqp://auth_user:$(RABBITMQ_PASSWORD)@rabbitmq.rabbitmq.svc.cluster.local:5672/acme
```

### The broker itself is a plain StatefulSet, installed imperatively

This is the part most often assumed wrong. The broker is **not** managed by the RabbitMQ Cluster
Operator, and it is **not** an ArgoCD Application. It is installed by step 6 of a 19-step
bootstrap shell script:

```bash
helm upgrade --install rabbitmq bitnami/rabbitmq \
  --namespace rabbitmq \
  --values "$REPO_ROOT/charts/infrastructure/rabbitmq-values.yaml" \
  --atomic --wait --timeout 5m
```

Key facts from `rabbitmq-values.yaml`, all verified in the file:

| Property           | Value                                                                                                                       |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| Chart              | `bitnami/rabbitmq`, pinned at 16.3.3                                                                                        |
| Image              | tag `4.1.3-debian-12-r1`, vendored into the platform's own ACR and digest-pinned                                            |
| `replicaCount`     | **1**                                                                                                                       |
| Default queue type | `default_queue_type = quorum` (via `extraConfiguration`)                                                                    |
| Extra plugins      | `rabbitmq_management`, `rabbitmq_shovel`, `rabbitmq_delayed_message_exchange`                                               |
| Memory watermark   | `vm_memory_high_watermark.relative = 0.7` against a 1Gi limit                                                               |
| `channel_max`      | 128 per connection                                                                                                          |
| Persistence        | 20Gi, `managed-csi`                                                                                                         |
| Service type       | `ClusterIP` — the management UI on 15672 is port-forward only                                                               |
| Admin auth         | `auth.username: acme`, password + Erlang cookie from the `rabbitmq-credentials` Secret (materialised by ESO from Key Vault) |

The single replica is deliberate and the values file is honest about the consequence: _"Quorum
queues run at replication factor 1 on a single node (a valid single-member quorum; no HA)."_ The
`allowInsecureImages: true` flag is present because the Bitnami chart rejects any non-Bitnami
registry, including the platform's own ACR — not because the image is untrusted.

### What the ADRs say versus what is deployed

**ADR-0049 (RabbitMQ Cluster Operator Adoption) is `Proposed`, architecture-board ratified, and
not implemented for the broker.** It calls for a `RabbitmqCluster` CRD under ArgoCD, upstream
images, and `spec.replicas: 1` rising to 3. None of that has shipped. What _has_ shipped from
ADR-0049's scope is the topology half: the Messaging Topology Operator, the Exchange/Queue/Binding
CRDs, and the passive `checkExchange` change on foreign exchanges.

Two statements in ADR-0049's own Context section are stale relative to the file it describes:

- It says _"`rabbitmq-values.yaml` declares `replicaCount:3` … against a single user node"_. The
  file today declares `replicaCount: 1` with a comment explaining the regional vCPU quota that
  forced it.
- It says the live image is _"unpinned `docker.io/bitnamilegacy`"_. The file today vendors the
  image into the platform ACR and pins it by digest.

The ADR's _conclusion_ (this is not a durable target) still stands; its snapshot of the status quo
does not.

### The Messaging Topology Operator

Installed as an ArgoCD Application at sync wave `-10` from a vendored upstream manifest
(v1.19.2) plus a Kustomize patch, into namespace `rabbitmq-system`. The patch narrows the
controller-runtime cache:

```yaml
env:
  - name: OPERATOR_SCOPE_NAMESPACE
    value: platform-identity,rabbitmq
```

Without that env var the operator's ClusterRole grants cluster-wide watch on every topology CRD —
a single operator-pod compromise would mean broker admin from any namespace. The narrowing is why
`platform-rmq-bootstrap` is a dependency of exactly one bundle (`identity-bundle`) even though it
provisions users for services in five bundles: the CRDs must land in a watched namespace. Adding
the chart to another bundle without extending this list produces CRDs that are simply never
reconciled, with no error anywhere.

The operator talks to the broker over the **management HTTP API on port 15672**, not AMQP:

```yaml
managementUri: http://rabbitmq.rabbitmq.svc.cluster.local:15672
```

It authenticates with a `connectionSecret` (keys `uri`, `username`, `password`) rather than a
`RabbitmqCluster` reference — precisely because the broker is a plain StatefulSet with no cluster
CRD to point at.

---

## 4. Every exchange

Thirty-four distinct exchanges exist on the `acme` vhost. All are `durable: true` and
`autoDelete: false`. They fall into three groups.

### 4.1 Chart-declared exchanges — 10 (9 bounded-context topic + 1 fanout)

Rendered by `templates/exchange.yaml` ranging over `.Values.exchanges[]`. The chart validates each
entry has both `name` and `type` and that the type is one of `direct`/`topic`/`fanout`/`headers`,
failing the template render otherwise.

| Exchange             | Type   | Owning service(s)                      | Consumers that bind to it                                                                      |
| -------------------- | ------ | -------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `acme.identity`      | topic  | auth-service                           | notification-service                                                                           |
| `acme.platform`      | topic  | tenant-service, user-service           | notification-service, user-service                                                             |
| `acme.inventory`     | topic  | inventory-service                      | reporting-service                                                                              |
| `acme.trading`       | topic  | trading-service                        | accounting-service, commission-service, inventory-service, reporting-service, document-service |
| `acme.ai`            | topic  | ai-service                             | none                                                                                           |
| `acme.reporting`     | topic  | reporting-service                      | none                                                                                           |
| `acme.accounting`    | topic  | accounting-service                     | trading-service, reporting-service, notification-service, document-service                     |
| `acme.communication` | topic  | notification-service, document-service | notification-service, document-generation worker                                               |
| `acme.commission`    | topic  | commission-service                     | notification-service, reporting-service, document-service                                      |
| `acme.audit-feed`    | fanout | the bootstrap chart (no BC owns it)    | audit-service                                                                                  |

`acme.audit-feed` is the only fanout. Per ADR-0026 the outbox relay dual-publishes every entry to
it so the audit service needs zero per-BC bindings — the ADR explicitly rejected the alternative of
binding `#` from each BC exchange because _"each new BC requires a new binding — an operational trap
where a new service's events are silently missed"_.

Metadata naming detail: the CRD's `metadata.name` is the dotted exchange name sanitised to a
DNS-1123 label (`.` → `-`, so `acme-trading`), while `spec.name` carries the real dotted name.

### 4.2 Chart-declared dead-letter exchanges — 10

`templates/dlx-exchange.yaml` ranges over the same `exchanges[]` list and renders `<name>.dlx` for
each, **always `type: topic`**, regardless of the source exchange's type. So `acme.audit-feed.dlx`
is a topic exchange even though `acme.audit-feed` is a fanout. The template explains the choice:

> A topic exchange with a fixed key behaves like a direct exchange for this one route, so the
> coupling is safe; documented here rather than switching to `direct` to keep the type identical to
> the runtime assert.

The full set: `acme.identity.dlx`, `acme.platform.dlx`, `acme.inventory.dlx`, `acme.trading.dlx`,
`acme.ai.dlx`, `acme.reporting.dlx`, `acme.accounting.dlx`, `acme.communication.dlx`,
`acme.commission.dlx`, `acme.audit-feed.dlx`.

### 4.3 Service-owned dead-letter exchanges — 14, declared at pod boot

Each is `topic` + `durable: true`, asserted by the consumer that owns it.

| Exchange                                 | Declared by          | Reason it is not `acme.<bc>.dlx`                       |
| ---------------------------------------- | -------------------- | ------------------------------------------------------ |
| `notification-service.communication.dlx` | notification-service | five source contexts, three of them foreign            |
| `notification-service.commission.dlx`    | notification-service | `acme.commission.*` outside notification's `configure` |
| `notification-service.accounting.dlx`    | notification-service | `acme.accounting.*` outside notification's `configure` |
| `notification-service.identity.dlx`      | notification-service | `acme.identity.*` outside notification's `configure`   |
| `notification-service.platform.dlx`      | notification-service | `acme.platform.*` outside notification's `configure`   |
| `accounting-service.trading.dlx`         | accounting-service   | source context is trading                              |
| `trading-service.accounting.dlx`         | trading-service      | source context is accounting                           |
| `commission-service.trading.dlx`         | commission-service   | source context is trading                              |
| `inventory-service.trading.dlx`          | inventory-service    | source context is trading                              |
| `reporting-service.trading.dlx`          | reporting-service    | source context is trading                              |
| `reporting-service.accounting.dlx`       | reporting-service    | source context is accounting                           |
| `reporting-service.commission.dlx`       | reporting-service    | source context is commission                           |
| `reporting-service.inventory.dlx`        | reporting-service    | source context is inventory                            |
| `audit-service.events.dlx`               | audit-service        | `audit.events.dlx` fails audit's exact-match regex     |

Three services deliberately reuse a chart-declared DLX instead of minting their own, because the
DLX in question falls inside their own `configure` namespace: document-service and the
document-generation worker both target `acme.communication.dlx`, and user-service targets
`acme.platform.dlx`. Their boot-time `assertExchange` is then a _redeclare_ against an
operator-created exchange — idempotent only because the chart pins `type: topic` and
`durable: true` to match.

### 4.4 The whole broker at a glance

```mermaid
flowchart LR
  subgraph CHART["Declared by chart CRDs — Messaging Topology Operator"]
    direction TB
    XID["acme.identity (topic)"]
    XPL["acme.platform (topic)"]
    XTR["acme.trading (topic)"]
    XIN["acme.inventory (topic)"]
    XAC["acme.accounting (topic)"]
    XCM["acme.commission (topic)"]
    XCO["acme.communication (topic)"]
    XRP["acme.reporting (topic)"]
    XAI["acme.ai (topic)"]
    XAF["acme.audit-feed (fanout)"]
  end

  subgraph RELAYS["Producers — OutboxRelay, 4 of 12 services"]
    RA["auth-service relay"]
    RT["tenant-service relay"]
    RU["user-service relay"]
    RI["inventory-service relay"]
  end

  subgraph CONS["Consumer queues — declared at pod boot"]
    direction TB
    QACC["accounting-service.trading"]
    QCOM["commission-service.trading"]
    QINV["inventory-service.trading"]
    QREP["reporting-service.* — 4 queues"]
    QDOC["document-service.events"]
    QJOB["jobs.communication.document-generation"]
    QNOT["notification-service.*.events — 5 queues"]
    QUSR["user-service.platform.tenant.created"]
    QAUD["audit.events"]
    QTRD["trading-service.accounting.invoice-processed"]
  end

  RA --> XID
  RT --> XPL
  RU --> XPL
  RI --> XIN
  RA --> XAF
  RT --> XAF
  RU --> XAF
  RI --> XAF

  XTR --> QACC
  XTR --> QCOM
  XTR --> QINV
  XTR --> QREP
  XTR --> QDOC
  XAC --> QTRD
  XAC --> QREP
  XAC --> QDOC
  XAC --> QNOT
  XCM --> QREP
  XCM --> QDOC
  XCM --> QNOT
  XCO --> QNOT
  XCO --> QJOB
  XIN --> QREP
  XID --> QNOT
  XPL --> QNOT
  XPL --> QUSR
  XAF --> QAUD
  XAI --> DEAD["no consumer"]
  XRP --> DEAD
```

Two structural facts jump out of that diagram and both are verified. First, **`acme.trading` and
`acme.accounting` are the busiest exchanges** — five and four consumer queues respectively — yet
neither trading-service nor accounting-service runs a relay, so nothing currently publishes to
them (section 12, defect D1). Second, **`acme.ai` and `acme.reporting` have zero consumers**: they
exist so that ai-service and reporting-service can publish, and so that a future consumer's
passive `checkExchange` will succeed on first boot rather than crash-looping.

---

## 5. Every queue

Forty-one distinct queues. Every one is `durable: true` with `x-queue-type: quorum` — there are no
classic queues anywhere, and the explicit `x-queue-type` argument is not redundant:

```ts
// Pin the queue type to the broker default (default_queue_type = quorum,
// charts/infrastructure/rabbitmq-values.yaml) so a redeclare never trips
// PRECONDITION_FAILED on inequivalent 'x-queue-type' against leftover
// classic-queue state. See #958.
```

**No queue anywhere sets `x-message-ttl`, `x-max-length`, `x-expires`, `x-overflow` or
`x-delivery-limit`.** A repository-wide search for those arguments returns only the operator's own
CRD schema documentation. Dead-letter queues therefore grow without bound and are never trimmed;
poison messages are never aged out.

### 5.1 Message-carrying queues — 17

| Queue                                          | Source exchange(s)                                   | Routing keys bound                                                                                                                                                                       | Consumer                   | Dead-letters to                          |
| ---------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- | ---------------------------------------- |
| `accounting-service.trading`                   | `acme.trading`                                       | `trading.purchase.finalised`, `trading.sale.finalised`, `trading.haulage.finalised`, `trading.overhead.finalised`, `trading.deal.locked`, `trading.line-item.finalised` (6)              | accounting-service         | `accounting-service.trading.dlx`         |
| `commission-service.trading`                   | `acme.trading`                                       | `trading.deal.locked`, `trading.deal.locked.v2`, `trading.credit-note.finalised` (3)                                                                                                     | commission-service         | `commission-service.trading.dlx`         |
| `inventory-service.trading`                    | `acme.trading`                                       | `trading.#` (1)                                                                                                                                                                          | inventory-service          | `inventory-service.trading.dlx`          |
| `reporting-service.trading`                    | `acme.trading`                                       | `trading.#` (1)                                                                                                                                                                          | reporting-service          | `reporting-service.trading.dlx`          |
| `reporting-service.accounting`                 | `acme.accounting`                                    | `accounting.#` (1)                                                                                                                                                                       | reporting-service          | `reporting-service.accounting.dlx`       |
| `reporting-service.commission`                 | `acme.commission`                                    | `commission.#` (1)                                                                                                                                                                       | reporting-service          | `reporting-service.commission.dlx`       |
| `reporting-service.inventory`                  | `acme.inventory`                                     | `inventory.#` (1)                                                                                                                                                                        | reporting-service          | `reporting-service.inventory.dlx`        |
| `trading-service.accounting.invoice-processed` | `acme.accounting`                                    | `accounting.invoice.processed.#` (1)                                                                                                                                                     | trading-service            | `trading-service.accounting.dlx`         |
| `document-service.events`                      | `acme.trading`, `acme.accounting`, `acme.commission` | `trading.purchase.confirmed`, `trading.sale.confirmed`, `trading.haulage.confirmed`, `trading.overhead.confirmed`, `accounting.invoice.approved`, `commission.commission.calculated` (6) | document-service           | `acme.communication.dlx`                 |
| `jobs.communication.document-generation`       | `acme.communication` (+ default exchange)            | `jobs.document.generate` (1, dead — see below)                                                                                                                                           | document-generation worker | `acme.communication.dlx`                 |
| `notification-service.communication.events`    | `acme.communication`                                 | `communication.document.generated`, `communication.document.failed` (2)                                                                                                                  | notification-service       | `notification-service.communication.dlx` |
| `notification-service.commission.events`       | `acme.commission`                                    | `commission.commission.calculated` (1)                                                                                                                                                   | notification-service       | `notification-service.commission.dlx`    |
| `notification-service.accounting.events`       | `acme.accounting`                                    | `accounting.invoice.failed` (1)                                                                                                                                                          | notification-service       | `notification-service.accounting.dlx`    |
| `notification-service.identity.events`         | `acme.identity`                                      | `identity.workspace.discovery-requested`, `identity.password.reset-requested` (2)                                                                                                        | notification-service       | `notification-service.identity.dlx`      |
| `notification-service.platform.events`         | `acme.platform`                                      | `platform.user.invited` (1)                                                                                                                                                              | notification-service       | `notification-service.platform.dlx`      |
| `user-service.platform.tenant.created`         | `acme.platform`                                      | `platform.tenant.created` (1)                                                                                                                                                            | user-service               | `acme.platform.dlx`                      |
| `audit.events`                                 | `acme.audit-feed`                                    | `''` — empty key on a fanout (1)                                                                                                                                                         | audit-service              | `audit-service.events.dlx`               |

That is **31 routing-key bindings** across the seventeen message-carrying queues.

The `jobs.communication.document-generation` binding deserves a note. The worker binds it to
`acme.communication` with routing key `jobs.document.generate`, but the producer never uses that
route — `document-event-consumer.ts` publishes to the **default exchange** with the queue name as
the routing key:

```ts
await this.rabbitMqConnection.publish(
  "", // default exchange — direct queue routing
  "jobs.communication.document-generation",
  { documentId: doc.id, tenantId },
  { persistent: true }
);
```

The `jobs.document.generate` binding is therefore inert. It is harmless but misleading: an operator
looking at the management UI would reasonably conclude that publishing `jobs.document.generate` to
`acme.communication` triggers document generation, and it does — through a path nothing uses. The
permission model reflects the real path: `document_user`'s `write` regex includes
`jobs\.communication(\..*)?` because publishing to the default exchange checks `write` against the
_routing key_, not the exchange name.

### 5.2 Dead-letter and retention queues — 24

Ten are chart-declared `Queue` CRDs, fourteen are asserted at pod boot. Every one is quorum +
durable and is bound to its DLX with the single key `dead-letter`.

| Retention queue                          | Bound to                                 | Declared by | Actually receives messages?                                |
| ---------------------------------------- | ---------------------------------------- | ----------- | ---------------------------------------------------------- |
| `acme.platform.dlq`                      | `acme.platform.dlx`                      | chart       | **yes** — from `user-service.platform.tenant.created`      |
| `acme.communication.dlq`                 | `acme.communication.dlx`                 | chart       | **yes** — from `document-service.events` and the job queue |
| `acme.identity.dlq`                      | `acme.identity.dlx`                      | chart       | no — see section 8.3                                       |
| `acme.inventory.dlq`                     | `acme.inventory.dlx`                     | chart       | no — see section 8.3                                       |
| `acme.trading.dlq`                       | `acme.trading.dlx`                       | chart       | no — nothing targets that DLX                              |
| `acme.accounting.dlq`                    | `acme.accounting.dlx`                    | chart       | no — nothing targets that DLX                              |
| `acme.commission.dlq`                    | `acme.commission.dlx`                    | chart       | no — nothing targets that DLX                              |
| `acme.reporting.dlq`                     | `acme.reporting.dlx`                     | chart       | no — nothing targets that DLX                              |
| `acme.ai.dlq`                            | `acme.ai.dlx`                            | chart       | no — nothing targets that DLX                              |
| `acme.audit-feed.dlq`                    | `acme.audit-feed.dlx`                    | chart       | no — audit uses its own pair                               |
| `accounting-service.trading.dlq`         | `accounting-service.trading.dlx`         | pod boot    | yes                                                        |
| `commission-service.trading.dlq`         | `commission-service.trading.dlx`         | pod boot    | yes                                                        |
| `inventory-service.trading.dlq`          | `inventory-service.trading.dlx`          | pod boot    | yes                                                        |
| `trading-service.accounting.dlq`         | `trading-service.accounting.dlx`         | pod boot    | yes                                                        |
| `reporting-service.trading.dlq`          | `reporting-service.trading.dlx`          | pod boot    | yes                                                        |
| `reporting-service.accounting.dlq`       | `reporting-service.accounting.dlx`       | pod boot    | yes                                                        |
| `reporting-service.commission.dlq`       | `reporting-service.commission.dlx`       | pod boot    | yes                                                        |
| `reporting-service.inventory.dlq`        | `reporting-service.inventory.dlx`        | pod boot    | yes                                                        |
| `notification-service.communication.dlq` | `notification-service.communication.dlx` | pod boot    | yes                                                        |
| `notification-service.commission.dlq`    | `notification-service.commission.dlx`    | pod boot    | yes                                                        |
| `notification-service.accounting.dlq`    | `notification-service.accounting.dlx`    | pod boot    | yes                                                        |
| `notification-service.identity.dlq`      | `notification-service.identity.dlx`      | pod boot    | yes                                                        |
| `notification-service.platform.dlq`      | `notification-service.platform.dlx`      | pod boot    | yes                                                        |
| `audit-service.events.dlq`               | `audit-service.events.dlx`               | pod boot    | yes                                                        |

**Eight of the ten chart-declared retention DLQs are inert.** That is not an accident of a
half-finished migration — it is the direct consequence of Rules 3 and 6 pulling in opposite
directions. The chart, following Rule 3, keys DLX/DLQ off the exchange; consumers, forced by the
permission model, follow Rule 6 and key them off themselves. Both are internally consistent and
they meet only in the three cases where a service happens to own the `configure` namespace of the
exchange it consumes from.

Counting bindings: 24 dead-letter bindings (10 chart CRDs + 14 asserted at boot) plus 31
message-routing bindings gives the **55 distinct bindings** claimed in section 1.

---

## 6. Per-context close-ups

### 6.1 Trading — the widest fan-out

```mermaid
flowchart TB
  XTR["acme.trading (topic)"]

  QACC["accounting-service.trading<br/>6 explicit keys"]
  QCOM["commission-service.trading<br/>deal.locked + deal.locked.v2 + credit-note"]
  QINV["inventory-service.trading<br/>trading.#"]
  QREP["reporting-service.trading<br/>trading.#"]
  QDOC["document-service.events<br/>4 confirmed keys"]

  DACC["accounting-service.trading.dlx"]
  DCOM["commission-service.trading.dlx"]
  DINV["inventory-service.trading.dlx"]
  DREP["reporting-service.trading.dlx"]
  DCOMM["acme.communication.dlx"]

  XTR --> QACC --> DACC --> LACC["accounting-service.trading.dlq"]
  XTR --> QCOM --> DCOM --> LCOM["commission-service.trading.dlq"]
  XTR --> QINV --> DINV --> LINV["inventory-service.trading.dlq"]
  XTR --> QREP --> DREP --> LREP["reporting-service.trading.dlq"]
  XTR --> QDOC --> DCOMM --> LDOC["acme.communication.dlq"]

  XTRDLX["acme.trading.dlx"] --> XTRDLQ["acme.trading.dlq"]
  XTR -.->|"nothing routes here"| XTRDLX
```

Five consumers on one exchange, and five _different_ dead-letter destinations. The chart's
`acme.trading.dlx` / `acme.trading.dlq` pair sits beside all of it, connected to nothing. What each
of those consumers does with the payload is catalogued in
[`../events/02-event-families.md`](../events/02-event-families.md) §5 and not repeated here; the
topology-level detail is the version coexistence on `commission-service.trading`, which binds both
`trading.deal.locked` and `trading.deal.locked.v2` — the ADR-0036 dual-bind that lets a producer run
a dual-publish transition window without the consumer fleet being upgraded in lockstep.

Note also the binding-breadth asymmetry. Accounting and document bind _explicit_ keys; inventory
and reporting bind `trading.#`. A new `trading.*` event therefore reaches inventory and reporting
automatically and reaches accounting and document only after a code change. Both choices are
defensible — the wildcard consumers are projections that ignore unknown types, the explicit
consumers switch on the routing key — but it means "who receives this new event?" has no single
answer.

### 6.2 Communication — the only context with a job lane

```mermaid
flowchart TB
  subgraph SRC["Source exchanges"]
    XTR2["acme.trading"]
    XAC2["acme.accounting"]
    XCM2["acme.commission"]
  end

  XCO2["acme.communication (topic)"]
  DEF["default exchange<br/>direct-to-queue by name"]

  QDOC2["document-service.events"]
  QJOB2["jobs.communication.document-generation"]
  QNC["notification-service.communication.events"]

  XTR2 --> QDOC2
  XAC2 --> QDOC2
  XCM2 --> QDOC2
  QDOC2 -->|"publish job"| DEF --> QJOB2
  XCO2 -.->|"jobs.document.generate — bound but unused"| QJOB2
  QJOB2 -.->|"outbox only — document-service relay is OFF (§12 D1)"| XCO2
  XCO2 --> QNC

  QDOC2 --> DLXC["acme.communication.dlx"]
  QJOB2 --> DLXC
  DLXC --> DLQC["acme.communication.dlq"]
  QNC --> DLXN["notification-service.communication.dlx"] --> DLQN["notification-service.communication.dlq"]
```

This is the one loop that is fully wired at the broker and broken at the relay: document-service
consumes finalisation events from three foreign contexts, creates a `PENDING` document row,
enqueues a generation job, the worker generates the artifact and writes
`communication.document.generated` to the outbox — where it stops, because the relay that would
drain it is disabled (section 12, defect D1). Only once that relay runs does notification-service
see the event and send the email. The job hop is deliberately _not_ through the outbox — the comment
in the code explains that the document row is already committed before the job fires, so the
outbox's atomicity guarantee buys nothing:

```ts
// Publish generation job to the document-generation worker queue.
// This is published directly (not via outbox) because the persist+flush
// above already committed — the document record exists before the job fires.
```

The worker is also deliberately self-sufficient: it asserts `acme.communication`,
`acme.communication.dlx`, `acme.communication.dlq` and the binding itself rather than relying on
`DocumentEventConsumer` having booted first, because both live in the same pod but Nest gives no
ordering guarantee between two `OnModuleInit` providers.

### 6.3 Identity and Platform — where the invite pipeline lives

```mermaid
flowchart TB
  RA2["auth-service relay"] --> XID2["acme.identity (topic)"]
  RT2["tenant-service relay"] --> XPL2["acme.platform (topic)"]
  RU2["user-service relay"] --> XPL2

  XPL2 -->|"platform.tenant.created"| QU["user-service.platform.tenant.created"]
  XPL2 -->|"platform.user.invited"| QNP["notification-service.platform.events"]
  XID2 -->|"identity.password.reset-requested<br/>identity.workspace.discovery-requested"| QNI["notification-service.identity.events"]

  QU --> DPL["acme.platform.dlx"] --> LPL["acme.platform.dlq"]
  QNP --> DNP["notification-service.platform.dlx"] --> LNP["notification-service.platform.dlq"]
  QNI --> DNI["notification-service.identity.dlx"] --> LNI["notification-service.identity.dlq"]

  QU -->|"creates Invitation<br/>publishes platform.user.invited"| RU2
```

The cycle in that diagram is real, not a drawing artefact: user-service both consumes from and
publishes to `acme.platform`, so the exchange feeds itself. The event-by-event walk of that invite
pipeline — who emits what, and what each consumer does with it — is in
[`../events/02-event-families.md`](../events/02-event-families.md) §4; the consequence that belongs
here is a permission one. Because producer and consumer share one exchange, user-service's
`write` regex had to be widened to include its own queue namespace — binding a queue requires write
on the _destination queue_, and without `user-service\..*` in `write` the bind returns 403 and the
pod crash-loops. The chart values record the fix inline:

> `user-service\..*` in WRITE: binding a consumer queue X to an exchange needs WRITE on X
> (queue.bind → write-on-destination). … without this the bind 403s ACCESS_REFUSED and the
> consumer crash-loops — the same fix already applied for `trading_user`.

This lane carries bearer secrets — the invite accept token and the password-reset token travel in
the event payload — which produces two topology-visible behaviours. First, the relay strips
declared secret paths from the **audit-feed copy only** (`auditSecretFields`), leaving the BC lane
intact so notification-service can build the email link. Second, notification-service refuses to
nack a token-bearing message: `TOKEN_BEARING_ROUTING_KEYS` (`platform.user.invited`,
`identity.password.reset-requested`) are acked-and-dropped with a scrubbed operator alert on a
pre-send failure, precisely so that a raw token never comes to rest in
`notification-service.platform.dlq`. The recovery is to resend the invitation, which mints a fresh
token.

### 6.4 The audit fanout

```mermaid
flowchart LR
  R1["auth relay"] --> AF["acme.audit-feed (fanout)"]
  R2["tenant relay"] --> AF
  R3["user relay"] --> AF
  R4["inventory relay"] --> AF
  AF -->|"binding key is the empty string"| QA2["audit.events (quorum)"]
  QA2 --> ADX["audit-service.events.dlx (fanout)"]
  ADX --> ADQ["audit-service.events.dlq"]
  AFD["acme.audit-feed.dlx"] --> AFQ["acme.audit-feed.dlq"]
  AF -.->|"no route — inert pair"| AFD
```

The audit consumer is the only one whose source exchange is a fanout, and that has a subtle
knock-on effect on the DLX type. The shared helper asserts the dead-letter exchange with the
**source exchange's** type, not a hardcoded `topic`:

```ts
await channel.assertExchange(config.dlx, config.exchangeType, {
  durable: true,
});
```

Because `AuditEventConsumer` passes `exchangeType: 'fanout'`, `audit-service.events.dlx` is created
as a **fanout**. The chart, by contrast, hardcodes every `<exchange>.dlx` to `topic`. The two never
collide today only because audit does not use the chart's `acme.audit-feed.dlx` name — it cannot,
since `audit_user`'s `configure` regex does not match it. Had the names coincided, the runtime
fanout declare against the chart's topic exchange would fail with `PRECONDITION_FAILED` and
crash-loop the pod. This is a latent trap for any future fanout-sourced consumer that lets the
explorer derive `<exchange>.dlx` for it.

---

## 7. Declaration order at boot

The shared helper declares in a fixed order, and every step of that order has a failure it is
guarding against. The full sequence in `setup-rabbit-consumer.ts`:

```mermaid
sequenceDiagram
    autonumber
    participant P as Consumer pod
    participant C as AMQP confirm channel
    participant B as Broker

    P->>C: checkExchange(source)
    C->>B: exchange.declare passive=true
    Note over B: 404 if absent — channel closes, boot fails
    B-->>C: ok

    P->>C: assertExchange(dlx, exchangeType, durable)
    Note over B: must precede the queue — a quorum queue<br/>referencing an undeclared DLX is rejected
    B-->>C: ok

    P->>C: assertQueue(dlq, quorum + durable)
    P->>C: bindQueue(dlq, dlx, 'dead-letter')
    Note over B: DLQ bound BEFORE the main queue exists,<br/>so no window where a nack has nowhere to land
    B-->>C: ok

    P->>C: assertQueue(main, quorum + DLX args)
    B-->>C: ok

    loop each routing key
        P->>C: bindQueue(main, source, key)
    end

    P->>C: prefetch(1)
    P->>C: consume(main)
    B-->>P: deliveries begin
```

Three orderings in that diagram are asserted by unit tests rather than left to convention:

- _"asserts the DLX exchange BEFORE the queue that references it — #958"_ compares the recorded
  call order and requires `dlxIndex < queueIndex`.
- _"asserts the DLQ AFTER the DLX it binds to (#976 P3)"_ requires the `assertExchange(dlx)` call to
  precede `bindQueue(dlq, dlx, 'dead-letter')`.
- _"does NOT declare a DLQ when config.dlq is omitted (back-compat)"_ pins the optionality.

One consumer deviates: `document-event-consumer.ts` asserts its DLX, DLQ and main queue _first_ and
only then calls `checkExchange` on its three source exchanges. The end state is identical, but the
failure mode differs — if `acme.trading` is missing, document-service has already created its
queues before crashing, whereas every other consumer crashes before creating anything.

### What a consumer does when its source exchange does not exist

`checkExchange` is a passive `exchange.declare`. Against a missing exchange the broker replies 404
and **closes the channel**; `amqplib` rejects the promise. Neither `setupRabbitConsumer` nor
`setupRabbitConsumerWithReconnect` swallows that — the reconnecting variant awaits its initial
`setup()` on the last line and lets the rejection propagate. Every caller's `OnModuleInit` therefore
throws, Nest aborts bootstrap, and the pod exits into `CrashLoopBackOff`.

That is the intended behaviour, and it is why the chart pre-declares all ten chart-owned exchanges rather
than letting the owning service create its own on first publish. The chart states the reasoning:

> Declaring the exchanges here (instead of relying on the owning service to have started) removes
> the cross-service startup-ordering coupling that otherwise crash-loops consumers when an upstream
> BC is down.

Note the asymmetry with the _reconnect_ path: once a consumer has booted successfully, a later
channel close schedules a bounded exponential-backoff reconnect (`computeBackoffMs`, capped at
30 s, bounded by `DEFAULT_MAX_RECONNECT_ATTEMPTS`, with the failure counter reset to zero after
every successful setup so a long-lived pod surviving many isolated blips never silently gives up).
Recovery is driven by the `close` event only — `error` is log-only — because `amqplib` emits
`error` then `close` on a server-side channel exception and reacting to both would start two
overlapping reconnect chains, leaking a channel and double-consuming.

### Redeclare semantics: what happens when two declarers disagree

RabbitMQ's `exchange.declare` and `queue.declare` are idempotent **only when every property
matches**. A mismatch returns `PRECONDITION_FAILED` and closes the channel. The properties that
must agree between the chart CRD and the runtime assert:

| Object   | Properties compared on redeclare                                                          | Where the two sides are pinned                                                                                                                             |
| -------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Exchange | `type`, `durable`, `autoDelete`, `internal`, arguments                                    | chart: `type: topic`, `durable: true`, `autoDelete: false`; runtime: `assertExchange(name, 'topic', { durable: true })`                                    |
| Queue    | `durable`, `exclusive`, `autoDelete`, and **all** `x-` arguments including `x-queue-type` | chart: `durable: true`, `arguments: { x-queue-type: quorum }`; runtime: same, plus `x-dead-letter-exchange` and `x-dead-letter-routing-key` on main queues |

The chart's `dlx-exchange.yaml` spells out the coupling requirement:

> NAME + TYPE must match the runtime `assertExchange` exactly so a redeclare is idempotent and
> never throws `PRECONDITION_FAILED`.

There is a live inconsistency hiding in the queue row. The chart's retention DLQ CRDs declare
`arguments: { x-queue-type: quorum }` and nothing else. The runtime redeclare of those same
retention DLQs (document-service and user-service reusing `acme.communication.dlq` and
`acme.platform.dlq`) also passes only `x-queue-type: quorum` — so they agree. But if anyone were to
add a dead-letter argument to a chart-declared retention DLQ without adding it to the code, or vice
versa, every pod reusing that DLQ would crash-loop on redeclare with no obvious cause.

### CRD immutability

The Messaging Topology Operator's admission webhooks reject in-place edits to the identity of an
object. The chart documents both cases:

- `vexchange.kb.io` rejects updates to `spec.name`, `spec.vhost`, `spec.type`, `spec.durable`,
  `spec.autoDelete`. Changing an exchange's type leaves ArgoCD in a permanent OutOfSync loop until
  the CR is deleted (`kubectl delete exchange <name> -n platform-identity`), after which ArgoCD
  recreates it. **Any publisher or consumer asserting the exchange during that gap gets NOT_FOUND.**
- `vpermission-v1beta1.kb.io` rejects updates to `user`, `userReference`, `vhost`,
  `rabbitmqClusterReference` **and** to the `spec.permissions` triplet. Tightening a permission
  regex therefore requires deleting the Permission CRDs first; services mid-publish during the gap
  get 403'd.

Neither is a rolling change. Both need a coordinated window.

### ArgoCD sync waves

| Wave | Objects                                                  | Why this wave                                                   |
| ---- | -------------------------------------------------------- | --------------------------------------------------------------- |
| −10  | Messaging Topology Operator + CRDs                       | operator must exist before any topology CR is applied           |
| −6   | 12 per-service ExternalSecrets + admin ExternalSecret    | credential Secrets must exist before `User` CRDs reference them |
| −5   | `Vhost`, 12 `User`                                       | vhost before anything declared on it                            |
| −4   | 20 `Exchange`, 10 `Queue`, 10 `Binding`, 12 `Permission` | exchanges land after the vhost; Permission lands after User     |
| 0+   | bundle Applications (the service Deployments)            | consumers boot only once topology and credentials exist         |

The within-wave ordering rationale is worth recording because it is not obvious: **ArgoCD applies
resources within a single wave alphabetically by kind.** `Exchange` sorts before `Vhost` and
`Permission` sorts before `User`, so co-locating them would produce transient "vhost not found" and
"user not found" reconcile errors that eventually converge but pollute every sync. The separate
waves buy quiet first reconciles, not correctness.

One drift here: `values.yaml` defines `syncWaves.vhost: '-5'` and `syncWaves.user: '-5'`, but
`vhost.yaml` and `user.yaml` both render the **deprecated flat** `.Values.syncWave` instead. The two
values coincide today, so behaviour is correct — but editing `syncWaves.vhost` would silently do
nothing.

---

## 8. The dead-letter chain, end to end

### 8.1 The chain

```mermaid
flowchart TB
  MSG["message delivered to consumer queue"]
  H{"handler resolves?"}
  ACK["channel.ack(msg)"]
  NACK["channel.nack(msg, false, false)<br/>allUpTo=false, requeue=false"]
  Q["consumer queue<br/>x-dead-letter-exchange: DLX<br/>x-dead-letter-routing-key: dead-letter"]
  DLX2["DLX (topic)"]
  BIND{"binding key<br/>= dead-letter?"}
  DLQ2["retention DLQ (quorum, no TTL, no max-length)"]
  DROP["message discarded silently"]
  MAN["manual rabbitmqadmin get / republish"]

  MSG --> H
  H -->|yes| ACK
  H -->|"throws or JSON.parse fails"| NACK
  NACK --> Q --> DLX2 --> BIND
  BIND -->|yes| DLQ2
  BIND -->|no| DROP
  DLQ2 --> MAN
```

The crucial mechanic is the **routing-key rewrite**. When the broker dead-letters a message it does
not reuse the original routing key: because the queue sets `x-dead-letter-routing-key:
'dead-letter'`, the message arrives at the DLX with the key `dead-letter`, which is exactly the key
the retention DLQ is bound with. That rewrite is what makes a single fixed binding sufficient for a
topic DLX carrying messages that originally had dozens of distinct keys.

### 8.2 The exact nack conditions

Both the shared helper and the explorer's inline setup wrap the handler identically:

```ts
await channel.consume(config.queue, async (msg) => {
  if (!msg) return;
  try {
    const event = JSON.parse(msg.content.toString()) as DomainEvent<TPayload>;
    await handler(event);
    channel.ack(msg);
  } catch (error) {
    logger.error(
      `Failed to process message on ${config.queue} — nack to DLX (${config.dlx}): …`
    );
    channel.nack(msg, false, false);
  }
});
```

So a message dead-letters when the body is not valid JSON, or when the handler throws for any
reason — a transient database error is treated identically to a permanent contract violation. There
is no retry budget, no delay queue, no redelivery count. **The first failure is the last.** Several
consumers add domain-level guards on top (accounting and trading both reject an event missing
`tenantId` straight to the DLX), and inventory and trading add an inbox table so a _redelivery_ is a
no-op — but nothing in the transport layer retries.

This is a direct contradiction of ADR-0017, which specifies:

> Failed messages are re-queued with TTL-based exponential backoff. After max retries, messages land
> in a Dead Letter Queue (DLQ) per job type for inspection. DLQ naming: `dlq.{service}.{purpose}`.

None of that shipped. There is no TTL-based retry queue anywhere, and the DLQ naming is
`<owner>.<source>.dlq`, not `dlq.<service>.<purpose>`. The code is the source of truth; the ADR
records an intent that was never implemented.

### 8.3 The second, broken entry path into the DLX

Consumer nacks are not the only thing that reaches a DLX. The outbox relay publishes **directly** to
`<exchange>.dlx` when it detects that an entry's `version` field disagrees with its routing key's
`.vN` suffix (ADR-0036 relay enforcement):

```ts
private async dlxRoute(channel, exchange, payload, originalPayload, eventId, rawVersion?) {
  const dlxExchange = `${exchange}.dlx`;
  const dlxRoutingKey = payload.originalRoutingKey;   // e.g. "trading.deal.locked.v2"
  …
  await this.publishOnce(channel, dlxExchange, dlxRoutingKey, buffer, options);
}
```

The envelope is a structured `VersionMismatchDlxPayload` and the original payload is preserved
verbatim on the `x-acme-original-payload` header for replay tooling. But the publish uses
`originalRoutingKey`, **not** `dead-letter` — and the DLX's only binding is the literal
`dead-letter`. A topic exchange does not match `trading.deal.locked.v2` against a binding pattern of
`dead-letter`, so the message is unroutable and dropped. The relay's own doc comment half-admits it:

> NOTE: `<exchange>.dlx` is declared (#976 P4) but has no bound DLQ yet, so the published copy is
> not retained — the WARN log is the current forensic record.

That comment is now stale in one direction and correct in the other: the DLQ _is_ bound (the chart
renders it), but the message still does not reach it, because the key does not match. The fix is
either to publish the mismatch envelope with the `dead-letter` key or to add a `#` binding on each
`<exchange>.dlx`. Neither has landed.

This is also why `acme.identity.dlq` and `acme.inventory.dlq` show "no" in the section 5.2 table
despite auth's and inventory's relays actively asserting `acme.identity.dlx` and
`acme.inventory.dlx`: those DLXes receive version-mismatch publishes and drop every one of them.

### 8.4 What drains a DLQ

**Nothing automated.** No component in the repository consumes from any `*.dlq`. There is no
reprocess worker, no shovel definition, no scheduled replay job. The `rabbitmq_shovel` plugin is
enabled on the broker but no shovel is configured.

What exists instead:

1. **An alert.** The monitoring runbook defines `platform-dlq-not-empty`, plus a per-service
   Prometheus rule `sum by (queue)(rabbitmq_queue_messages{queue=~"trading-service\\..*dlq"}) > 0`
   for 1 minute at `critical`. Its guidance is _"Any value > 0 is critical: a message was nacked to
   the DLX. Inspect, fix the cause, and replay."_ Escalation threshold: a DLQ beyond 100 messages,
   or any DLQ containing financial transaction data.
2. **A manual replay loop** in the same runbook, built on `rabbitmqadmin get` and a re-publish. It
   is a copy-paste procedure, not tooling.
3. **A post-deploy verification script**, `scripts/ci/dlq-functional-smoke.sh`, which proves the
   chain works end to end by publishing one uniquely-tagged poison message into a named source
   queue and polling the DLQ until _that specific message id_ appears — deliberately not merely a
   depth increase, which would race with real traffic and produce false passes. It refuses to run if
   the DLQ is non-empty at baseline, and its cleanup trap removes only its own tagged message. It is
   explicitly not a CI gate: it mutates a live broker.

Combined with the absence of any TTL or max-length, this means a dead-lettered message is retained
indefinitely and requires a human to act. That is a defensible design for a financial system — silent
expiry of a failed invoice event would be worse — but it makes the alert the only backstop.

---

## 9. Topology ownership summarised

```mermaid
flowchart TB
  subgraph GIT["git — charts/platform-rmq-bootstrap"]
    VALS["values.yaml<br/>services[12] + exchanges[10]"]
  end
  subgraph ARGO["ArgoCD sync of identity-bundle"]
    REND["helm template → 78 manifests"]
  end
  subgraph K8S["Kubernetes — namespace platform-identity"]
    CRDS["1 Vhost · 20 Exchange · 10 Queue<br/>10 Binding · 12 User · 12 Permission"]
    ESO["13 ExternalSecrets"]
  end
  subgraph OP["messaging-topology-operator (ns rabbitmq-system)"]
    RECON["reconcile loop<br/>watch scope: platform-identity, rabbitmq"]
  end
  BROKER["RabbitMQ StatefulSet<br/>management API :15672"]
  PODS["12 service pods<br/>AMQP :5672"]

  VALS --> REND --> CRDS
  REND --> ESO
  ESO -->|"projects credentials"| CRDS
  CRDS --> RECON -->|"HTTP PUT /api/…"| BROKER
  PODS -->|"assertExchange · assertQueue · bindQueue"| BROKER
```

Rendering the chart produces exactly **78 manifests**: 20 `Exchange`, 13 `ExternalSecret`,
12 `Permission`, 12 `User`, 10 `Queue`, 10 `Binding`, 1 `Vhost`. The chart README still claims
_"38 manifests in total: 12 Users + 12 Permissions + 12 per-service ExternalSecrets + 1 Vhost + 1
admin ExternalSecret"_ — accurate before the Exchange/DLX/DLQ/Binding templates were added, stale
now. It also still describes the chart as "Phase 1 … not yet wired into a bundle", which
`identity-bundle/Chart.yaml` contradicts: the dependency on `platform-rmq-bootstrap` version 0.1.6
is present.

The ownership boundary in one sentence: **the chart owns everything shared across contexts and
everything that must exist before any pod boots; a service owns everything inside its own
`configure` namespace and declares it at `OnModuleInit`.** The only objects declared twice are the
three chart-owned dead-letter resources that a service also happens to be permitted to declare.

---

## 10. The credential model and the drift it produces

### 10.1 The chain

```mermaid
flowchart LR
  TF["Terraform random_password.rmq_user<br/>one per service"]
  KV["Key Vault secret<br/>platform-SVC-rabbitmq-password"]
  ESOA["ExternalSecret in the bundle namespace<br/>projects Secret SVC-secrets"]
  ESOB["ExternalSecret in platform-identity<br/>projects Secret platform-rmq-service-SVC"]
  POD["service pod<br/>RABBITMQ_URI composed from env"]
  USR["User CRD<br/>importCredentialsSecret"]
  OPR["topology operator"]
  BRK["broker user SVC_user"]

  TF --> KV
  KV --> ESOA --> POD
  KV --> ESOB --> USR --> OPR --> BRK
  POD -->|"AMQP PLAIN handshake"| BRK
```

One Key Vault secret, **two independent ExternalSecret consumers**, and they must converge on the
same value for the handshake to succeed. The pod side composes the URI at deploy time by env-var
substitution rather than storing a composed URI:

```yaml
- name: RABBITMQ_PASSWORD
  valueFrom:
    secretKeyRef: { name: auth-secrets, key: rabbitmq-password }
- name: RABBITMQ_URI
  value: "amqp://auth_user:$(RABBITMQ_PASSWORD)@rabbitmq.rabbitmq.svc.cluster.local:5672/acme"
```

The operator side reads the same Key Vault key into `platform-rmq-service-<svc>` with an added
literal `username: <svc>_user`, because `User.spec.importCredentialsSecret` requires both keys while
Key Vault holds only the password.

Twelve services have RabbitMQ users: auth, tenant, user, inventory, trading, ai, audit, reporting,
accounting, notification, document, commission. The gateway is the only service with
`hasRabbitMQ: false`.

### 10.2 The permission matrix

Each `Permission` CRD carries three RabbitMQ regexes matched against **resource names** — exchanges,
queues and bindings — never against routing keys.

| User                | `configure`                                                                       | `write` adds                                                                   | `read` covers                                                                  |
| ------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `auth_user`         | `acme.identity(\..*)?`, `auth-service\..*`                                        | `acme.audit-feed(\..*)?`                                                       | identity, platform, own queues                                                 |
| `tenant_user`       | `acme.platform(\..*)?`, `tenant-service\..*`                                      | `acme.audit-feed(\..*)?`                                                       | platform, identity, own queues                                                 |
| `user_user`         | `acme.platform(\..*)?`, `user-service\..*`                                        | `acme.audit-feed(\..*)?`, `user-service\..*`                                   | platform, identity, own queues                                                 |
| `inventory_user`    | `acme.inventory(\..*)?`, **`acme.audit-feed(\..*)?`**, `inventory-service\..*`    | `acme.audit-feed(\..*)?`, `inventory-service\..*`                              | inventory, trading, platform, identity, own queues                             |
| `trading_user`      | `acme.trading(\..*)?`, `trading-service\..*`                                      | `acme.audit-feed(\..*)?`, `trading-service\..*`                                | trading, platform, identity, **accounting**, own queues                        |
| `ai_user`           | `acme.ai(\..*)?`, `ai\.signals\..*`                                               | `acme.audit-feed(\..*)?`                                                       | ai, trading, inventory, accounting, commission, reporting, platform, identity  |
| `audit_user`        | `audit\.events`, `audit-service\..*`                                              | `acme.audit-feed(\..*)?`, `audit\.events`, `audit-service\..*`                 | audit-feed, `audit.events`, own queues                                         |
| `reporting_user`    | `acme.reporting(\..*)?`, `reporting-service\..*`                                  | `acme.audit-feed(\..*)?`, `reporting-service\..*`                              | reporting, trading, inventory, accounting, commission, platform, identity      |
| `accounting_user`   | `acme.accounting(\..*)?`, `accounting-service\..*`                                | `acme.audit-feed(\..*)?`, `accounting-service\..*`                             | accounting, trading, platform, identity, own queues                            |
| `notification_user` | `acme.communication(\..*)?`, `notification-service\..*`                           | `acme.audit-feed(\..*)?`, `notification-service\..*`                           | communication, commission, accounting, platform, identity, own queues          |
| `document_user`     | `acme.communication(\..*)?`, `document-service\..*`, `jobs\.communication(\..*)?` | `acme.audit-feed(\..*)?`, `document-service\..*`, `jobs\.communication(\..*)?` | communication, trading, accounting, commission, platform, identity, own queues |
| `commission_user`   | `acme.commission(\..*)?`, `commission-service\..*`                                | `acme.audit-feed(\..*)?`, `commission-service\..*`                             | commission, trading, platform, identity, own queues                            |

Every producer gets `write` on `acme.audit-feed` because the relay dual-publishes. Only
`inventory_user` gets **`configure`** on it — a bridge grant, marked TEMPORARY in the values file
pending the passive-`checkExchange` fix. That fix has shipped:
`EventBusModule.createOutboxRelay` now calls `checkExchange(AUDIT_FEED_EXCHANGE)`. The over-grant is
therefore stale and revocable, and the helm-unittest that was supposed to prevent it becoming
permanent only asserts against `documentIndex: 0` — the _auth_ Permission — so it passes while the
inventory grant remains.

There is no `spec.user` anywhere; every Permission uses `spec.userReference.name`. The chart records
why: a first cut passed the short service name literally to the broker as an AMQP login and produced
`vhost_or_user_not_found` on the `PUT`.

### 10.3 The drift failure

A single Key Vault value feeding two independent sync paths is the whole failure mode. If the broker
user's password and the pod's password diverge, the AMQP `PLAIN` handshake returns
`403 ACCESS_REFUSED`, and — crucially — **the failure is latent**. Running pods hold cached AMQP
connections and keep working; the divergence only surfaces on the next fresh handshake, which is
usually the next deploy.

The recorded incident (dev only, three services down: commission, document, notification) followed
exactly that shape. At the time the design was worse — _two_ Key Vault secrets per service, a
composed `-uri` that embedded the password plus a separate raw `-password`, both carrying
`lifecycle { ignore_changes = [value] }`. A past `terraform state rm` dropped the backing
`random_password` resources; because Terraform was told to ignore value changes it never reconciled
them, and the two secrets drifted apart with no plan signal. The redeploy forced fresh handshakes and
surfaced three simultaneous 403s.

Five properties of that incident generalise and are worth internalising:

1. **Two secrets for one credential is drift-prone by construction.** Any design where the same
   secret is stored twice will eventually store two different values.
2. **`ignore_changes = [value]` hides drift.** Terraform never reconciles, so a state loss is silent
   until something reads both copies.
3. **Cached AMQP connections mask the failure.** Drift is invisible until a restart — which also
   means **rollback is useless**: an older image reconnects fresh and fails identically.
4. **Key Vault purge protection forbids delete-and-recreate.** Rotation has to happen in place.
5. **The topology operator does not re-push on a Secret content change.** Changing the projected
   Secret is not enough; the `User` CR must be recreated.

Two of the five have since been fixed in source. The composed-URI secret was deleted outright — the
Terraform module now carries only one `key_vault_secret.rmq_password` resource per service, with an
explanatory block where the URI resource used to be — and `ignore_changes` was removed, restoring
reconciliation. That removal introduced its own hazard, documented in the resource:

> PRE-APPLY GUARD: because `ignore_changes` is gone, ANY divergence between TF state and the live KV
> value is clobbered on apply. Run the drift audit in `scripts/platform/rmq-reimport-preflight.sh`
> before every apply that touches this resource.

The documented rotation procedure is now four steps, and the fourth is the one people forget:

```bash
terraform apply -replace='…random_password.rmq_user["<svc>"]'
  → Terraform writes the new value to Key Vault
  → ESO syncs both Secrets on its refresh interval (1h)
  → kubectl delete user.rabbitmq.com <svc> -n platform-identity
      (ArgoCD self-heals the CR; only then does the operator re-push the credential)
```

### 10.4 The admin credential, and a live username discrepancy

The operator's own connection to the broker uses a separate admin credential projected into
`platform-rmq-admin-connection` with keys `uri`, `username`, `password`. The password comes from a
Terraform-managed `random_password.rabbitmq_admin` in Key Vault. If anyone runs
`rabbitmqctl change_password` directly on the broker, the operator's cached connection secret still
holds the old value and **all** CRD reconciliation fails with 401 — silently, because a failed
reconcile is not a failed sync. Recovery requires updating Key Vault _and_ restarting the operator
pod to bust its connection-secret cache.

There is an unresolved discrepancy about who the admin actually is:

- `charts/infrastructure/rabbitmq-values.yaml` bootstraps the broker with `auth.username: acme`.
- `charts/platform-rmq-bootstrap/values.yaml` sets `admin.username: platform`, with a comment
  claiming the value was confirmed live via `rabbitmqctl list_users`.

`scripts/ci/dlq-functional-smoke.sh` flags this explicitly as a repo discrepancy for a human to
resolve, defaults to the chart value, and notes that the authoritative live value lives in the
`platform-rmq-admin-connection` Secret's `username` key. It cannot be resolved from source alone.

---

## 11. Local development topology — a deliberate divergence

Local Docker Compose runs `rabbitmq:3-management-alpine` with a preloaded definitions file. It is
**not** the cluster topology, and the differences are large enough that a topology bug can pass
locally and fail in the cluster:

| Property           | Cluster                                  | Local Compose                                                    |
| ------------------ | ---------------------------------------- | ---------------------------------------------------------------- |
| Broker image       | RabbitMQ 4.1.x, vendored + digest-pinned | `rabbitmq:3-management-alpine`                                   |
| vhost              | `acme`                                   | `/`                                                              |
| Users              | 12 per-service principals                | 1 (`platform`)                                                   |
| Permissions        | 12 BC-scoped regex triplets              | `.* .* .*`                                                       |
| Exchange source    | 20 Exchange CRDs                         | 13 preloaded definitions                                         |
| Queues             | 41, all quorum                           | 2 preloaded, no queue-type argument                              |
| Default queue type | `quorum` via broker config               | broker default (classic) — code passes `x-queue-type` explicitly |

Three specific traps in the local definitions:

1. **`acme.trading.dlx` is declared as a `fanout` locally** but as a `topic` in the chart and in
   every runtime assert. Nothing currently asserts that exchange (trading runs no relay and every
   trading consumer uses its own `<svc>.trading.dlx`), so the mismatch is latent — but the moment a
   component does assert it, local development will fail with `PRECONDITION_FAILED` in a way the
   cluster never will.
2. **Two legacy exchanges, `platform.events` and `platform.dlx`, plus a `platform.dead-letters`
   queue, are preloaded and referenced by nothing.**
3. **A blanket `.* .* .*` permission** means every permission-regex bug is invisible locally.
   Every 403 in the incident record would have passed local testing.

Integration tests take a third path again: `RabbitMqTestHelper` starts a throwaway
`rabbitmq:3-management-alpine` Testcontainer with `guest`/`guest` and no preloaded definitions at
all, which is why `event-handler-explorer.ts`'s `setupConsumerInline` uses an **active**
`assertExchange` on the source exchange rather than the passive `checkExchange` the production
helper uses:

```ts
// Declare the source exchange — assertExchange (not checkExchange) so it
// works in fresh testcontainer brokers and dev environments without needing
// the Exchange CRD to have run first. BC-isolation is enforced by ACLs.
```

That divergence is deliberate and documented, but it means the explorer path would need the
`configure` permission that BC isolation withholds — one more reason it is not used in production.

---

## 12. Verified defects and open drift

Each of these was confirmed against source while writing this document. They are ordered by blast
radius.

**D1 — Eight of twelve services write to an outbox that nothing drains.**
`enableRelay: true` is set for exactly four services: auth, tenant, user, inventory. It is `false`
for trading, accounting, commission, document, notification, reporting, audit and ai. Trading, for
example, has a full `TradingEventPublisher` writing `trading.*` entries to `outbox_entry` on every
sale, purchase, haulage and overhead mutation — and no relay to publish them. `EventBusModule` logs
a warning at startup for exactly this case (_"OutboxRelay is DISABLED — events written to outbox
will NOT be published to RabbitMQ"_), and trading-service even ships an `outbox-lag.observer.ts`
that exports `acme_trading_outbox_lag_seconds` from the age of the oldest `PENDING` row. The
consequence at the topology level is that `acme.trading`, `acme.accounting` and `acme.commission` —
the three exchanges with the most consumer queues between them — currently receive nothing, so the
nine queues bound to them are idle.

**D2 — Background jobs enqueued through the outbox can never be published.**
`JobEnqueuer` writes an `OutboxEntry` with `entryType = JOB` and both `eventType` and `routingKey`
set to the queue name, e.g. `jobs.accounting.erp-posting`. The relay derives the exchange from the
first dotted segment, which for that entry is `acme.jobs` — an exchange that does not exist in the
chart, in the local definitions, or anywhere else. Publishing to a missing exchange closes the
channel with `NOT_FOUND`. The point is currently moot only because accounting-service, the sole
`JobEnqueuer` user, has `enableRelay: false` (D1), so the entries never get as far as a publish.

**D3 — `@EventHandler` is a no-op in production.**
`EventHandlerExplorer` is exported from `@acme/event-bus` and thoroughly unit- and
testcontainer-tested, but a repository-wide search finds `new EventHandlerExplorer(...)` only inside
test files. No application module instantiates it. Consequently the eleven `ai.signals.*` queues
declared by ai-service's six decorator-based consumers do not exist on the broker, and neither do
their bindings. `user-service` discovered this the hard way and rewrote its
`platform.tenant.created` consumer by hand; its source comment is the clearest statement of the
defect: _"the `@EventHandler` decorator is a dead no-op in production (no `EventHandlerExplorer` is
ever instantiated), so relying on it left user-service NEVER declaring/binding its queue and the
first-admin invite never fired."_ Two of user-service's three decorated handlers
(`identity.user.login`, `platform.tenant.suspended`) remain dead.

**D4 — Version-mismatch envelopes are published to a key that matches no binding.**
Covered in section 8.3. The relay's `dlxRoute` publishes with `originalRoutingKey` while the only
DLX binding is the literal `dead-letter`. The structured mismatch envelope, and the original payload
carried on `x-acme-original-payload` for replay, are both dropped. The WARN log is the sole record.

**D5 — Eight of ten chart-declared retention DLQs are inert.**
Covered in section 5.2. `acme.trading.dlq`, `acme.accounting.dlq`, `acme.commission.dlq`,
`acme.reporting.dlq`, `acme.ai.dlq` and `acme.audit-feed.dlq` have nothing routing to their DLX at
all; `acme.identity.dlq` and `acme.inventory.dlq` sit behind DLXes that receive only the D4
publishes and therefore stay empty.

**D6 — The inventory `configure` over-grant on `acme.audit-feed` outlived its cause, and its guard
test does not guard it.** Covered in section 10.2.

**D7 — The ADR-0017 retry model was never built.** No TTL retry queues, no delay queues, no
`x-delivery-limit`, no redelivery counting at the transport layer. First handler failure equals
dead-letter. Covered in section 8.2.

**D8 — `ai-service` is deployed but absent from the service registry.**
`charts/argocd/applicationset.yaml` renders a standalone `platform-ai` Application in namespace
`platform-ai` with a full `RABBITMQ_URI` and a NetworkPolicy egress to the broker, and the bootstrap
chart provisions `ai_user` with an eleven-context `read` scope. But `charts/services.yaml` — which
the file itself calls _"Single Source of Truth"_ and which is the source for the
`OUTBOX_ADVISORY_LOCK_ID` uniqueness check — has no `ai-service` entry. So ai-service has broker
credentials and broad read permissions, but no allocated advisory lock id, and (per D3) no queues.

**D9 — The chart README's manifest count and phase description are stale.**
Covered in section 9: 78 rendered manifests versus a documented 38, and "not yet wired into a
bundle" versus a live `identity-bundle` dependency on version 0.1.6.

**D10 — `syncWaves.vhost` and `syncWaves.user` are declared but unreferenced.**
Covered in section 7. Both templates render the deprecated flat `syncWave`.

**D11 — ADR-0049's Context section misdescribes the file it critiques.**
Covered in section 3: `replicaCount` and the image-pinning claim are both out of date. The ADR's
decision remains unimplemented for the broker.

**D12 — The admin username is inconsistent between the two charts that reference it.**
Covered in section 10.4. Unresolvable from source; the live value is in the connection Secret.

---

## 13. Onboarding a service to the bus

Everything above is inventory. This is the procedure it implies, in the order the objects have to
exist. Each step names the failure you get if you skip it.

**1. Decide whether the service needs a new bounded-context exchange.** One topic exchange per
bounded context, `acme.<bc>` (Rule 1). A new context means one new entry with `name` and `type` in
the bootstrap chart's `exchanges[]` — the template render fails on a malformed entry, which is the
cheap failure. That single entry produces four objects: the exchange, `<name>.dlx`, `<name>.dlq`
and the `dead-letter` binding between them (sections 4.1, 4.2 and 5.2). A service that only _consumes_
an existing context adds nothing here.

**2. Add the service to the chart's `services[]` and get the three regexes right the first time.**
That entry renders the `User`, the `Permission` and the two ExternalSecrets. Permission regexes are
immutable in place (section 7) — tightening one later means deleting the CRD and taking 403s in the
gap — so the shape matters more than usual:

- `configure` covers the service's own namespace `<service>-service\..*`, plus `acme.<bc>(\..*)?`
  if the service owns a context.
- `write` adds `acme.audit-feed(\..*)?` if the service publishes at all, because the relay
  dual-publishes — and, the clause people forget, the service's **own queue namespace**, because
  `queue.bind` checks write on the _destination queue_ (section 6.3).
- `read` covers every source exchange the service consumes from, plus its own queues.

**3. Provision the credential once and project it twice.** One Terraform-managed Key Vault secret
per service feeds two independent ExternalSecrets (section 10.1): one into the bundle namespace for
the pod's `RABBITMQ_PASSWORD`, one into the bootstrap namespace with an added literal
`username: <svc>_user` for `User.spec.importCredentialsSecret`. Both must resolve to the same value
or the AMQP `PLAIN` handshake returns 403 — latently, on the next fresh connection rather than at
deploy time (section 10.3).

**4. Allocate an advisory lock id** — but only if the service will run an outbox relay. The lock
space is shared across one table and ids are per service, so a duplicate id silently serialises two
unrelated relays behind one lock and starves whichever loses the race. The registry and its guards are in
[`./02-publishing.md`](./02-publishing.md) §4.

**5. Declare what the service itself owns, at `OnModuleInit`.** For each source context consumed: a
`<service>-service.<source-bc>` queue (Rule 5), and — unless the source context's DLX happens to
fall inside the service's own `configure` namespace — a `<service>-service.<source-bc>.dlx` /
`.dlq` pair (Rule 6). Use the shared helper rather than hand-rolling: it declares in the only order
that works (section 7) — passive `checkExchange` on the source, `assertExchange` on the DLX,
`assertQueue` then `bindQueue` on the DLQ, then the main queue with its dead-letter arguments, then
the routing-key binds, then `prefetch(1)` and `consume`.

**6. Never actively declare a foreign exchange.** Bounded-context isolation withholds `configure`
on it, so `assertExchange` returns `403 ACCESS_REFUSED` and the pod crash-loops (section 1). The
passive `checkExchange` is the only legal probe, and it succeeds only because step 1 already ran for
the owning context.

**7. Let the sync waves do the ordering.** Credentials land before `User`, `User` before
`Permission`, exchanges before the service Deployment (section 7). A pod that boots ahead of its
topology gets a 404 on `checkExchange` and enters `CrashLoopBackOff` — that is the designed
behaviour, not a bug to code around.

The two steps that account for most first-boot failures are 2 and 5: a `write` regex that omits the
service's own queue namespace, and a hand-rolled consumer that declares its queue before its DLX.
Both surface as a crash-looping pod with a single AMQP error line and no other symptom.

---

## Where this connects

- **Survey doc this sits under:** [`../../backend/05-messaging.md`](../../backend/05-messaging.md)
  — the messaging spine end to end: outbox, relay, versioning, consumer discipline, ADR map.
- **The rest of this folder** — the objects catalogued here, in motion:
  - [`./02-publishing.md`](./02-publishing.md) — the outbox row, the relay cycle, the advisory lock
    referenced in section 13, publisher confirms and the audit dual-publish.
  - [`./03-consuming.md`](./03-consuming.md) — what happens after `consume(main)`: handler
    contracts, inbox idempotency, reconnect behaviour.
  - [`./04-failure-atlas.md`](./04-failure-atlas.md) — every failure mode named in this document,
    with the diagnostic command and the recovery for each.
  - [`./05-testing-the-broker.md`](./05-testing-the-broker.md) — which of these claims a test
    actually holds, and which tier gates a merge.
- **Sibling deep-dives:**
  - [`../events/01-event-anatomy.md`](../events/01-event-anatomy.md) — the envelope schema and
    versioning rules behind the routing keys in section 5; and
    [`../events/02-event-families.md`](../events/02-event-families.md) — what each consumer
    catalogued here does with the payload.
  - [`../multi-tenancy/03-propagation.md`](../multi-tenancy/03-propagation.md) — how `tenantId`
    travels in the event envelope, and why the broker carries no per-tenant topology.
- **Platform context:**
  [`../../platform/event-catalog.md`](../../platform/event-catalog.md) — the event types that
  populate the routing keys in section 5;
  [`../../platform/integration-patterns.md`](../../platform/integration-patterns.md) — outbox,
  inbox and anti-corruption patterns around the bus;
  [`../../platform/bounded-contexts.md`](../../platform/bounded-contexts.md) — why the exchanges are
  split the way they are.
- **Adjacent backend concerns:**
  [`../../backend/03-data-architecture.md`](../../backend/03-data-architecture.md) — the
  `platform_outbox` schema, the advisory-lock registry and the outbox reaper;
  [`../../backend/04-authn-authz.md`](../../backend/04-authn-authz.md) — the identity headers whose
  events flow through `acme.identity` and `acme.platform`;
  [`../../backend/06-caching.md`](../../backend/06-caching.md) — the Redis boundary ADR-0017 drew
  when it removed BullMQ.
- **Deployment:** [`../../devops/01-gitops-topology.md`](../../devops/01-gitops-topology.md) — the
  sync waves, bundles and namespaces the CRDs in section 9 land in.
