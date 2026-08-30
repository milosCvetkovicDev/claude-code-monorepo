# The Failure Atlas

This document answers one question nine times: _when this specific thing breaks, what
mechanically happens, who notices, and what does an operator type?_ It is an atlas rather than a
list — every failure mode gets an identically-shaped map sheet (the failure, the blast radius, the
detection signal, the recovery procedure, the prevention that exists and the prevention that does
not), so you can jump straight to the sheet you need without reading the ones before it. Read it
on call, or before adding a consumer, a relay or an alert. It sits below
[`backend/05-messaging.md`](../../backend/05-messaging.md) and
[`platform/integration-patterns.md`](../../platform/integration-patterns.md), which describe the
shape of the messaging layer — this describes what happens when the shape breaks.

---

## Atlas index

Start from the symptom. Each terminal node is a map sheet in this document.

```mermaid
flowchart TD
  START["Something is wrong with messaging"] --> Q1{"Can services reach<br/>the broker at all?"}

  Q1 -- "No, all services" --> S1["Sheet 1<br/>Broker unavailable"]
  Q1 -- "No, one service only" --> S2["Sheet 2<br/>Credential drift"]
  Q1 -- "Yes" --> Q2{"Are messages arriving<br/>at the consumer?"}

  Q2 -- "No, and nothing ever did" --> S9["Sheet 9<br/>Binding nothing publishes"]
  Q2 -- "No, they stopped" --> Q3{"What is the outbox<br/>row's status?"}
  Q2 -- "Yes, but wrongly" --> Q5{"Wrong how?"}

  Q3 -- "Still PENDING" --> S1
  Q3 -- "Stuck in PUBLISHING" --> S8["Sheet 8<br/>Confirm never arrives"]
  Q3 -- "PUBLISHED but not delivered" --> S7["Sheet 7<br/>DLQ accumulation"]
  Q3 -- "Consumer channel died" --> S6["Sheet 6<br/>Consumer crash mid-batch"]

  Q5 -- "Applied twice" --> S3["Sheet 3<br/>Duplicate delivery"]
  Q5 -- "Applied in the wrong order" --> S4["Sheet 4<br/>Out-of-order delivery"]
  Q5 -- "One message kills the handler" --> S5["Sheet 5<br/>Poison message"]

  S5 --> REPLAY["DLQ replay runbook"]
  S7 --> REPLAY
  S6 --> REPLAY
```

The diagram encodes a real triage order, not a taxonomy. The first branch is deliberately
_scope_: a broker-wide outage and a single-service 403 look identical in one service's logs and
completely different across the fleet, so the cheapest first question is "does anyone else have
this?". The second branch is _where the message stopped_, which the transactional outbox makes
answerable with a single SQL query rather than by reading logs — the row's `status` column tells
you whether the failure is upstream of the broker (`PENDING`, `PUBLISHING`) or downstream of it
(`PUBLISHED` and yet nothing happened). Only once the message is known to have been delivered do
the semantic failures — duplicate, out-of-order, poison — become candidates. Three of the sheets
converge on the same recovery procedure, which is why the DLQ replay runbook is a section of its
own at the end.

---

## Ground truth these sheets assume

Every sheet below rests on the same eight facts. They are stated once here rather than repeated
nine times, and every one of them is a deliberate design choice with a failure consequence.

**One broker node.** The broker runs as a single-replica StatefulSet with a 20 GiB persistent
volume. Quorum queues are the broker default (`default_queue_type = quorum`) and every queue in
the codebase pins `x-queue-type: quorum` explicitly, but on one node a quorum queue is a
single-member quorum — durable, not highly available. The chart states the reason: the shared node
pool is capped at one 4-vCPU node by a regional vCPU quota, so a three-node cluster cannot
schedule.

**No PodDisruptionBudget on the broker.** The chart sets
`cluster-autoscaler.kubernetes.io/safe-to-evict: "false"`, and its own comment is honest about the
scope: that annotation blocks _cluster-autoscaler_ scale-down eviction only. `kubectl drain` and
surge upgrades ignore it. A PDB with `maxUnavailable: 0` on a single replica would deadlock every
drain, so none is set, and a 1–3 minute messaging outage during a reschedule (volume re-attach
plus Mnesia recovery) is an accepted cost.

**A memory watermark that blocks publishers.** `vm_memory_high_watermark.relative = 0.7` against a
1 GiB container limit means the broker begins blocking publishing connections at roughly 717 MiB.
`channel_max = 128` bounds channels per connection.

**Four relays, one table.** Twelve services use the event bus; four of them run the outbox relay
(`enableRelay: true`): auth-service, tenant-service, user-service and inventory-service. All
twelve share **one** PostgreSQL database with per-service schemas, and the outbox entity is pinned
to a single shared schema — `@Entity({ tableName: 'outbox_entry', schema: 'platform_outbox' })`.
The bootstrap job spells out the consequence: a `NOLOGIN` group role owns the schema and every
service role joins it, "so this service can create + read/write the shared `outbox_entry` table
regardless of which service migrates first … (cross-service DML — the relay/reaper read all
rows)". A relay's claim query filters on `status = PENDING` and nothing else.

**Thirteen consumer classes in four tiers.** Their reconnect behaviour differs materially and is
catalogued in [`03-consuming.md`](./03-consuming.md) §1. The distinction that matters most here:
five consumers (audit-service plus four reporting-service projection consumers) use the library
helper `setupRabbitConsumer`, which attaches **no** `channel.on('close')` handler at all.

**Every consumer runs `prefetch(1)`.** Without exception. That is the single most consequential
number in this document: it bounds unacked messages per consumer to one, which is why "crash
mid-batch" has a blast radius of one message rather than a hundred.

**Every nack is `nack(msg, false, false)`.** No consumer ever requeues. A failed message
dead-letters immediately; it is never retried in place. There is no TTL-based retry loop anywhere
in the code, despite the messaging decision record describing one.

**Probes are asymmetric on purpose.** `GET /health/live` returns 200 unconditionally.
`GET /health/ready` runs every registered dependency check and returns 503 if any is not `ok`. The
broker check is `conn.isConnected() ? 'ok' : 'disconnected'` — connection state only, nothing
about channels or consumers. Readiness runs every 5 s with `failureThreshold: 3`, so a
disconnected pod leaves the Service endpoints in roughly 15 seconds and is never restarted for it.

---

## Sheet 1 — Broker unavailable

### The failure

Three distinct events produce the same broker-side symptom and three different application-side
behaviours: a broker pod restart, a node drain, and a network partition.

On the broker side the outcome is uniform. The single replica goes away, its AMQP listener stops
accepting, and every existing TCP connection is closed or hangs. Quorum queues survive because
their log is on the persistent volume, but with one member there is no failover — the queues are
simply unavailable until the pod is rescheduled and Mnesia recovers.

On the application side, three layers react independently.

The **connection layer** (`RabbitMqConnection`) attaches `close` and `error` listeners to the
amqplib connection after a successful connect. On `close` it sets `connected = false`, nulls the
cached channel, and schedules a reconnect after `reconnectDelayMs` (default 5000 ms). The
reconnect calls `connect()`, which itself retries up to `maxRetries` (default 5) with exponential
backoff `backoffMs * 2^(attempt-1)` — 2 s, 4 s, 8 s, 16 s between the five attempts — and on
exhaustion re-arms `scheduleReconnect()`. That outer loop is unbounded, which is correct: a broker
that is down for an hour is recovered from automatically.

The **channel layer** does not follow. Channels die with their connection. Whether a consumer
comes back depends entirely on which tier it belongs to, and the two reconnect implementations do
not even agree on their backoff constants:

| Tier                                                                                 | Mechanism                                                              | Backoff on channel close     | Attempt ceiling | Worst-case retry span   |
| ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- | ---------------------------- | --------------- | ----------------------- |
| A — library `setupRabbitConsumerWithReconnect` (user-service)                        | `computeBackoffMs(attempt, { baseMs: 10, capMs: 30000, jitterMs: 5 })` | 10 ms doubling to a 30 s cap | 100             | ≈ 50 minutes            |
| B — hand-rolled (inventory, notification, accounting, commission, document, trading) | `computeBackoffMs(attempt)` with library defaults                      | 5 s doubling to a 5 min cap  | 100             | ≈ 8 hours               |
| C — library `setupRabbitConsumer` (audit, reporting ×4)                              | none — no `close` listener exists                                      | n/a                          | n/a             | never recovers          |
| D — raw `setTimeout(setup, 5000)` (document generation worker)                       | fixed 5 s, no jitter                                                   | one attempt per close        | none            | one retry, then silence |

Tier D deserves a footnote because its row understates the problem. Its `close` handler schedules
exactly one `setupConsumer()` five seconds later and `.catch`es a failure by logging it. A
successful retry re-attaches a `close` listener and the cycle can repeat, but a _failed_ retry
re-arms nothing — so a broker that is still down five seconds after the channel closed leaves that
worker permanently stopped, with `Worker reconnect failed: …` as the only trace. Its
`onModuleDestroy` logs a line and closes nothing.

The **relay layer** degrades cleanly. Its injected publish adapter calls
`rabbitMqConnection.publish(...)` per message, and that method reads `this.channel` fresh each
time, so once the connection layer reconnects and creates a new confirm channel the relay picks it
up with no coordination. While the broker is down, `publish` throws `No channel available — call
connect() first`, Phase 2 catches per entry, Phase 3 increments `retry_count` and returns the row
to `PENDING`. After `maxRetries` (default 5) the row goes to `FAILED` — which, for a broker outage
longer than five poll cycles, means the outbox drains itself into a permanently failed state. That
is worth internalising: **a five-second broker blip is invisible, a six-second one is not**,
because the relay polls every 1000 ms and burns the whole retry budget in five seconds.

There is one more variant, and it is the nastiest. If the broker is unavailable at **pod start**,
`onModuleInit` calls `connect()`, the five attempts fail, and the `catch` deliberately swallows the
error so the pod stays up and the readiness probe can report `disconnected`. But the `close`
listener that drives `scheduleReconnect()` is only attached _after_ a successful connect — so
nothing ever retries. Services that also run an AMQP consumer recover by accident: their
consumer's `onModuleInit` rethrows, Nest bootstrap fails, and Kubernetes crash-loops the pod until
the broker returns. Services with **no** consumer — auth-service and tenant-service, both of which
run relays — have no such escape. They stay up, permanently disconnected, readiness 503 forever,
relay never started, until a human deletes the pod.

```mermaid
sequenceDiagram
  autonumber
  participant K as Kubernetes
  participant B as Broker pod
  participant C as RabbitMqConnection
  participant R as OutboxRelay
  participant TB as Tier B consumer
  participant TC as Tier C consumer

  K->>B: drain / restart
  B--)C: connection close
  B--)TB: channel close
  B--)TC: channel close
  C->>C: connected = false, channel = null
  C->>C: scheduleReconnect after 5s
  TB->>TB: scheduleReconnect, backoff from 5s
  Note over TC: no close listener — nothing happens, ever
  R->>C: publish next PENDING entry
  C-->>R: throw "No channel available"
  R->>R: retry_count++, status back to PENDING
  Note over R: after 5 failures the row becomes FAILED
  B->>B: rescheduled, volume re-attached, Mnesia recovered
  C->>B: connect attempt 1/5 succeeds
  C->>C: createConfirmChannel, readyPromise already resolved
  TB->>B: re-assert exchange, queue, bindings, consume
  R->>C: publish succeeds again
  Note over TC: still silent — pod restart is the only cure
```

The diagram makes the asymmetry visible: the connection heals itself, the relay heals with it for
free, Tier B heals on its own timer, and Tier C never heals. The gap between step 5 and the last
note is the entire operational risk of this failure mode.

### Blast radius

**Degraded.** All event publication (rows accumulate as `PENDING`, then `FAILED` after five poll
cycles). All event consumption. All background job enqueue paths that publish to work queues.
Readiness for every service that imports the event bus — which is every service except the gateway
— so with one replica per service in the dev environment, the gateway stops routing to all of them.

**Still working.** Synchronous HTTP request handling inside the process (the database and cache
are untouched), every business write (the outbox row is written in the same transaction and simply
waits), and liveness — which is exactly why Kubernetes will not restart the pod out of the failure.

**What a user sees.** During the outage, if the gateway has any healthy replica, requests succeed
and state changes commit; the _effects_ that depend on events do not happen. An invoice is
approved but the document is not generated. A user is invited but no email is sent. A deal is
locked but commission is not calculated. After recovery, everything still in `PENDING` flushes
within one poll cycle and the effects arrive late, in a burst. Everything that reached `FAILED`
never arrives at all and requires manual intervention. With one replica per service the more
likely user-visible outcome is a 503 from the gateway, because readiness pulled the only pod out
of the endpoint list.

### Detection

