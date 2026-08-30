---
name: platform-rmq-consumer-bc-isolation
description: "Platform RabbitMQ consumers must passively checkExchange FOREIGN source exchanges (never assertExchange), actively declare their OWN DLX, and rely on Exchange CRDs; ownership oracle is each service's configure regex in platform-rmq-bootstrap/values.yaml"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000035
---

Platform enforces bounded-context isolation on the shared `acme` vhost (ADR-0017). A consumer binds to a SOURCE exchange owned by the PUBLISHING bounded context and holds only `read` on it — NOT `configure`. The contract:

- **Foreign source exchange → passive `checkExchange(name)`.** amqplib sends `exchange.declare passive=true` (needs no `configure`; errors 404 if the exchange is absent). NEVER `assertExchange` a foreign exchange — an active declare needs `configure`, which BC-isolation denies → `403 ACCESS_REFUSED - configure access to exchange '<x>' refused`, a fatal crash-loop. amqplib has **NO `passive` option on `assertExchange`**; the dedicated method is `checkExchange` (verified: `node_modules/amqplib/lib/api_args.js:141` sets `passive: true`; `channel_model.js:130`).
- **Own resources (queue + DLX) → active declare.** The DLX MUST live in the consumer's own configure namespace (`<svc>-service.<bc>.dlx`, or an own `acme.<ownbc>.dlx`), be declared BEFORE the queue references it, and the queue pinned `x-queue-type: quorum` (the broker default; a quorum queue rejects an UNDECLARED DLX — #958). A FOREIGN DLX name (e.g. notification using `acme.commission.dlx`) is unconfigurable by that user → rename to an owned name.
- **BC exchanges exist independently** via `rabbitmq.com/v1beta1` Exchange CRDs in `charts/platform-rmq-bootstrap` (`templates/exchange.yaml` + `exchanges[]` in `values.yaml`): 9 `acme.<bc>` topic exchanges + the `acme.audit-feed` fanout. This makes passive `checkExchange` succeed regardless of which service started first (removes cross-service startup-ordering coupling; without it passive just turns a 403 into a 404 when the owner is down).

**Ownership oracle:** a service OWNS `acme.<x>` iff its `configure` regex in `charts/platform-rmq-bootstrap/values.yaml` contains it. Classify every `assertExchange` as foreign-vs-own BEFORE changing it — **not every inline assert is a bug**: e.g. `document-generation-worker` declaring `acme.communication` is legitimate (document IS the comms BC owner), but `commission`/`accounting`/`inventory` declaring `acme.trading` is foreign.

Shared helper: `libs/platform/event-bus/src/lib/setup-rabbit-consumer.ts` (used by audit + 4 reporting consumers). The 5 inline consumers (commission/accounting/inventory/document/notification) reimplement the wiring and needed the same fix. Shipped across PR #972 (shared helper), #973 (Exchange CRDs), #974 (inline consumers, closes #965); all Refs #970. Related: [[rmq-topology-operator-rotation-gotcha]].
