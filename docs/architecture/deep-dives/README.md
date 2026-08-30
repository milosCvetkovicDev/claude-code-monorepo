# Deep dives

The [architecture set](../README.md) describes the shape of the system. These fifteen documents
go under it, into three mechanisms that are hard to get right and harder to explain: the
event-driven backbone, the message broker underneath it, and multi-tenant isolation.

**15 documents · 91 diagrams · ~19,900 lines.** Every claim was checked against source, and
where the code and a decision record disagree the document says so rather than picking the
flattering version.

---

## Where to start

Each series has one document written to be read on its own, before the others:

1. [`events/03-the-life-of-one-event.md`](events/03-the-life-of-one-event.md) — one trade
   confirmation followed from a button press to the last downstream side effect, twelve hops,
   with what happens when each hop fails. Read this and you know the pipeline.
2. [`rabbitmq/04-failure-atlas.md`](rabbitmq/04-failure-atlas.md) — nine ways messaging breaks,
   each on an identical map sheet: the failure, the blast radius, the detection signal, the
   recovery, the prevention.
3. [`multi-tenancy/05-isolation-threat-model.md`](multi-tenancy/05-isolation-threat-model.md) —
   the same isolation machinery read from the attacker's side: nine attack paths, the control
   that stops each, and whether a test proves that control exists.

The other twelve are reference. Read them when you need them.

---

## Events

How the platform's services agree on what happened, without calling each other.

| Document                                                              | What it covers                                                                                                    | Diagrams |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | -------- |
| [`01-event-anatomy.md`](events/01-event-anatomy.md)                   | The envelope field by field — what writes each field, what reads it, what breaks without it                       | 4        |
| [`02-event-families.md`](events/02-event-families.md)                 | The counted index: every event, its owner, its exchange, its routing key, its consumers                           | 7        |
| [`03-the-life-of-one-event.md`](events/03-the-life-of-one-event.md)   | One event, twelve hops, end to end — with each hop's failure mode                                                 | 13       |
| [`04-event-evolution.md`](events/04-event-evolution.md)               | Changing an event's shape without breaking a running consumer; versioned routing keys and the dual-publish window | 4        |
| [`05-choreography-decisions.md`](events/05-choreography-decisions.md) | Why choreography over orchestration, where sagas appear, and the honest cost of eventual consistency              | 4        |

## RabbitMQ

The broker: what is declared, how messages get in and out, and what happens when it goes wrong.

| Document                                                        | What it covers                                                                                                      | Diagrams |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | -------- |
| [`01-topology.md`](rabbitmq/01-topology.md)                     | Every exchange, queue, binding and dead-letter chain — and who declares each, at what moment                        | 9        |
| [`02-publishing.md`](rabbitmq/02-publishing.md)                 | The outbox relay: caller-owned transactions, advisory locking, publisher confirms, the audit lane and its redaction | 5        |
| [`03-consuming.md`](rabbitmq/03-consuming.md)                   | Consumer lifecycle, the hardened reconnect helper and its adopter contract, ack strategy, the inbox pattern         | 5        |
| [`04-failure-atlas.md`](rabbitmq/04-failure-atlas.md)           | Nine failure modes as uniform map sheets, plus the dead-letter replay runbook                                       | 11       |
| [`05-testing-the-broker.md`](rabbitmq/05-testing-the-broker.md) | What can be proved before production — and what only a deployed environment can                                     | 3        |

## Multi-tenancy

One deployment, many tenants, and the machinery that keeps them from seeing each other.

| Document                                                                     | What it covers                                                                                               | Diagrams |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | -------- |
| [`01-tenant-model.md`](multi-tenancy/01-tenant-model.md)                     | What a tenant is as rows and columns: the aggregate, its lifecycle, its four identity handles                | 4        |
| [`02-resolution.md`](multi-tenancy/02-resolution.md)                         | How an anonymous request finds its tenant before authentication is possible                                  | 4        |
| [`03-propagation.md`](multi-tenancy/03-propagation.md)                       | Six carriers that must all agree: header, token claim, async context, event envelope, job payload, cache key | 4        |
| [`04-enforcement.md`](multi-tenancy/04-enforcement.md)                       | The fail-closed ORM filter, the forked-entity-manager problem, and every exemption argued individually       | 4        |
| [`05-isolation-threat-model.md`](multi-tenancy/05-isolation-threat-model.md) | Nine attack paths, the control that stops each, and the test that proves it                                  | 10       |

---

## How to read these

**They are written to be argued with.** Where a control is held up by convention and review
rather than by an executing test, that is stated. Where a decision record describes behaviour
the code does not have, the document says which one it believes and why. A reference that only
records the parts that went well is not much of a reference.

**Weaknesses are described as patterns, not as status.** These documents were exported from a
real private codebase. Specific unremediated defects, exact service counts and the internal
identifiers that would locate them have been generalised into the engineering lesson they
teach — "where authorisation is opt-in per controller, a deliberate omission and a forgotten
one look identical" carries the insight without being a map of anyone's live system. See
[`SANITIZATION.md`](../../../SANITIZATION.md).

**All identifiers are fictional.** Product, company, people, hosts, tenants and trading entities
are renamed consistently, so cross-references still resolve and the examples still read like
real work.