| Signal                                                                   | Where                            | Latency          | Live?                                                          |
| ------------------------------------------------------------------------ | -------------------------------- | ---------------- | -------------------------------------------------------------- |
| `RabbitMQ connection closed, scheduling reconnect` (WARN)                | service logs                     | immediate        | yes                                                            |
| `RabbitMQ connection attempt n/5 failed, retrying in Xms` (WARN)         | service logs                     | 5 s after close  | yes                                                            |
| `RabbitMQ connected (attempt 1/5)`                                       | service logs                     | on recovery      | yes                                                            |
| readiness 503 with `checks.rabbitmq = "disconnected"`                    | `GET /health/ready`              | ≈ 15 s (3 × 5 s) | yes                                                            |
| `probe_success{probe_class="service-health"}` → the container-down alert | blackbox scraper → metrics store | 30 s             | yes — external to the pod's own signals                        |
| `acme_trading_outbox_lag_seconds` climbing                               | 15 s observer interval           | 15–30 s          | metric emitted; alerting depends on the rule's evaluation path |
| `up{job="rabbitmq"}`                                                     | broker dashboard                 | 30 s scrape      | yes                                                            |

Two detection gaps deserve naming. First, the readiness check flips back to `ok` the instant the
connection is re-established — while a Tier C consumer that never re-subscribed stays permanently
dead. Nothing anywhere reports "this pod holds a connection but consumes nothing". Second, an
outbox-lag rule can be authored, reviewed and merged and still never be evaluated: a rules
directory that no deploy generator references is a rule that exists in version control and nowhere
else, and an operator-format rule additionally needs an operator in the cluster to reconcile it
into something that runs. Assert the wiring, not the file.

### Recovery

1. Establish scope — one service or all of them:
   ```bash
   kubectl get pods -n rabbitmq
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- rabbitmqctl status | head -20
   ```
   If the broker pod is `Running` and `rabbitmqctl status` answers, this is Sheet 2, not Sheet 1.
2. If the pod is `Pending`, the node it wants is gone or full. Check events:
   ```bash
   kubectl -n rabbitmq describe pod rabbitmq-0 | tail -30
   ```
   A volume that is still attached to the old node is the common cause and resolves on its own
   once the detach completes.
3. Once the broker answers, confirm each service re-established its connection:
   ```bash
   kubectl logs -n platform-<bundle> -l app.kubernetes.io/name=<svc>-service --tail=50 \
     | grep -E 'RabbitMQ (connected|connection)'
   ```
4. **Restart the Tier C consumers unconditionally.** They will not have recovered. Audit-service
   and reporting-service:
   ```bash
   kubectl delete pod -n platform-ops -l app.kubernetes.io/name=audit-service
   kubectl delete pod -n platform-ops -l app.kubernetes.io/name=reporting-service
   ```
5. **Restart any relay-only service that was started while the broker was down.** auth-service and
   tenant-service have no consumer and therefore no crash-loop escape:
   ```bash
   kubectl delete pod -n platform-identity -l app.kubernetes.io/name=auth-service
   kubectl delete pod -n platform-identity -l app.kubernetes.io/name=tenant-service
   ```
6. Sweep the outbox for rows the retry budget consumed during the outage:
   ```sql
   SELECT event_type, count(*), min(created_at), max(created_at)
     FROM platform_outbox.outbox_entry
    WHERE status = 'FAILED'
      AND created_at > now() - interval '2 hours'
    GROUP BY event_type
    ORDER BY 2 DESC;
   ```
7. Re-arm the failed rows only after confirming the events are safe to re-publish (see Sheet 3 for
   why that is not automatic):
   ```sql
   UPDATE platform_outbox.outbox_entry
      SET status = 'PENDING', retry_count = 0, last_error = NULL
    WHERE status = 'FAILED'
      AND created_at > now() - interval '2 hours';
   ```

### Prevention

**What exists.** Unbounded connection-level reconnect with exponential backoff. Bounded,
jittered channel-level reconnect for tiers A and B — the jitter (`computeBackoffMs` adds
`floor(random() * jitterMs)`) exists specifically to stop replicas synchronising into a retry storm
after a broker restart. Deterministic channel teardown before every reconnect, so a reconnect never
leaks the previous channel or its listeners. Re-entrancy guards (`reconnectScheduled`) that collapse
amqplib's `error`-then-`close` double-emit into one reconnect chain rather than two overlapping
ones with a leaked channel and a doubled consumer. Business writes never depend on the broker
because the outbox is written in the same database transaction.

**What does not exist.** A second broker node, and therefore any tolerance of a node drain. A
PodDisruptionBudget (correctly, given one replica). Reconnect for the five Tier C consumers.
Any reconnect at all after a failed _initial_ connect, which strands relay-only services. A
retry budget proportional to the outage — five retries at a one-second poll interval is five
seconds of tolerance before permanent failure, which is far shorter than the 1–3 minute reschedule
window the chart itself documents as expected. A health check that reflects consumer liveness
rather than connection liveness.

---

## Sheet 2 — Credential drift

### The failure

Each service authenticates to the broker as its own principal (`<service>_user` on the `acme`
vhost) with a per-service password. That one password is stored in **two** secrets, and the split
is the whole failure mode.

| Secret                             | Contents                                                                          | Consumer of the secret              | Path                                                                                                       |
| ---------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `platform-<svc>-rabbitmq-uri`      | full `amqp://<svc>_user:<PASSWORD>@rabbitmq.rabbitmq.svc.cluster.local:5672/acme` | the **application pod**             | key vault → external-secrets → `<svc>-secrets` → env `RABBITMQ_URI`                                        |
| `platform-<svc>-rabbitmq-password` | the raw password                                                                  | the **messaging topology operator** | key vault → external-secrets → `platform-rmq-service-<svc>` → `User` CR `importCredentialsSecret` → broker |

Two stores exist because two different systems need the credential in two different shapes at two
different layers. The pod needs a connection URI; it never sees a bare password. The topology
operator needs a bare password because it PUTs the user into the broker through the management
API, and it reads that password from a Kubernetes Secret referenced by the `User` custom resource.
Both secrets are generated from a single `random_password` resource in Terraform, so _by
construction_ they agree.

They stop agreeing when the generating resource leaves Terraform state. Both secret resources
carry `lifecycle { ignore_changes = [value] }`, which means Terraform writes their values **only
at creation** and never reconciles them again. Once the `random_password` is gone from state — a
stray `terraform state rm` did it in the recorded incident — a subsequent apply recreates one
secret and not the other, or recreates both from a new random value while one is protected by
`ignore_changes`. The two live values diverge.

Nothing breaks immediately. Running pods hold established AMQP connections and never re-present
credentials. The drift is **latent** — for days, in the recorded case. The next restart, redeploy
or node move forces a fresh PLAIN handshake, which the broker refuses:

```text
Handshake terminated by server: 403 (ACCESS-REFUSED) with message
"ACCESS_REFUSED - Login was refused using authentication mechanism PLAIN."
```

Rollback does not help — this is the counter-intuitive part that costs the most time during an
incident. An older image reconnects just as freshly and fails identically. The deploy did not
cause the failure; it _revealed_ it.

```mermaid
sequenceDiagram
  autonumber
  participant TF as Terraform
  participant KV as Key vault
  participant ESO as External-secrets
  participant OP as Topology operator
  participant BR as Broker
  participant POD as Service pod

  Note over TF: one random_password feeds both secrets
  TF->>KV: write uri secret with password P1
  TF->>KV: write password secret with P1
  ESO->>POD: project uri secret, pod connects with P1
  ESO->>OP: project password secret
  OP->>BR: set user password to P1
  Note over POD,BR: steady state — both stores agree

  Note over TF: random_password removed from state
  TF->>KV: recreate password secret with P2
  Note over KV: uri secret still holds P1 — ignore_changes blocks reconciliation
  ESO->>OP: project P2
  OP->>BR: set user password to P2
  Note over POD: existing connection still open — no symptom yet

  POD->>POD: pod restarts for an unrelated reason
  POD->>BR: PLAIN handshake with P1
  BR-->>POD: 403 ACCESS-REFUSED
  POD->>POD: CrashLoopBackOff
```

The diagram's value is the gap between the drift and the symptom. Every step before the restart is
silent, and by the time the 403 appears the change that caused it is days old and unrelated to
whatever deploy is currently in flight.

### Blast radius

**Degraded.** Exactly one service, and completely. A service with a consumer rethrows from
`onModuleInit`, Nest bootstrap fails, and the pod enters `CrashLoopBackOff` — so it loses its HTTP
surface too, not only its messaging. A relay-only service (auth, tenant) stays up but never
publishes; its outbox accumulates `PENDING` rows, then `FAILED` ones.

**Still working.** Every other service, including every other service's messaging. The broker
itself. The affected service's database state. Because per-service credentials are the mechanism
of bounded-context isolation, credential drift is also _contained_ by it: one principal's password
being wrong cannot affect another's.

**What a user sees.** If the drifted service is on a request path, immediate 503s from the gateway
once readiness drops. If it is a background consumer — the recorded incident hit commission,
document and notification — the user sees nothing at all. Commissions are not calculated,
documents are not generated, emails are not sent, and the only symptom is absence.

### Detection

The 403 line in the pod log is the primary signal and it is unambiguous. Three secondary signals
matter, two of which are traps:

- **`User` CR `Ready=True` is a lie.** `kubectl get user.rabbitmq.com <svc> -n platform-identity`
  reports the status of the last _create_, not of an ongoing broker↔secret sync. It stays green
  through the entire incident.
- **External-secret `Ready=True` is also not enough.** Both external secrets can be perfectly
  synced from the key vault and the pod still 403s, because the two key vault _values_ genuinely
  differ. Force-syncing them proves the secret plumbing is fine and eliminates it as a cause —
  which is a useful diagnostic step precisely because it does not fix anything.
- **`terraform plan` is the confirming signal.** The drifted service's credential resources appear
  as "to add" — present in the live key vault, absent from state.

The definitive test, non-destructively:

```bash
pw=$(kubectl get secret -n platform-identity platform-rmq-service-<svc> \
     -o jsonpath='{.data.password}' | base64 -d)
kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
  rabbitmqctl authenticate_user <svc>_user "$pw"   # failure here = the two stores disagree
```

Note the username: the broker principal is `<svc>_user`, **not** the `User` CR name `<svc>`. Using
the CR name here produces a confusing "user does not exist" instead of an authentication failure.

Time to detect: zero from the moment of a restart, and unbounded before one. The drift can sit
undetected for as long as the pods stay up.

### Recovery

The key vault has purge protection enabled, so a soft-deleted secret name cannot be purged or
recreated for the retention window. **Never delete and recreate.** Rotate in place —
`az keyvault secret set` is an upsert that adds a new version.

1. Generate one password per affected service and write **both** secrets from it. Values must
   never be echoed:
   ```bash
   for svc in commission document notification; do
     pw="$(openssl rand -hex 16)"
     az keyvault secret set --vault-name <KEY_VAULT_NAME> \
       --name "platform-${svc}-rabbitmq-password" --value "$pw" --output none
     az keyvault secret set --vault-name <KEY_VAULT_NAME> \
       --name "platform-${svc}-rabbitmq-uri" \
       --value "amqp://${svc}_user:${pw}@rabbitmq.rabbitmq.svc.cluster.local:5672/acme" --output none
   done
   ```
2. Force-sync **both** external secrets — the pod-side one and the operator-side one. Confirm by
   watching the Kubernetes Secret `resourceVersion` increment. There is no need to decode values.
   ```bash
   kubectl annotate externalsecret <svc>-secrets -n platform-<bundle> \
     force-sync="$(date +%s)" --overwrite
   kubectl annotate externalsecret platform-rmq-service-<svc> -n platform-identity \
     force-sync="$(date +%s)" --overwrite
   ```
3. Force the broker-side push. **This is the step everyone forgets.** The topology operator
   watches `User` resources, not the Secrets they reference, so a Secret content change never
   triggers a reconcile and the broker keeps the old password indefinitely:
   ```bash
   kubectl delete user.rabbitmq.com <svc> -n platform-identity
   kubectl patch application platform-identity -n argocd --type merge \
     -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
   ```
   If the GitOps application is itself unhealthy — so self-heal cannot be trusted to recreate the
   deleted user — or the operator pod cannot be restarted, push the password directly instead. It
   is convergent with declarative intent, because it sets the broker to exactly the value the
   operator's own source Secret holds:
   ```bash
   pw=$(kubectl get secret -n platform-identity platform-rmq-service-<svc> \
        -o jsonpath='{.data.password}' | base64 -d)
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
     rabbitmqctl change_password <svc>_user "$pw"
   ```
4. Restart the pod. Environment is injected at pod creation, and the secret-reloader controller
   does not cover a broker-side re-sync:
   ```bash
   kubectl delete pod -n platform-<bundle> -l app.kubernetes.io/name=<svc>-service
   ```
5. Verify: the pod logs `RabbitMQ connected (attempt 1/5)` followed by
   `Nest application successfully started`, and the service's `*.dlq` queues form and bind to their
   `*.dlx` with routing key `dead-letter`.

### Prevention

**What exists.** A single generating resource in Terraform, so the two secrets agree by
construction when state is intact. A written runbook with the purge-safe procedure. The direct
`rabbitmqctl change_password` fallback for when the operator path is blocked. An upstream issue
filed against the topology operator proposing the missing `Watches(&corev1.Secret{}, ...)`
cross-resource watch — the standard controller-runtime pattern — with an explicit decision _not_
to build an in-repo controller for it, on the grounds that it would be the first Go service in a
TypeScript monorepo to mitigate a gap upstream is better placed to fix.

**What does not exist.** Any detector for the drift itself. Nothing compares the password embedded
in the URI secret against the raw password secret, and nothing compares either against the broker.
`lifecycle { ignore_changes = [value] }` actively suppresses the one signal Terraform would
otherwise give. The two-secret split is the root design smell and is still in place — a single
secret with the password as the only stored field, with the URI composed at pod start, would make
divergence impossible. And the operator's `Ready=True` remains actively misleading with no
in-repo compensating check.

---

## Sheet 3 — Duplicate delivery

### The failure

At-least-once is not an accident here; it is the chosen semantic, and it is produced at three
separate points.

**Point one — the relay's retry boundary.** The relay's poll cycle is deliberately split into
three phases so that a publish is never inside a transaction that can roll back around it: Phase 1
claims `PENDING` rows and flips them to `PUBLISHING` inside the advisory-lock transaction; Phase 2
publishes outside any transaction; Phase 3 writes the outcome in its own short transaction. That
shape eliminates the original duplicate-delivery bug (a cycle-wrapping transaction that could roll
back N successful publishes back to `PENDING` and re-deliver them next cycle), but the residual
window is unavoidable: if the publish succeeded and the Phase 3 write fails, the row stays
`PUBLISHING` forever rather than being re-published. The system chooses a stuck row over a
duplicate — and Sheet 8 covers the consequences.

**Point two — dual-publish during a version transition.** `publishToBoth` submits the canonical
and legacy routing keys to the confirm window together via `Promise.allSettled`, then fails the
whole entry if either rejects. The code comment is explicit that this is a deliberate trade:

> With allSettled, if any publish is rejected we surface a combined error … Phase 3 retries it. The
> canonical-duplicate risk on retry is accepted during the transition window because consumers
> MUST be event-id idempotent.

There is a tracked follow-up to add a per-entry publish checkpoint column so a retry can skip
already-confirmed keys, which would close this. It has not been implemented.

**Point three — the shared outbox with four lock domains.** This one is a structural hazard rather
than a design trade. All four relays poll the _same_ `platform_outbox.outbox_entry` table in the
_same_ database, and mutual exclusion between them is a PostgreSQL advisory lock whose key comes
from the `OUTBOX_ADVISORY_LOCK_ID` environment variable. Tracing where that value comes from:

| Service           | Relay | Lock id actually injected | Source                                         |
| ----------------- | ----- | ------------------------- | ---------------------------------------------- |
| auth-service      | yes   | `900001`                  | identity bundle values → the chart's env block |
| tenant-service    | yes   | `900002`                  | identity bundle values                         |
| user-service      | yes   | `900003`                  | identity bundle values                         |
| inventory-service | yes   | `900006`                  | trading bundle values, explicit env entry      |

There is a second source of the same setting: a per-service values file assigns a distinct
`outboxAdvisoryLockId` to all twelve services (auth 900001, tenant 900002, user 900003 …). Those
files are only referenced by the two _standalone_ GitOps applications (the gateway and the AI
service); the eleven bundled services are deployed from bundle values plus environment overlays,
so wherever a bundle sets the id, the bundle is what reaches the pod — and six of the bundle-level
values disagree with the per-service allocation anyway (accounting 900010 vs 900007, commission
900012 vs 900008, audit 900022 vs 900011, reporting 900023 vs 900012, notification 900050 vs
900010, document 900040 vs 900009). Two files reconciled independently, only one of which is read,
is a configuration shape that guarantees drift.

The consequence: all four relays hold four distinct keys in one lock space and therefore never
contend. Single-flight is enforced per service, not per table — which is precisely the wrong
granularity when the table is shared. Four relays, one table, no `FOR UPDATE SKIP LOCKED`, and a
claim that flushes `UPDATE … WHERE id = ?` with no status predicate. Any two of them can read the
same `PENDING` batch, both flip it to `PUBLISHING`, and both publish it.

```mermaid
sequenceDiagram
  autonumber
  participant RA as Relay in auth pod, lock 900001
  participant RI as Relay in inventory pod, lock 900006
  participant DB as Shared outbox table
  participant BR as Broker

  RA->>DB: pg_try_advisory_xact_lock 900001 → true
  RI->>DB: pg_try_advisory_xact_lock 900006 → true
  RA->>DB: SELECT WHERE status = PENDING ORDER BY created_at LIMIT 100
  RI->>DB: SELECT WHERE status = PENDING ORDER BY created_at LIMIT 100
  Note over RA,RI: both hold the same 100 rows
  RA->>DB: UPDATE status = PUBLISHING, COMMIT
  RI->>DB: UPDATE status = PUBLISHING — blocks, then commits over it
  RA->>BR: publish entry X
  RI->>BR: publish entry X again
  BR->>BR: entry X delivered twice
```

There is a second-order problem in the same diagram. A relay derives the target exchange from the
event type — `trading.deal.locked` becomes `acme.trading` — but publishes with _its own_ principal.
`tenant_user`'s write grant is `^(acme\.platform(\..*)?|acme\.audit-feed(\..*)?)$`, so an identity
relay that claims a trading-service row cannot publish it: the broker answers
`403 ACCESS_REFUSED - write access to exchange 'acme.trading' refused`, which closes the _channel_.
The connection layer has no channel-level close handler — only a connection-level one — so once
that channel is closed, every subsequent `publish` throws `IllegalOperationError: Channel closed`
until the pod restarts. The module's own comment asserts the invariant that makes this safe:

> INVARIANT: this static `<exchangeName>.dlx` equals dlxRoute()'s runtime target … because a
> relay-enabled service only ever emits its own bounded context's events (one-BC-per-outbox).

That invariant does not hold on a shared outbox table. **Unverified:** whether it currently
manifests in the running environment depends on whether a non-relay service's rows are ever
claimed by a relay whose principal lacks the write grant, which requires live broker and database
inspection this document could not perform. The code path is verified; the live incidence is not.
A related code comment claiming that a peer service's relay "polls a DIFFERENT database" is
contradicted by the infrastructure module itself, whose own variable documentation describes one
shared database with per-service schema isolation.

**What defends against duplicates at the consumer.** Two mechanisms, unevenly applied:

- **The inbox** (`processed_event`, primary key `(consumer, event_id)`), present in
  inventory-service and trading-service only. The two implementations order the write
  _differently_, for a good reason. Trading records the inbox row **before** applying, inside one
  transaction, so the dedup and the state change commit or roll back together. Inventory records
  it **after** applying, because its stock repositories persist through per-operation forked
  entity managers — each `save()` is its own transaction — so no single caller transaction can
  span both the inbox insert and every stock write. Its wrapper documents the reasoning: recording
  after success "keeps the inbox a truthful 'already-applied' ledger: a crash between `apply()`
  and the inbox insert simply re-runs `apply()` on redelivery, which is safe because every handler
  is independently idempotent". Recording _before_ apply without a shared transaction would be the
  classic anti-pattern — mark processed, then lose the state change.
- **Per-effect unique constraints**, which are the real backstop: a unique index on
  `stock_movement.event_id`, and a uniqueness rule on `(sourceEventId, templateCode, recipientId)`
  for notification deliveries.

Everything else — accounting, commission, document, reporting, audit — has neither an inbox nor a
documented per-effect key, and relies on handlers being naturally idempotent.

### Blast radius

**Degraded.** Any handler without an inbox row or a per-effect unique key. The financial ones are
the ones that matter: a duplicated `trading.deal.locked` recalculates commission, a duplicated
`accounting.invoice.processed` appends a second `deal_activity` projection row.

**Still working.** Everything protected by a unique index fails the second insert and treats it as
a benign duplicate. The inbox repository catches `UniqueConstraintViolationException` on flush and
returns `false` rather than re-throwing, so a cross-process race is absorbed silently. It also
holds a synchronous in-process reservation set that closes the window between two concurrent
`recordOnce` calls _before_ the first `await`, which the database constraint alone cannot cover.

**What a user sees.** Doubled figures, duplicate audit trail entries, or two identical emails.
Because the audit lane fans out every event to a separate exchange, a duplicate is also duplicated
into the audit store, so the audit trail confirms rather than contradicts the doubled effect.

### Detection

- `acme_inventory_consumer_redeliveries_total{consumer,event_type}` and
  `acme_trading_consumer_redeliveries_total{consumer,event_type}` — incremented on a _deduplicated_
  redelivery. A rising counter is the system working, not failing; a rising counter alongside a
  doubled figure means the dedup was bypassed.
- A redelivery-rate rule exists in operator format, firing above 0.1/s sustained for 10 minutes —
  with the same evaluation-path caveat as Sheet 1.
- Duplicates in a handler with _no_ dedup produce **no signal whatsoever**. The only detection is
  the business number being wrong.
- To check the lock-domain hazard directly:
  ```bash
  kubectl exec -n platform-<bundle> deploy/<svc>-service -- \
    printenv OUTBOX_ADVISORY_LOCK_ID   # expect the service's allocated id; empty means the
                                       # code default, which is itself a misconfiguration
  ```
  ```sql
  SELECT objid, count(*) FROM pg_locks
   WHERE locktype = 'advisory' GROUP BY objid;
  ```
  More than one distinct advisory `objid` in the 900000 range at the same moment means more than
  one relay is claiming concurrently.

### Recovery

Duplicate delivery is not recoverable at the messaging layer — the second copy has already been
applied. Recovery is a data fix plus a structural fix.

1. Identify the duplicated effect from its natural key. For stock, `stock_movement.event_id`; for
   deal activity, `(deal_id, entity_id, activity_type)`; for notifications,
   `(source_event_id, template_code, recipient_id)`.
2. Reverse the duplicate with a domain operation, never a raw `DELETE`, so the reversal is itself
   audited.
3. Backfill the missing dedup guard — an inbox row for the affected `(consumer, event_id)` prevents
   a third application if the message is still in flight somewhere:
   ```sql
   INSERT INTO <schema>.processed_event (consumer, event_id, processed_at)
   VALUES ('<consumer-name>', '<event-id>', now())
   ON CONFLICT DO NOTHING;
   ```
4. Fix the lock-domain divergence by setting `OUTBOX_ADVISORY_LOCK_ID` to one shared value across
   every relay-enabled service for as long as the outbox table is shared. Per-service ids only
   become correct once each service owns its own outbox table; until that separation exists, a
   distinct id per relay is a lock that guards nothing.

### Prevention

**What exists.** The three-phase relay that made the original duplicate class impossible. The
inbox convention with two correctly-reasoned write orderings. Per-effect unique indexes on the
highest-value effects. An adapter that treats a unique-violation as a duplicate rather than an
error. A synchronous in-process reservation closing the pre-`await` race. An explicit, documented
acceptance that dual-publish retries can duplicate, paired with the requirement that consumers be
event-id idempotent.

**What does not exist.** The publish-checkpoint column that would make dual-publish retries
idempotent. `FOR UPDATE SKIP LOCKED` on the claim, which would make the advisory lock an
optimisation rather than a correctness requirement. A status predicate on the claim's `UPDATE`,
which would let a losing relay detect that it lost. An inbox in ten of the twelve services. And
any test or startup assertion that all relay-enabled services agree on a lock id while they share
a table.

---

## Sheet 4 — Out-of-order delivery

### The failure

Within one queue consumed by one consumer with `prefetch(1)`, RabbitMQ delivers in publication
order and the handler processes serially. That is the ordering guarantee the system actually has,
and four things break it.

**More than one consumer on the queue.** The base chart defaults to `replicaCount: 2` with
autoscaling from 2 to 10; the dev overlay pins every service to 1. So the dev environment has
per-queue ordering and any environment on chart defaults does not. Two replicas of the same
consumer each hold one unacked message and finish in whatever order their handlers finish.

**Redelivery after a channel death.** This is the case that surprises people, because it happens
even with a single replica. A message delivered but not yet acked when the channel dies is
returned to the queue and re-delivered later — by which time messages published _after_ it may
already have been processed. The message re-enters the stream out of position.

**Two concurrent relays.** From Sheet 3: the claim is ordered `created_at ASC`, but interleaving
between two relays on different advisory locks has no ordering at all.

**Dual-publish concurrency.** During a transition window `publishToBoth` submits the canonical and
legacy keys through `Promise.allSettled`, so both are in the confirm window simultaneously. Two
consumers bound to the two keys can observe the same logical event at different times.

The one case _not_ present is the classic reordering culprit: nack-with-requeue. Every nack in the
codebase is `nack(msg, false, false)`. A rejected message does not go back to the head of the
queue and jump ahead of its successors — it leaves the ordered stream entirely, for the
dead-letter exchange. That converts a reordering hazard into a _loss_ hazard (Sheet 5) and a
much-delayed reordering hazard: a DLQ message replayed hours later is an old event re-entering a
stream that has moved on. The replay runbook's step ordering is designed around exactly that.

```mermaid
sequenceDiagram
  autonumber
  participant Q as Queue
  participant C as Consumer with prefetch 1
  participant DB as Read model

  Q->>C: deliver E1 at t=10
  C->>DB: apply E1, lastEventAt = t10
  Q->>C: deliver E2 at t=20
  Note over C: channel dies before ack
  Q->>Q: E2 unacked — returned to the queue
  Q->>C: deliver E3 at t=30 to the reconnected consumer
  C->>DB: apply E3, lastEventAt = t30
  Q->>C: redeliver E2 at t=20
  C->>DB: updateFrom compares eventAt t20 to lastEventAt t30
  DB-->>C: false — stale event skipped
  C->>Q: ack E2
```

The last three steps are the defence, and it is worth being precise about it. The read-model
projections do not assume ordering; they enforce last-write-wins on the _event's own_ timestamp:

```ts
updateFrom(data: Partial<{...}>, eventAt: Date): boolean {
  if (eventAt <= this._lastEventAt) return false;
  // ... apply fields ...
  this._lastEventAt = eventAt;
  return true;
}
```

The caller logs `Skipping stale event … event older than lastEventAt` and returns without
flushing. Note the input: `event.timestamp`, set by the producing pod's wall clock at publish
time. Clock skew between producer pods is therefore a correctness input to ordering, not merely a
reporting nuisance. Nothing in the pipeline uses the broker's arrival order or a monotonic
sequence.

The other defence is state guards rather than ordering. The invoice write-back handler transitions
only `FINALISED → INVOICED` through the entity's guarded method — `INVOICED` is set nowhere else —
and anything arriving against a non-`FINALISED` source is parked with reason `INVALID_STATE`
rather than applied or dropped. An out-of-order arrival therefore becomes a queryable SQL row with
a reason, which is the desired outcome.

### Blast radius

**Degraded.** Any handler that is order-dependent and has no timestamp guard and no state guard.
The stock handlers are the sharpest example: a `reserved` applied after its matching `released`
leaves a phantom reservation, and the per-effect unique index on `event_id` prevents _duplicates_
but says nothing about _order_.

**Still working.** Read-model projections (timestamp guard). Invoice write-back (state guard plus
parking). Anything whose effect is idempotent and commutative — an audit append, a notification
send.

**What a user sees.** A stale value in a list view that a later refresh does not fix, because the
projection has recorded a newer `lastEventAt` than the correcting event carries and will refuse it
forever. Or an inventory position that does not reconcile.

### Detection

There is no direct signal. Out-of-order delivery is detected by its consequences:

- The `Skipping stale event for <Entity> — event older than lastEventAt` debug line is the only
  place the system says the word "stale". It is emitted at `debug` level, so it is invisible at
  the default log level.
- `acme_trading_parked_messages_total{reason="INVALID_STATE"}` counts state-guard rejections,
  which are frequently reordering in disguise. A parked-message rule alerts on any increase over
  5 minutes at critical severity — subject to the same evaluation-path caveat as Sheet 1.
- The `parked_message` table is directly queryable and is the best forensic surface:
  ```sql
  SELECT reason, event_type, count(*), min(parked_at), max(parked_at)
    FROM trading.parked_message
   GROUP BY reason, event_type
   ORDER BY 3 DESC;
  ```
- The inventory reconciliation job compares derived stock against movements. The decision record
  behind the inbox convention describes its intended demotion from "only line of defence" to
  backstop once that convention spreads.

### Recovery

1. Determine whether the effect is recoverable by replay or needs a data fix:
   ```sql
   SELECT id, event_id, event_type, reason, parked_at, payload
     FROM trading.parked_message
    WHERE reason = 'INVALID_STATE'
    ORDER BY parked_at DESC
    LIMIT 20;
   ```
2. For a projection that has latched a too-new `lastEventAt`, the fix is to lower the watermark and
   re-drive, not to edit the projected fields — otherwise the next event re-latches the wrong
   state:
   ```sql
   UPDATE reporting.rpt_deal_summary
      SET last_event_at = '1970-01-01T00:00:00Z'
    WHERE deal_id = '00000000-0000-0000-0000-000000000001';
   ```
   Then replay the events for that aggregate.
3. For a parked message whose source entity has since reached the required state, re-drive the
   single event rather than the whole stream. The parked row carries the original payload verbatim
   for exactly this purpose.
4. If reordering was caused by multiple replicas, scaling the consumer to one replica restores
   per-queue ordering at the cost of throughput. That is a deliberate, reversible trade, not a fix.

### Prevention

**What exists.** `prefetch(1)` everywhere, which makes a single consumer strictly serial.
Timestamp-guarded projections. State-guarded transitions with parking rather than dropping. One
in-process serialisation lock in the notification consumer, which chains every message across its
five per-context consumers onto one promise — introduced because channel-wide `prefetch(1, true)`
is rejected by quorum queues with `NOT_IMPLEMENTED`, and the entity-manager identity map it was
protecting is not concurrency-safe. Its `.catch(() => undefined)` on the chain keeps one failing
message from poisoning every subsequent one.

**What does not exist.** Any per-aggregate ordering mechanism — no consistent hashing to a
partition, no single-active-consumer, no sequence number in the envelope. The envelope has
`eventId` as a time-ordered UUID v7 and a `timestamp`, but no monotonic per-aggregate counter, so
a consumer cannot detect a _gap_, only a _reversal_. No clock-skew monitoring, despite producer
wall-clock time being an ordering input. The staleness log line is at debug level and has no
counter behind it.

---

## Sheet 5 — Poison message

### The failure

A poison message is one that deterministically kills its handler on every attempt: a payload that
fails `JSON.parse`, a field the handler dereferences that is absent, a value in a shape the
handler does not expect. The defining property is determinism — retrying cannot help.

The consumer path is uniform and short. Every consumer wraps its handler in try/catch and, on any
throw, calls `nack(msg, false, false)`: no `allUpTo`, no `requeue`. The broker routes the message
via the queue's `x-dead-letter-exchange` to `<owner>.<context>.dlx`, rewriting the routing key to
the literal `dead-letter` because the queue declares `x-dead-letter-routing-key: dead-letter`. The
dead-letter exchange has one binding on that literal key, to a durable quorum retention queue. The
message is retained.

```mermaid
stateDiagram-v2
  [*] --> Delivered
  Delivered --> Parsed: JSON.parse succeeds
  Delivered --> Nacked: parse throws
  Parsed --> TenantChecked: envelope read
  TenantChecked --> Nacked: tenantId absent and not a platform event
  TenantChecked --> Dispatched: tenant resolved
  Dispatched --> Acked: handler resolves
  Dispatched --> Parked: domain-invalid, recorded with a reason
  Dispatched --> TokenDrop: pre-send failure on a token-bearing key
  Dispatched --> Nacked: handler throws
  Parked --> Acked
  TokenDrop --> Acked: ACK without dead-lettering
  Nacked --> DeadLettered: x-dead-letter-exchange
  DeadLettered --> Retained: binding on the dead-letter key
  Acked --> [*]
  Retained --> [*]
```

Four of those transitions are policy decisions worth spelling out.

**A missing tenant is treated as poison, not as an error.** Both the inventory and trading
consumers check for a tenant id before dispatching and nack immediately with
`Event <id> missing tenantId — rejecting to DLX`. This is a fail-closed multi-tenancy control
expressed as a messaging decision: an event that cannot be scoped to a tenant must not be applied
to any tenant.

**A token-bearing payload is dropped rather than dead-lettered.** The notification consumer keeps
a set of routing keys whose payloads carry a raw single-use token — the invite accept token and
the password-reset token. A pre-send failure on one of those does **not** nack:

```ts
if (TOKEN_BEARING_ROUTING_KEYS.has(routingKey)) {
  this.logger.error(
    `Pre-send failure on token-bearing event ${routingKey} — ACKED (not dead-lettered) ` +
      `to avoid retaining the raw token at rest; resend to retry. Cause: ${message}`
  );
  channel.ack(msg);
  return;
}
```

The reasoning is that a dead-lettered invite would leave a usable bearer credential sitting at
rest in a retention queue until someone replayed it, which defeats the "no usable token at rest"
control the rest of the identity work establishes. The flow is recoverable by resending the
invitation, which mints a fresh token, so the message is worth strictly less than the risk of
keeping it. Note the determination is made from the **routing key**, not the body — deliberately,
because it must be reliable even when the body is what failed to parse. Note also what this costs:
that message is gone, and only a scrubbed log line records that it existed.

**A domain-invalid event is parked, not nacked.** The distinction the code draws is precise: the
dead-letter exchange is the _transport_ backstop for poison and transient failures; the
`parked_message` table is the _domain-level_ quarantine for events that were validly delivered and
correctly parsed but cannot be applied. A parked event is a queryable SQL row with a reason and
the original payload, and the delivery is acked. The two reasons in use are `INVALID_STATE` (the
source entity is not in the state the transition requires) and `UNRESOLVABLE_ENTITY` (the
referenced entity does not exist, or belongs to another tenant).

**Relay-side poison takes a different, lossier path.** When an outbox entry's `version` field
disagrees with its routing key's `.vN` suffix — or is a non-integer, or less than 1 — the relay
does not fail the entry. It publishes a structured envelope
`{ originalRoutingKey, expectedVersion, actualVersion, eventId, reason: 'VERSION_BINDING_MISMATCH' }`
to `<exchange>.dlx`, preserves the original payload on an `x-…-original-payload` header for replay
tooling, logs a WARN, and marks the entry `PUBLISHED` so the relay never re-attempts. The relay's
own comment concedes the gap, and it is worse than the comment says: `dlxRoute` publishes with the
**original** routing key, while the retention queue is bound to that exchange on the literal key
`dead-letter`. A topic exchange does not match `trading.deal.locked.v2` against a binding of
`dead-letter`. The envelope is unroutable and silently discarded, the confirm still succeeds, and
the WARN log is the only forensic record that the event ever existed.

### Blast radius

**Degraded.** Exactly one message, per poison, per consumer. This is the payoff for
`prefetch(1)` plus `requeue: false`: a poison message cannot block the queue, cannot loop, and
cannot starve its successors. The notification consumer additionally isolates failures across its
serialisation chain so one throw does not break the chain for every later message.

**Still working.** Everything else on the queue. The consumer keeps consuming. No crash, no
restart, no backlog.

**What a user sees.** A single missing effect — one email not sent, one stock movement not
recorded, one invoice not written back — with no error surfaced anywhere in the product.

**Except** in one case. A message that kills the _process_ rather than the handler — an
out-of-memory, an unhandled rejection outside the try/catch — is never acked, so the broker
redelivers it to the replacement pod, which dies again. No queue in this codebase sets
`x-delivery-limit`, so nothing in the application configuration bounds that loop. **Unverified:**
the broker (version 4.1.3) may apply its own default delivery limit to quorum queues; confirm
against the broker's documentation for that major version before relying on it. From the
application's side, the loop is unbounded.

### Detection

| Signal                                                                                       | Where         | Latency                                       |
| -------------------------------------------------------------------------------------------- | ------------- | --------------------------------------------- |
| `Failed to process message on <queue> — nack to DLX (<dlx>)` (ERROR)                         | consumer logs | immediate                                     |
| `Event <id> missing tenantId — rejecting to DLX` (ERROR)                                     | consumer logs | immediate                                     |
| `Pre-send failure on token-bearing event <key> — ACKED (not dead-lettered)` (ERROR)          | consumer logs | immediate                                     |
| `OutboxRelay: routed entry <id> to <exchange>.dlx (…reason=VERSION_BINDING_MISMATCH)` (WARN) | relay logs    | immediate                                     |
| Retention DLQ depth crosses zero                                                             | metrics store | 5 min (alert `for` duration)                  |
| `acme_trading_parked_messages_total{reason}`                                                 | metrics       | immediate; alerts only if a rule evaluates it |
| `parked_message` rows                                                                        | direct SQL    | immediate                                     |

Inspect a retained message without consuming it:

```bash
kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
  rabbitmqctl list_queues -p acme name messages | grep dlq
```

The original routing key is not on the message any more — it was rewritten to `dead-letter` — but
it survives in the `x-death` and `x-first-death-*` headers the broker adds when dead-lettering,
along with a redelivery count. That is the only place to recover what the message originally was.

### Recovery

1. Read the ERROR log line that produced the nack. It names the queue, the dead-letter exchange
   and the exception message; that is usually enough to classify the poison.
2. Count and sample the retained messages (`rabbitmqctl list_queues`, then the inspection loop in
   the replay runbook below with `requeue: true` so nothing is consumed).
3. Classify. **Producer defect** — fix the producer and discard the retained copies, because
   replaying a malformed message reproduces the failure exactly. **Consumer defect** — fix the
   consumer, deploy, and replay. **One-off corruption** — discard after recording the payload.
4. If the cause was a version-binding mismatch, the retained copy does not exist. Recover the
   payload from the relay's WARN log, or from the outbox row itself — it was marked `PUBLISHED`,
   not deleted:
   ```sql
   SELECT id, event_type, routing_key, payload
     FROM platform_outbox.outbox_entry
    WHERE id = '00000000-0000-0000-0000-000000000001';
   ```
5. Replay per the runbook below, only after the fix is deployed and only if the handler's
   idempotency has been confirmed.

### Prevention

**What exists.** Nack-without-requeue as the universal policy, which converts every poison into a
bounded, retained, single-message loss. A per-context dead-letter exchange in each consumer's own
permission namespace, so a consumer can always declare its own DLX regardless of who owns the
source exchange. A bound retention queue on every consumer DLX — without one, a dead-letter
exchange is a black hole. Fail-closed tenant validation. Domain-level parking that preserves the
payload and a machine-readable reason. Token-bearing payloads excluded from at-rest retention.

**What does not exist.** Schema validation at the consumer boundary — every consumer does
`JSON.parse(...) as DomainEvent<T>`, an unchecked cast, so a shape mismatch surfaces as a
`TypeError` deep inside a handler rather than as a rejected envelope at the edge. Any
`x-delivery-limit`, so a process-killing message is an unbounded redelivery loop from the
application's point of view. A working retention path for relay-side version mismatches — the
fix is one line, either publishing the DLX envelope with the `dead-letter` key or adding a `#`
binding to each dead-letter exchange. And a poison-specific alert: the only detector is DLQ depth,
which conflates poison with transient failure.

---

## Sheet 6 — Consumer crash mid-batch

### The failure

"Mid-batch" is almost a misnomer here, and that is the point. Every consumer calls
`channel.prefetch(1)`, so the broker will not hand a consumer a second message until the first is
acked. The in-flight window is one message per consumer, not per channel — the notification
consumer registers five consumers (one per source context) on a single channel with
`prefetch(1, false)`, so its worst case is five unacked messages, of which its in-process
serialisation lock lets exactly one execute at a time.

The reason it is per-consumer rather than channel-wide is a broker constraint, not a preference:
channel-wide QoS (`prefetch(1, true)`) is rejected by quorum queues with `NOT_IMPLEMENTED`. That
rejection is why the serialisation lock exists at all.

When the consumer dies — pod eviction, OOM kill, `SIGKILL`, node failure — the TCP connection
drops, the broker sees the channel close, and every message delivered on it and not yet acked is
requeued. The broker marks each as redelivered and increments the delivery counter that quorum
queues maintain. Nothing in the codebase reads either flag.

Graceful shutdown is a different path with the same outcome. Tier A and Tier B consumers implement
`OnModuleDestroy`: they set a `destroyed` guard so the reconnect loop cannot re-arm, clear any
pending reconnect timer, remove the channel's `close` and `error` listeners, and close the channel.
The unacked message is requeued just the same, but the shutdown is quiet — no error spam from a
reconnect loop opening channels on a closing connection. Tier C consumers never close their
channel; the connection close cleans up after them.

```mermaid
sequenceDiagram
  autonumber
  participant BR as Broker
  participant C as Consumer pod
  participant H as Handler
  participant DB as Database
  participant IB as Inbox table

  BR->>C: deliver E1 — prefetch window now full
  C->>H: apply E1
  H->>DB: write state change, commit
  Note over C,IB: inventory records the inbox row AFTER apply
  C--XC: pod killed before the inbox insert
  BR->>BR: E1 unacked — requeued, redelivered flag set
  BR->>C: redeliver E1 to the replacement pod
  C->>IB: hasProcessed consumer, E1 → false
  C->>H: apply E1 again
  H->>DB: unique index on event_id rejects the duplicate effect
  C->>IB: record consumer, E1
  C->>BR: ack E1
```

The diagram shows why the inventory inbox ordering is safe despite looking wrong. The window
between the state change committing and the inbox row being written is real, and a crash inside it
does cause a re-application. It is safe only because the per-effect unique index absorbs the second
attempt. Remove that index and the ordering becomes a data-corruption bug. Trading's handler avoids
the window entirely by writing the inbox row inside the same transaction as the state change — it
can, because its handler owns one transaction spanning everything it touches.

### Blast radius

**Degraded.** One message per consumer, briefly. It is redelivered to the replacement pod within
the pod's startup time.

**Still working.** Everything else. The queue is not blocked; other consumers on the same queue,
if any, keep draining it.

**What a user sees.** Usually nothing — a redelivery a few seconds later completes the effect.
The visible failure is second-order: if the redelivered message re-applies a non-idempotent effect
(Sheet 3), the user sees a doubled figure; if it re-enters the stream behind newer messages
(Sheet 4), the user sees a stale one.

**The exception is Tier C.** Those five consumers do not crash on a channel close — they carry on
running with a dead subscription. There is no replacement pod because nothing died. The unacked
message is requeued and simply sits there, along with everything published afterwards, until
someone restarts the pod.

### Detection

- `Channel closed for queue=<q> — scheduling reconnect` (WARN) followed by
  `Reconnect attempt n in Xms` — Tier A and B only.
- `Max reconnect attempts (100) reached for queue=<q> — manual intervention required` (ERROR) is
  the terminal line. After it, that consumer is dead and nothing will retry. At Tier B's default
  backoff that message appears roughly eight hours after the first failure; at Tier A's much more
  aggressive constants, roughly fifty minutes.
- Queue depth rising while consumer count is zero is the definitive broker-side signal, and the
  only one that catches Tier C:
  ```bash
  kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
    rabbitmqctl list_queues -p acme name messages consumers
  ```
  A queue with `messages > 0` and `consumers = 0` has no one attached. It is broker state, which
  means no application-level probe reports it and it is seen only by someone who goes and looks.
- Unacked depth (`rabbitmq_queue_messages_unacked`) is a broker dashboard number, and a number on
  a dashboard is a signal someone must read rather than a detector that finds them.
- The `rabbitmq` readiness check reports `ok` throughout, because the connection is fine.

### Recovery

1. Identify queues with no consumer:
   ```bash
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
     rabbitmqctl list_queues -p acme name messages consumers | awk '$3 == 0 && $2 > 0'
   ```
2. Map each orphaned queue to its owning service by name — every queue is prefixed with its
   owner's service name (`reporting-service.trading`, `audit-service.events`,
   `inventory-service.trading`).
3. Restart the owning pod. For a Tier C consumer this is the _only_ recovery:
   ```bash
   kubectl delete pod -n platform-<bundle> -l app.kubernetes.io/name=<svc>-service
   ```
4. Confirm the consumer re-attached and the backlog is draining — `consumers` becomes 1 and
   `messages` falls.
5. If the reconnect ceiling was hit (`manual intervention required` in the log), the restart is
   again the fix; the counter resets on a successful setup.

### Prevention

**What exists.** `prefetch(1)` universally, which is what makes the blast radius one message.
Per-consumer QoS rather than channel-wide, forced by quorum queues but correct anyway. A reconnect
counter that resets to zero after every successful setup, so a long-lived pod surviving many
isolated blips never accumulates its way to the ceiling — the counter bounds an unbroken failure
streak, not a lifetime. Recovery driven from `close` only, with `error` reduced to logging, so
amqplib's `error`-then-`close` double-emit produces one reconnect chain rather than two. An
`error` listener registered purely so an unhandled `error` event does not crash the process per
the EventEmitter contract. Deterministic teardown before each reconnect. Inbox and per-effect
uniqueness to absorb the redelivery.

**What does not exist.** Reconnect for the five Tier C consumers — the single largest gap in this
document, because it turns a self-healing event into a permanent silent stop. Any health check,
metric or alert that reflects consumer attachment; `consumers = 0` on a queue is invisible to the
platform. Any use of the `redelivered` flag or the quorum delivery counter to detect a message
that has been retried many times. A shared shutdown contract — Tier C never closes its channel and
Tier D has no teardown at all.

---

## Sheet 7 — DLQ accumulation

### The failure

Every consumer queue dead-letters to an exchange, and every dead-letter exchange has exactly one
bound queue whose sole purpose is retention. Nothing consumes a retention queue. That is by
design: a DLQ is an inspection surface, not a retry mechanism. The failure mode is therefore not
that the DLQ fills — it is that the DLQ fills **and nobody finds out**.

There are two historical variants, and they have opposite root causes.

**Variant one — the DLQ does not exist.** A dead-letter exchange with no bound queue silently
discards everything routed to it. This was live for weeks: twelve `*.dlx` exchanges existed on the
broker and exactly **one** `*.dlq` queue did — audit-service's. Every other context's nacked
messages were dropped, not retained. What makes this instructive is the root cause. It was not a
code gap: the shared consumer helper and all five hand-rolled consumers declared DLX, DLQ and
binding. It was not a permission gap: the consumer principals' `configure` regexes matched their
own DLQ names. It was a **stale build artifact** — the deployed image was tagged with a commit
whose ancestry contained the DLQ code, yet shipped compiled JavaScript that predated it. The
smoking gun was the broker's own log: work queues had a creation timestamp, and the sibling DLQ
declared on the line immediately before them in the same linear, try/catch-free setup path had no
creation line at all, across four days of reconnects.

The fix chain is worth recording because two attempts failed for non-obvious reasons. Bumping the
cache-version file did not bust the image build — that file is an input to the task-runner cache,
not to the Docker build context. Adding a `COPY` of it into the Dockerfile failed because its
directory is excluded by `.dockerignore`. Rewriting the ignore rule with a `!`-negation to
re-include the single file passed locally and still failed in CI, because CI's _shared, persistent_
BuildKit daemon prunes the excluded subtree before the negation can re-include it, while a local
BuildKit does not. The working fix was to stop copying entirely: read the file on the runner and
pass it as `--build-arg`, referenced in the build `RUN` so a changed value changes the layer cache
key. The durable lesson — never rely on `.dockerignore` negation under a shared BuildKit daemon —
is a build-system lesson that presented as a messaging outage.

**Variant two — the DLQ exists and grows unnoticed.** This is the shape that remains once the
first variant is fixed. Messages accumulate, nothing consumes them, and the only thing standing
between silent growth and an operator is a depth metric.

```mermaid
flowchart TD
  NACK["Consumer nacks with requeue false"] --> DLX["Context dead-letter exchange"]
  DLX --> BIND{"Is a queue bound<br/>on the dead-letter key?"}
  BIND -- "No" --> BLACKHOLE["Message discarded silently<br/>the historical 11 of 12 case"]
  BIND -- "Yes" --> DLQ["Durable quorum retention queue"]
  DLQ --> GROW["Depth grows — no consumer by design"]
  GROW --> SCRAPE{"Is per-queue depth<br/>reaching the metrics store?"}
  SCRAPE -- "No" --> BLIND["Growth invisible"]
  SCRAPE -- "Yes" --> RULE{"Is a rule evaluating it?"}
  RULE -- "Rule on an unreconciled path" --> BLIND
  RULE -- "Rule on a reconciled path" --> ALERT["Warning after 5 minutes above zero"]
  ALERT --> TRIAGE["Operator triage and replay"]

  RELAY["Relay version-mismatch envelope"] --> DLXDIRECT["Published to the DLX with the ORIGINAL routing key"]
  DLXDIRECT --> NOMATCH["No binding matches — discarded, confirm still succeeds"]
```

The right-hand branch is the subtler leak: a nacked consumer message reaches the
retention queue because the _queue_ rewrites its routing key to `dead-letter`, which is exactly the
binding key. A relay-generated version-mismatch envelope is published _directly_ to the same
exchange with the original routing key, which matches nothing. Two paths into one exchange, only
one of which is retained.

The scrape branch has its own trap, and it is a good example of a metric that exists without being
useful. The broker's default `/metrics` endpoint emits only an **aggregate** `rabbitmq_queue_messages`
with no `queue` label — live inspection returned the single line `rabbitmq_queue_messages 0` and
zero `queue=`-labelled lines. Per-queue depth is only available from `/metrics/detailed` as
`rabbitmq_detailed_queue_messages{vhost,queue}`. Any alert written against the obvious metric name
with a `queue=~".*\.dlq"` selector therefore matches nothing forever while looking entirely
plausible in review.

### Blast radius

**Degraded.** Nothing, immediately — that is what makes it dangerous. The consumer is healthy, the
queue is draining, throughput is normal. The degradation is entirely in effects that silently did
not happen.

**Still working.** Everything. This failure has no runtime symptom at all.

**What a user sees.** Absence, discovered late and usually by a human noticing a business
inconsistency: an invoice that was never posted, an email that never arrived, a commission that
was never calculated. In the recorded email incident, seven messages sat in one retention queue
until someone asked why discovery emails were not arriving.

### Detection

| Detector                                      | Expression                                                                                          | Severity | Evaluated?                                                                                             |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------ |
| Dashboard-provisioned depth rule              | `rabbitmq_detailed_queue_messages{queue=~".*\\.dlq"}` reduced by `last`, threshold `> 0`, `for: 5m` | warning  | yes — the dashboard's own rule store, fed by a collector scraping `/metrics/detailed`                  |
| Operator-format rule expressing the same idea | `sum by (queue)(rabbitmq_queue_messages{queue=~"<service>\\..*dlq"}) > 0` for 1m                    | critical | only where a deploy generator references its rules directory _and_ an operator reconciles the resource |
| Broker inspection                             | `rabbitmqctl list_queues -p acme name messages`                                                     | —        | manual                                                                                                 |
| Consumer ERROR log at nack time               | `Failed to process message … nack to DLX`                                                           | —        | yes, but only at the moment of failure                                                                 |

Three gaps compound here. The depth rule is **warning** severity and depth-only: it fires on the
first retained message and then stays firing, so a queue that has held one message for a month and
a queue that gained a thousand in an hour look identical. There is no _age_ signal — nothing
reports the oldest retained message. And the rule's runbook prescribes a replay procedure that
does not work under this system's own permission model (see the replay section).

Note also that the two chart-rendered audit-feed dead-letter resources are inert: the bootstrap
chart ranges over _all_ exchanges and renders `acme.audit-feed.dlx` and `acme.audit-feed.dlq`, but
the audit principal's `configure` regex is `^(audit\.events|audit-service\..*)$`, which cannot
declare them, so the consumer uses `audit-service.events.dlx` and `.dlq` instead.

### Recovery

1. Enumerate every retention queue and its depth. This is the single most useful command in this
   document:
   ```bash
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
     rabbitmqctl list_queues -p acme name messages | grep dlq
   ```
2. Confirm each expected DLQ exists at all. A context with a `*.dlx` and no `*.dlq` is variant one
   — dead-lettered messages are being discarded right now:
   ```bash
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
     rabbitmqctl list_exchanges -p acme name | grep dlx
   ```
   If a DLQ is missing while the code declares it, suspect the deployed artifact before the code.
   Verify by exporting the image and grepping its compiled bundle rather than trusting the tag.
3. Sample the retained messages non-destructively — `basic.get` with `requeue: true` so nothing
   is consumed. Use the inspection form of the replay loop below.
4. Correlate each sample against the consumer's ERROR log at the corresponding timestamp to find
   the cause.
5. Check idempotency before replaying: if the handler dedups on a natural key, some retained
   messages may already have been applied by another path, and an operator retry endpoint (where
   one exists) is preferable to a bulk drain.
6. Fix the cause, deploy, verify the new artifact actually contains the fix, then replay per the
   runbook below.

### Prevention

**What exists.** A bound retention queue for every consumer dead-letter exchange, declared before
the main queue so the binding exists by the time any message can dead-letter. Durable quorum
queues for retention. Chart-declared CRDs whose names and types must match the runtime asserts
exactly — a redeclare with different arguments closes the channel with `PRECONDITION_FAILED`,
which is why the chart keys its dead-letter resources off _exchanges_ rather than services. A depth
alert written against the correct metric name.

**What does not exist.** Any consumer of a retention queue, or any tooling committed to the
repository for draining one — a repository-wide search for reprocess tooling returns prose and one
unrelated comment. An age-based signal. A per-queue owner mapping, so an alert on
`acme.communication.dlq` does not say who to page. Any bound on retention: no queue in the
codebase sets `x-message-ttl` or `x-max-length`, so a retention queue grows until it presses on the
broker's 20 GiB volume or its 0.7 memory watermark — at which point Sheet 8 begins. A retention
path for relay-generated version-mismatch envelopes. And a critical-severity rule on an evaluation
path that is actually reconciled — severity declared in a rule file is only as real as the path
that reads it.

---

## Sheet 8 — Publisher confirm never arrives

### The failure

The relay publishes on a confirm channel and treats the broker's acknowledgement as the completion
signal. `publishOnce` wraps `channel.publish(..., callback)` in a promise that settles when the
callback fires. If the callback never fires, the promise never settles.

amqplib covers the common case itself. On channel close it drains its unconfirmed-callback window
and invokes every pending callback with `Error('channel closed')`:

```js
this.on("close", function () {
  var cb;
  while ((cb = this.unconfirmed.shift())) {
    if (cb) cb(new Error("channel closed"));
  }
});
```

So a clean channel close produces a prompt rejection, Phase 2 catches it, and the entry is retried
normally. The dangerous case is the one where **no close event ever fires**: the TCP connection
half-closes during a network partition, or the broker blocks the publishing connection because it
crossed the memory or disk alarm threshold. The socket is open, the channel is open, amqplib is
waiting, and the confirm is never coming.

Without a bound, three things cascade. The publish promise hangs. The poll cycle that awaits it
never completes, so `inFlightPromise` never resolves. And `onModuleDestroy` awaits
`inFlightPromise`, so `SIGTERM` blocks indefinitely and the pod is eventually `SIGKILL`ed by the
grace period.

`withConfirmTimeout` bounds it at `publishConfirmTimeoutMs`, default 30 000 ms:

```ts
private withConfirmTimeout<T>(inner: Promise<T>, contextLabel: string): Promise<T> {
  const timeoutMs = this.config.publishConfirmTimeoutMs;
  inner.catch((lateErr: unknown) => { /* absorb a late rejection */ });
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeoutPromise = new Promise<T>((_, reject) => {
    timer = setTimeout(() => reject(new Error(
      `OutboxRelay publish confirm timeout after ${timeoutMs}ms (${contextLabel}). ` +
      `AMQP channel did not invoke the confirm callback — likely a dropped ` +
      `connection. Entry will be retried via Phase 3 retry budget.`)), timeoutMs);
  });
  return Promise.race([inner, timeoutPromise]).finally(() => {
    if (timer !== undefined) clearTimeout(timer);
  });
}
```

Three details in those fifteen lines are load-bearing. `Promise.race` does not cancel the loser, so
an explicit `.catch` is attached to `inner` as defence in depth — a late rejection from a publish
that settles after the timeout would otherwise risk surfacing as an unhandled rejection depending
on microtask ordering. The timer is cleared in `finally` so a fast publish does not hold a
30-second timer per message. And the `contextLabel` is chosen by the caller so that during a
dual-publish window it reads `dual-publish window v2 (canonical OR legacy may have hung)` rather
than naming a single routing key — the entry's stored routing key is not necessarily the one that
hung, and an operator reading `last_error` should not be misled into fixing the wrong binding.

The timeout converts a hang into an ordinary publish failure, and the entry goes back to `PENDING`
with an incremented retry count. Which leaves the other half of this sheet: the rows that get
stuck.

```mermaid
stateDiagram-v2
  [*] --> PENDING: EventPublisher writes in the business transaction
  PENDING --> PUBLISHING: Phase 1 claim under the advisory lock
  PUBLISHING --> PUBLISHED: publish confirmed, Phase 3 update affected > 0
  PUBLISHING --> PENDING: publish failed, retry budget remaining
  PUBLISHING --> FAILED: publish failed, retry budget exhausted
  PUBLISHING --> STUCK: Phase 3 transaction threw — row never left PUBLISHING
  PUBLISHING --> LOCKLOST: Phase 3 update affected 0 — an external writer moved the row
  STUCK --> FAILED: reaper flips it after the grace period
  LOCKLOST --> [*]: relay reverts in memory and does not retry
  PUBLISHED --> [*]
  FAILED --> [*]
```

The `STUCK` state is deliberate, and the reasoning is the crux of the whole design. The relay's
claim query filters on `status = 'PENDING'`, so a row left in `PUBLISHING` is invisible to every
future cycle. That is the safe direction: the publish may well have succeeded, and re-publishing
would duplicate. A stuck row is a visible, recoverable problem; a duplicate is an invisible,
unrecoverable one.

Phase 3 batches ten rows per transaction by default (`persistChunkSize`), trading strict per-entry
isolation for roughly a tenth of the round trips. When a chunk's transaction throws, all ten rows
are left stuck, each entry's in-memory mutation is reverted from a snapshot, an ERROR is logged per
row, and a counter `outbox_relay_stuck_publishing_total{event_type}` is incremented — labelled by
event type only, deliberately excluding the entry id to avoid a cardinality explosion. The counter
is resolved lazily from the tracing API and degrades to `undefined` if that package is absent, in
which case the ERROR log remains the only signal.

The `LOCKLOST` state exists because Phase 3 does not flush an entity — it issues
`nativeUpdate(OutboxEntry, { id, status: <snapshot status> }, target)`. If an administrator, a
recovery script or a peer relay moved the row out of `PUBLISHING` between Phase 2 and Phase 3, the
update matches zero rows, the relay reverts its in-memory state and warns, and it does **not**
retry — the external writer is treated as the source of truth.

The reaper is the safety net for `STUCK`. Every 15 minutes (first scan 5 seconds after wiring, so
an incident surfaces on restart rather than a full interval later) it selects up to 100
`PUBLISHING` rows older than `warnAfterMs` (default 15 minutes) oldest-first, warns with a sample
of up to five ids, and flips anything older than `failAfterMs` (default 4 hours) to `FAILED` with
an explicit marker:

> `OutboxReaper: stuck in PUBLISHING since <ts> (> 14400000ms). Marker write was lost mid-cycle;
event may or may not have been delivered to RabbitMQ. Manual review required.`

That message is unusually honest and exactly right: the reaper cannot know whether the publish
succeeded, so it says so rather than implying either. The flip is an atomic
`UPDATE … WHERE id = ? AND status = 'PUBLISHING'`, so if the relay's Phase 3 wins the race the
reaper sees zero affected rows and logs a lost race instead of overwriting a `PUBLISHED` state.
Each flip is a true top-level transaction — the scan deliberately does _not_ wrap them in an outer
transaction — because that is what makes `SET LOCAL statement_timeout` bound the individual
statement rather than leak into a savepoint of a larger one, and what keeps one flip's failure from
rolling back its peers. A watchdog rejects a scan that exceeds 90% of the scan interval, so a
stalled connection pool cannot wedge the loop silently. And the reaper runs a separate
`count(*) WHERE status = 'PUBLISHING'` query so the backlog signal reflects the true total rather
than however many rows this batch happened to contain.

The reaper's known approximation is stated in its own docstring: it uses `created_at` as a proxy
for "publishing since", because there is no `publishing_since` column. In steady state rows are
claimed within about a second of creation, so the proxy is accurate for nearly all stuck entries —
but for a row that sat `PENDING` through a long broker outage before being claimed, the reaper's
age is the age since _creation_, not since the claim, and it will be flipped early.

### Blast radius

**Degraded.** The affected event types. A stuck row is an event that may or may not have been
delivered, so the downstream effect is in an unknown state. During a genuine hang, the relay's poll
cycle blocks for up to 30 seconds per message, so throughput collapses to roughly two messages per
minute for the duration.

**Still working.** Business writes (the outbox row commits regardless). Consumers. Every event
type not caught in the affected chunk.

**What a user sees.** Delayed effects during the hang, then either the effect appearing late, or
never appearing, with no way to tell which from outside. If a stuck row is manually re-armed and
the original publish _had_ succeeded, the user sees a duplicate — which is why the manual re-arm
is gated behind a judgement call rather than automated.

### Detection

| Signal                                                                                         | Meaning                          | Latency                                                      |
| ---------------------------------------------------------------------------------------------- | -------------------------------- | ------------------------------------------------------------ |
| `OutboxRelay publish confirm timeout after 30000ms (…)` (in the entry's `last_error`)          | a publish hung and was abandoned | 30 s per occurrence                                          |
| `OutboxRelay: entry <id> stuck in PUBLISHING — status update failed …` (ERROR)                 | Phase 3 transaction threw        | immediate                                                    |
| `outbox_relay_stuck_publishing_total{event_type}`                                              | count of stuck rows              | immediate; a counter is not a detector until a rule reads it |
| `OutboxRelay: entry <id> optimistic-lock lost …` (WARN)                                        | an external writer moved the row | immediate                                                    |
| `OutboxReaper: N entries stuck in PUBLISHING for > 900000ms (oldest: …, sample ids: …)` (WARN) | the backlog signal               | up to 15 min                                                 |
| `OutboxReaper: flipped entry <id> PUBLISHING → FAILED after 14400000ms grace period` (ERROR)   | terminal                         | 4 h                                                          |
| `acme_trading_outbox_lag_seconds`                                                              | age of the oldest `PENDING` row  | 15 s; same evaluation-path caveat                            |

The lag gauge deserves a caveat. Its query has no service predicate:

```sql
SELECT payload->>'tenantId' AS tenant,
       EXTRACT(EPOCH FROM (now() - min(created_at))) AS lag_seconds
  FROM platform_outbox.outbox_entry
 WHERE status = 'PENDING'
 GROUP BY payload->>'tenantId'
```

Because the outbox table is shared, this reports the lag of the _whole platform outbox_ while
labelling it `service="trading-service"` — and it is emitted by a service whose own relay is
disabled. It is a useful platform-wide signal wearing a misleading label.

Direct inspection:

```sql
SELECT status, count(*), min(created_at) AS oldest
  FROM platform_outbox.outbox_entry
 GROUP BY status;

SELECT id, event_type, routing_key, retry_count, created_at, last_error
  FROM platform_outbox.outbox_entry
 WHERE status = 'PUBLISHING'
   AND created_at < now() - interval '15 minutes'
 ORDER BY created_at
 LIMIT 50;
```

### Recovery

1. Establish whether the broker is blocking publishers, which is the most common cause of a hang
   that produces no close event:
   ```bash
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- rabbitmqctl status \
     | grep -A5 -E 'Memory|alarms'
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- rabbitmqctl list_connections \
     name state user
   ```
   A connection in state `blocked` or `blocking` is the answer. Relieve the alarm — drain a large
   queue, or raise the memory limit and watermark — before touching any rows.
2. Inventory the stuck rows with the second query above. Note `last_error`: a confirm timeout, a
   `403 ACCESS_REFUSED`, and a `Channel closed` are three different incidents.
3. Decide per event type whether re-publishing is safe. It is safe when the consumer has an inbox
   row or a per-effect unique key (inventory, trading, notification deliveries); it is not safe
   otherwise (Sheet 3's table of who has what).
4. Re-arm the rows that are safe to retry, one id at a time for financial event types:
   ```sql
   UPDATE platform_outbox.outbox_entry
      SET status = 'PENDING', retry_count = 0, last_error = NULL
    WHERE id = '00000000-0000-0000-0000-000000000001'
      AND status = 'PUBLISHING';
   ```
   The `AND status = 'PUBLISHING'` predicate is not decoration — it is the same optimistic guard
   the relay and reaper use, and it stops the update racing a Phase 3 write that is committing at
   that instant.
5. For rows that are not safe to retry, leave them and let the reaper flip them to `FAILED` after
   the grace period, then reconcile the downstream effect by domain-specific means.
6. If the relay is not progressing at all, confirm it holds its advisory lock and is not being
   starved:
   ```sql
   SELECT pid, objid, granted FROM pg_locks WHERE locktype = 'advisory';
   ```

### Prevention

**What exists.** A bounded confirm wait with an explicit late-rejection sink and timer cleanup. A
three-phase cycle that never wraps a publish in a transaction. A safe-state choice — stuck rather
than duplicated — with the reasoning written into the entity's own docstring. An optimistic-lock
predicate on every status write, on both the relay and the reaper side. A reaper with an eager
first scan, a bounded batch, a per-entry statement timeout, a watchdog, an independent total-count
signal, constructor validation that rejects configurations which would silently disable it, and a
`lastError` marker that is honest about ambiguity. A counter for stuck rows that degrades
gracefully when the tracing API is unavailable.

**What does not exist.** A `publishing_since` column, which would remove the reaper's only
approximation. Any listener on amqplib's connection `blocked` and `unblocked` events, so a broker
that is deliberately blocking this publisher is indistinguishable from one that is merely slow.
An evaluated rule over `outbox_relay_stuck_publishing_total` or over outbox lag — emitting a
counter is the cheap half of a detector, and the half that tends to get done. A per-key publish
checkpoint, which would let a retry skip already-confirmed routing keys. And a channel-level close
handler on the shared connection wrapper, which is why a single `403` on one publish permanently
wedges the relay's channel until the pod restarts.

---

## Sheet 9 — A binding nothing publishes

### The failure

A topic binding that matches no published routing key is indistinguishable from a topic binding
during a quiet period. The queue exists, the consumer is attached, the broker is healthy, the
dashboard shows zero — and zero is what an idle system looks like too. There is no error, no
warning, and no broker-side notion of "this binding has never matched anything".

There is a recorded instance. The commission consumer binds three routing keys:

```ts
const ROUTING_KEY_DEAL_LOCKED = "trading.deal.locked";
/** v2 of deal.locked — adds idempotencyKey to payload. */
const ROUTING_KEY_DEAL_LOCKED_V2 = "trading.deal.locked.v2";
const ROUTING_KEY_CREDIT_NOTE_FINALISED = "trading.credit-note.finalised";
```

and dispatches on the routing key rather than the body precisely so it can tell v1 from v2. But
nothing publishes `trading.deal.locked.v2`, and nothing can, for three independent reasons. The
trading publisher hard-codes `version: 1` on every envelope it constructs. No bundle sets
`eventBus.transitionVersion`, so the relay's dual-publish branch — which requires
`transitionVersion === version && version > 1` — is never taken. And the relay derives its
canonical key from the entry's own version, so a v1 entry can only ever produce the bare key. The
`.v2` binding is a permanent no-op, and the `case ROUTING_KEY_DEAL_LOCKED_V2:` branch behind it is
unreachable code.

A second instance is more instructive, because in it the _feature works_ and the binding is still
dead. The document generation worker declares its job queue and then binds it to the communication
topic exchange:

```ts
const JOB_QUEUE_NAME = "jobs.communication.document-generation";
const JOB_EXCHANGE_NAME = "acme.communication";
// ...
await channel.bindQueue(
  JOB_QUEUE_NAME,
  JOB_EXCHANGE_NAME,
  "jobs.document.generate"
);
```

But the only site that enqueues a generation job does not publish to that exchange at all. It
publishes to the **default** exchange with the routing key set to the queue name, which the default
exchange routes directly to the queue by name:

```ts
await this.rabbitMqConnection.publish(
  "", // default exchange — direct queue routing
  "jobs.communication.document-generation",
  { documentId: doc.id, tenantId },
  { persistent: true }
);
```

So jobs are delivered, the pipeline works, and `jobs.document.generate` is a routing key that no
producer has ever emitted. The binding is invisible, harmless and permanently misleading — a
reader tracing the job flow from the worker outwards will look for a publisher on the communication
exchange and not find one. That is the characteristic cost of this failure mode even in its benign
form: it makes the topology lie about how the system works.

The mirror image is worse, because it loses messages rather than merely never receiving them: a
**producer** whose routing key no binding matches. A topic exchange discards an unroutable message
silently. The publisher can detect this by setting the AMQP `mandatory` flag and listening for the
broker's `basic.return`. Nothing in this codebase sets `mandatory` — the relay's publish options
are `{ persistent: true, contentType, messageId, headers }` and the dual-publish helper's are
`{ persistent: true, headers }` — and no `return` listener is registered anywhere. So a typo'd
routing key produces a _successful publisher confirm_ for a message that was thrown away.

That is not hypothetical either. It is exactly why the relay's version-mismatch envelope is lost
(Sheet 5): it is published to the dead-letter exchange with the original routing key, no binding
matches, the message is discarded, and the confirm succeeds.

```mermaid
flowchart LR
  subgraph Producer side
    P["Producer publishes routing key K"] --> EX["Topic exchange"]
    EX --> M{"Any binding<br/>matches K?"}
    M -- "No" --> DROP["Discarded silently<br/>confirm still succeeds<br/>because mandatory is not set"]
  end
  subgraph Consumer side
    B["Consumer binds pattern P"] --> QU["Queue"]
    QU --> N{"Any producer<br/>emits a key matching P?"}
    N -- "No" --> IDLE["Queue depth stays 0<br/>indistinguishable from idle"]
  end
  M -- "Yes" --> QU
  N -- "Yes" --> DELIVER["Delivered"]
```

The diagram's two halves are the same defect seen from opposite ends, and neither end has a
detector. The only asymmetry is consequence: an unmatched binding wastes a queue, an unmatched
publish loses an event.

There is a third variant in the same family — the routing key matches but the _payload_ does not.
The invoice write-back is the recorded case. The producer emitted
`{ invoiceId, erpUrn, referenceNumber, type, idempotent }`; the shared contract declared
`{ invoiceId, sourceEntityType, sourceEntityId, erpUrn, processedAt, tenantId }`; the consumer
read four fields that were all `undefined` and parked every message as `UNRESOLVABLE_ENTITY`. A
third artefact — the provider contract test — documented a fourth shape, so none of the three
agreed. There was also a casing mismatch: the producer stored title-case values (`'Sale'`) while
the consumer switched on upper-case (`'SALE'`), so even a corrected payload would still have
parked. The root cause was mechanical and generalises: the publish call was untyped, so
`publish<T>` inferred `T` from the object literal rather than checking it against the contract.
Typing the call site was the fix. The same defect hides anywhere else the pattern repeats: a
publish site that still emits a legacy, untyped shape no longer matching the payload its contract
declares, with nothing at compile time to say so.

### Blast radius

**Degraded.** The entire feature behind the binding, silently and from day one. Because it has
never worked, there is no regression to notice — no dashboard line that dropped, no alert that
fired, no user report that "it stopped".

**Still working.** Everything else. This failure mode has no runtime cost at all; a binding that
matches nothing consumes no resources and produces no errors.

**What a user sees.** A feature that was announced and does not exist. In the write-back case,
finalised sale lines that never transitioned to invoiced, which is a financial-reporting
discrepancy discovered by reconciliation rather than by monitoring.

### Detection

There is no automatic detection. The available checks are all manual and all cheap:

1. Compare the broker's bindings against what actually flows:
   ```bash
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
     rabbitmqctl list_bindings -p acme source_name destination_name routing_key
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
     rabbitmqctl list_queues -p acme name messages consumers
   ```
   A queue with a consumer, zero messages and a producer that is demonstrably publishing is the
   signature.
2. Prove the producer side from the outbox rather than the broker — the outbox is the record of
   what was _meant_ to be published, and it survives:
   ```sql
   SELECT event_type, routing_key, status, count(*)
     FROM platform_outbox.outbox_entry
    WHERE created_at > now() - interval '7 days'
    GROUP BY event_type, routing_key, status
    ORDER BY 4 DESC;
   ```
   A routing key a consumer binds that never appears in this result has no producer.
3. For payload-shape drift, provider and consumer contract tests are the only mechanism, and they
   only work if all three artefacts — contract, producer, consumer — are kept in agreement.

### Recovery

1. Decide which side is authoritative. If the consumer is speculatively bound ahead of a producer
   that was never built, delete the binding and the unreachable dispatch branch. If the producer
   was supposed to emit the key, fix the producer.
2. Never "fix" a payload mismatch by loosening the consumer. In the recorded case the fix was made
   at the emit site — canonicalising the casing there and typing the publish call — so that the
   contract remained the single source of truth and the next drift would fail to compile.
3. After a producer fix, the events that were lost are gone: unroutable publishes are not retained
   anywhere. If the source state is still queryable, re-emit from it rather than attempting a
   replay. The write-back case was closed this way, with a test that boots the real fail-closed
   infrastructure and drives a producer-shaped event through to the expected transition and zero
   parked rows.
4. Remove the dead binding so the next reader is not misled. Deleting the `bindQueue` call is
   necessary but **not sufficient**: `assertQueue` is idempotent and does not remove bindings, so a
   binding already established on a long-lived queue survives every redeploy. Confirm what is
   actually bound, and remove the orphan explicitly:
   ```bash
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
     rabbitmqctl list_bindings -p acme source_name destination_name routing_key \
     | grep '<queue-name>'
   ```
   Then delete the binding through the management API (port-forward `15672`; the management UI is
   ClusterIP-only by design and is not exposed through the ingress).

### Prevention

**What exists.** The decorator-plus-explorer path derives exchange, routing key, queue, dead-letter
exchange and dead-letter queue from a single authored `eventType`, so a handler author cannot bind
to the wrong context by typo. Both the relay and the explorer derive the exchange with the same
rule, and both refuse a malformed event type — the explorer warns and skips rather than asserting
an `undefined` exchange. The relay validates the version against the routing key on every publish.
Provider and consumer contract tests exist for the accounting-to-trading integration.

**What does not exist.** Any check that a bound routing key has a producer, or that a published
routing key has a binding — either at startup or in CI, where it would be a straightforward static
comparison of two sets both derivable from the source tree. The `mandatory` flag and a
`basic.return` listener, which would turn an unroutable publish from silent into loud for the cost
of a few lines. Typed publish call sites everywhere — any untyped one will drift the same way. And
the seven hand-rolled consumers still declare their bindings as local string
constants rather than deriving them from the same shared definition the producer uses, which is
what allowed the `.v2` binding to be written for an event that could not exist.

---

## DLQ replay

Replaying a retention queue looks trivial and is not. The procedure below has been executed
end-to-end against a real backlog — seven retained messages drained to zero, all seven reaching
`DELIVERED`, no re-failures — and every step exists because a simpler step failed.

### Why the obvious approaches do not work

| Approach                                                               | Outcome                                                                                                                                                                                                                                                                                                                                              |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Publish to the default exchange (`""`) and let the queue name route it | **403.** The default exchange's resource name is the empty string, which matches no per-service permission regex, so every service principal is refused write on it.                                                                                                                                                                                 |
| Publish back to the producing context's exchange with the original key | **403.** A consumer holds `read` on a foreign exchange, never `write`. A consumer principal's write grant covers its own context and the audit feed — `^(acme\.communication(\..\*)? \| acme\.audit-feed(\..\*)? \| <service>-service\..\*)$` — and the producing context is not in it.                                                              |
| Use the admin principal                                                | Works, but violates least privilege, requires handling the admin credential, and — decisively — **no single service principal can both read a service's retention queue and write the producing context's exchange**, so an admin is the only credential that can do both, and using one makes the operation unauditable against a service identity. |
| The documented `rabbitmqadmin get` piped into `rabbitmqadmin publish`  | Fails for three reasons: it needs admin credentials; it needs the _original_ routing key, which the retained copy no longer carries (the queue rewrote it to `dead-letter`); and the get-then-publish shell ordering removes the message before the republish is known to have succeeded.                                                            |

The way through is to stay entirely inside the service's own grants. Every service principal may
`configure`, `write` and `read` within its own `<service>-service.*` namespace. So: declare a
temporary exchange in that namespace, bind the service's own events queue to it, drain the
retention queue through it, and tear it down. Nothing outside the service's existing permissions is
touched, no permission change is deployed, and no admin credential is used.

The other enabler is dispatch style. The notification consumer resolves its handler from
`ROUTING_KEYS[event.eventType]` — a lookup on the **message body**, not the AMQP routing key. A
message re-injected through any exchange with any key therefore reaches the correct handler. That
is not universally true: the commission consumer dispatches on the routing key, because that is how
it distinguishes v1 from v2 `deal.locked`. **Check the target consumer's dispatch style before
replaying.** For a routing-key-driven consumer, the original key must be recovered from the
`x-death` headers and used as the republish key.

```mermaid
sequenceDiagram
  autonumber
  participant OP as Operator, inside the service pod
  participant TMP as Temporary direct exchange in the service namespace
  participant Q as The service events queue
  participant DLQ as The retention queue
  participant C as The running consumer

  OP->>TMP: assertExchange direct, durable false
  OP->>Q: bindQueue to TMP with key reprocess
  loop until basic.get returns nothing
    OP->>DLQ: basic.get with noAck false
    DLQ-->>OP: message plus x-death headers
    OP->>OP: strip x-death, x-first-death, x-last-death, x-delivery-count
    OP->>TMP: publish on a CONFIRM channel
    TMP->>Q: routed by the reprocess binding
    OP->>OP: waitForConfirms
    OP->>DLQ: ack — only now
    Q->>C: delivered as a fresh message
  end
  OP->>Q: unbindQueue from TMP
  OP->>TMP: deleteExchange
```

The invariant the diagram encodes: **a message leaves the retention queue only after a
broker-confirmed copy exists somewhere else.** Reprocessing is copy-then-delete, never move.

### Runbook

1. **Confirm the fix is deployed and the artifact really contains it.** Replaying into an unfixed
   consumer re-fails every message and, worse, burns the `x-death` history that told you what
   originally happened. Verify the running image, not the tag — the historical DLQ incident was
   caused by an image whose tag implied code it did not contain.

2. **Count and sample first, non-destructively.** Run the loop below with `noAck: false` and
   _requeue_ rather than ack, so nothing is consumed:

   ```bash
   kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
     rabbitmqctl list_queues -p acme name messages | grep dlq
   ```

   Knowing the count in advance is what lets you tell a completed drain from a stalled one.

3. **Check idempotency before deciding to replay.** If the handler dedups on a natural key, some
   retained messages may already have been applied — the notification discovery handler counts
   existing deliveries by `(source_event_id, template_code)` and skips. Query the target table
   first. Where an operator retry endpoint exists for a single record, prefer it over a bulk drain.

4. **Check for token-bearing payloads.** If the retained messages are invite or reset events, do
   **not** replay them: their tokens may be expired or already consumed, and the correct recovery
   is to resend the invitation, which mints a fresh token. (These should not be in a retention
   queue at all — the consumer acks rather than dead-letters them — but a message dead-lettered
   before that guard shipped can still be sitting there.)

5. **Run from inside the service's own pod, using its own connection URI.** This is what keeps the
   operation inside the service's grants and out of admin credentials. The images are distroless,
   so there is no shell and no `printenv`; invoke the Node binary directly and read the URI from
   the process environment in-process. **Never print the URI or any part of it** — parse and redact
   in-process if you need to log anything.

6. **Declare the temporary exchange, and bind the events queue to it.** Both names must sit in the
   service's own `configure` namespace:

   ```js
   const EX = "notification-service.reprocess",
     RK = "reprocess",
     Q = "notification-service.identity.events",
     DLQ = "notification-service.identity.dlq";
   const c = await amqp.connect(process.env.RABBITMQ_URI);
   const ch = await c.createConfirmChannel(); // CONFIRM channel — publish-confirm before ack
   await ch.assertExchange(EX, "direct", { durable: false });
   await ch.bindQueue(Q, EX, RK);
   ```

   `direct` because there is exactly one route and no pattern matching is wanted. `durable: false`
   because the exchange must not outlive the operation — if the broker restarts mid-replay, the
   temporary topology disappears rather than becoming permanent drift.

7. **Drain, stripping the death headers.** The strip is what makes the message look fresh to any
   redelivery-count logic downstream; leaving them in can cause a broker or a consumer to treat a
   replayed message as an already-failing one:

   ```js
   for (;;) {
     const m = await ch.get(DLQ, { noAck: false });
     if (!m) break;
     const h = { ...(m.properties.headers || {}) };
     for (const k of Object.keys(h))
       if (/^x-(death|first-death|last-death|delivery-count)/.test(k))
         delete h[k];
     ch.publish(EX, RK, m.content, {
       contentType: "application/json",
       headers: h,
       persistent: true,
     });
     await ch.waitForConfirms();
     await ch.ack(m);
   }
   ```

   If the target consumer dispatches on the routing key rather than the body, read the original key
   out of `h['x-death'][0].routing_keys` **before** the strip and publish with that key instead of
   `RK`, binding the queue accordingly.

8. **Confirm before ack — this is the safety property, and the ordering is the whole point.**
   `waitForConfirms()` resolves only when the broker has accepted the republished copy. If the
   publish is refused (a permission the operator did not anticipate) or anything throws, the
   `basic.get` message was never acked, so the broker returns it to the retention queue. Zero loss
   on a failed replay. Reversing these two lines converts a safe operation into a lossy one.

9. **Tear down.** Leaving the temporary exchange bound means a future publish to it silently
   re-injects into the live queue:

   ```js
   await ch.unbindQueue(Q, EX, RK);
   await ch.deleteExchange(EX);
   ```

10. **Verify on three independent surfaces.** Broker: retention queue at zero _and_ events queue at
    zero, so the messages were consumed rather than merely moved. Database: the target rows reached
    their expected terminal state, with a count that matches the number replayed. Logs: one
    success line per message and none of the failure signatures — no tenant-filter errors, no
    global-entity-manager errors, no nacks.
    ```bash
    kubectl -n rabbitmq exec rabbitmq-0 -c rabbitmq -- \
      rabbitmqctl list_queues -p acme name messages | grep -E 'notification-service'
    ```

### When not to replay

Discard rather than replay when the cause was a **producer** defect — the payload is malformed and
replaying reproduces the failure exactly, so the correct recovery is to re-emit from source state
after fixing the producer. Discard when the message carries a credential (step 4). Discard when the
event is superseded — replaying a stale event into a timestamp-guarded projection is a no-op at
best, and into a state-guarded handler produces a parked row. And do not replay into a consumer
that has no inbox and no per-effect unique key without first confirming, per message, that the
effect has not already been applied by another path.

---

## The detection substrate

Nearly every sheet above names a signal and then qualifies it. This table collects the
qualifications in one place, because "the alert exists" and "the alert fires" are different claims
and the difference is the difference between an incident found in five minutes and one found in
five weeks.

| Signal                                                 | Kind          | Evaluation path | Notes                                                                                                                                  |
| ------------------------------------------------------ | ------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Service logs (connect, reconnect, nack, stuck, reaper) | log           | log store       | The most reliable layer. Every failure in this atlas has a log line.                                                                   |
| `GET /health/ready` with `checks.rabbitmq`             | probe         | kubelet         | Connection state only. Says nothing about channels, consumers or the relay.                                                            |
| `GET /health/live`                                     | probe         | kubelet         | Always 200 by design. Never restarts a pod out of a messaging failure.                                                                 |
| Blackbox `probe_success{probe_class="service-health"}` | alert         | reconciled      | External to the pod's own signals, which is why it survives a pod that is lying about itself.                                          |
| Dashboard-provisioned DLQ depth rule                   | alert         | reconciled      | Warning, depth `> 0` for 5 min, on `rabbitmq_detailed_queue_messages`. Correct metric name — the obvious one carries no `queue` label. |
| Dashboard-provisioned queue depth rule                 | alert         | reconciled      | Same scrape path, non-DLQ queues.                                                                                                      |
| Outbox-lag, parked-message, DLQ and redelivery rules   | alert         | operator format | Reconciled only where a deploy generator references the rules directory _and_ an operator turns it into something that runs.           |
| `outbox_relay_stuck_publishing_total`                  | metric        | emitted         | Emitting is not evaluating.                                                                                                            |
| `acme_inventory_consumer_redeliveries_total`           | metric        | emitted         | As above.                                                                                                                              |
| `acme_trading_outbox_lag_seconds`                      | metric        | emitted         | Shared-outbox scope under a single service's label — see Sheet 8.                                                                      |
| Broker `ServiceMonitor`                                | scrape config | operator format | Needs a Prometheus Operator; a collector-based scraper is the alternative path.                                                        |
| `consumers = 0` on a queue                             | broker state  | manual only     | The only signal that catches a consumer that stopped without dying, and nothing above the broker looks there.                          |

Two structural observations follow. First, the log layer is complete and the metric layer is not:
every failure mode in this atlas produces a log line, and roughly half produce a metric that no
rule reads. Second, alert-rule sprawl across two systems — dashboard-provisioned rules and
operator-format rules, reconciled by different machinery — means an alert can be authored,
reviewed, merged and believed in without ever being evaluated. When adding a detector, the question
to ask is not "did the rule land on main" but "which evaluation path is it on, and is that path
reconciled".

---

## Where this connects

**Survey docs this sits below.** [`backend/05-messaging.md`](../../backend/05-messaging.md) gives
the broker topology, the naming grammar, the message lifecycle and the credential model, and its
§11 records six verified drift items — several of which this document develops into full failure
modes (the version-mismatch envelopes that never reach retention become Sheets 5 and 7; the
`enableRelay` count becomes the shared-outbox hazard in Sheet 3).
[`platform/integration-patterns.md`](../../platform/integration-patterns.md) §1–2 establish the
transactional outbox and the inbox/parked-message conventions that Sheets 3, 4 and 8 assume, and
its §5 gives the dead-letter and reprocess shape that this document's replay runbook expands into
per-step reasoning. [`platform/event-catalog.md`](../../platform/event-catalog.md) is the reference
for the envelope, the routing grammar and versioned routing keys — read its §5 before Sheet 9.

**Sibling deep-dives.** [`03-consuming.md`](./03-consuming.md) is the mirror of this document on
the healthy path: it catalogues the thirteen consumer classes and their four reconnect tiers, which
Sheets 1 and 6 use as a given, and develops the inbox and forked-entity-manager mechanics that
Sheet 3 relies on. [`01-topology.md`](./01-topology.md) is the exchange, queue, binding and
credential inventory these sheets assume; [`02-publishing.md`](./02-publishing.md) is the
outbox-relay path in the healthy case, which Sheets 3 and 8 break;
[`05-testing-the-broker.md`](./05-testing-the-broker.md) is what does and does not get proved about
any of it before a merge. The neighbouring sets are the event-design series
([`../events/01-event-anatomy.md`](../events/01-event-anatomy.md) onwards) and the multi-tenancy
series, where the fail-closed tenant filter that forces `{ filters: { tenant: false } }` on every
relay, reaper and inbox query is developed properly
([`01-tenant-model.md`](../multi-tenancy/01-tenant-model.md),
[`02-resolution.md`](../multi-tenancy/02-resolution.md)).

**Decisions cited here.**

| Decision                                                                | Used in                            |
| ----------------------------------------------------------------------- | ---------------------------------- |
| Per-bounded-context schemas inside one shared database instance         | Ground truth, Sheet 3              |
| A single broker as the unified inter-service messaging substrate        | Ground truth, Sheets 5 and 7       |
| Database instance hardening, including the advisory-lock id allocations | Sheet 3, Sheet 8                   |
| A fanout audit feed that every producer dual-publishes to               | Sheet 3 (dual-publish), Sheet 5    |
| Bounded-context-aligned bundles as the unit of deploy                   | Sheet 3 (where lock ids come from) |
| Versioned routing keys with a dual-publish transition window            | Sheets 3, 5 and 9                  |
| The AI signal event taxonomy                                            | Sheet 9                            |
| Inbox, idempotency-key and parked-message stores as per-service tables  | Sheets 3, 4 and 5                  |

**Documented contradictions between source and source.** Recorded here rather than silently
reconciled, because each one has cost someone time. The messaging decision record specifies
TTL-based exponential retry before dead-lettering and a `dlq.{service}.{purpose}` naming scheme;
the code has neither — every nack goes straight to a dead-letter exchange and the naming is
`<owner>.<context>.dlq`. The versioned-routing decision writes routing keys with the exchange
prefix included (`acme.trading.deal.locked`); the code uses the bare event type as the routing key,
and that decision is still marked `Proposed` while its enforcement is fully implemented in the
relay. One handler cites a decision-record number for the inbox convention that in fact belongs to
an unrelated TLS decision — two adjacent numbers, one transposed in a comment nobody checked — and
elsewhere two unrelated decisions share a number outright. A relay-enabled service's code comment
states that another service's relay polls a different database, which the infrastructure module
contradicts in its own variable documentation. And a set of per-service `outboxAdvisoryLockId`
values carefully reconciled in one values file is not what reaches the pods for half the services,
because a second file, read in preference to it, was maintained independently.
