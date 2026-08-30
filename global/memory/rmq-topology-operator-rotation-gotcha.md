# RMQ topology-operator: rotation gotcha (Secret-cache gap)

**Verified end-to-end on 2026-05-15** during PR #767 rotation validation
on AKS dev-platform, operator image
`ghcr.io/rabbitmq/messaging-topology-operator:1.19.2`.

## What goes wrong

`messaging-topology-operator` does NOT re-reconcile a `User.rabbitmq.com`
when the content of its `importCredentialsSecret` changes. The User
spec is unchanged by a rotation (the reference name stays the same), so
the operator's `For(&topology.User{})` watch never fires; and there is
no companion watch on `Secret`. The broker keeps the OLD password until a
human kicks the controller.

Rotation flow stalls at the broker:

```
random_password.rmq_user[<svc>] -> Azure Key Vault -> ESO -> k8s Secret
                                                              |
                                                           STOPS HERE
                                                              v
                                                      operator never re-reads
                                                              v
                                                      broker keeps old pw
```

## How to force a reconcile (workarounds)

Either of:

1. Delete the User CRD; ArgoCD auto-recreates within ~30s on next sync;
   operator imports fresh Secret on the recreated User. Risk: brief drop
   of the user during the recreate window.

   ```bash
   kubectl -n platform-identity delete user.rabbitmq.com <svc>
   ```

2. Restart the operator pod; cache rebuild reads every referenced Secret
   at startup. Risk: affects every topology CRD reconciliation on the
   cluster.

   ```bash
   kubectl -n rabbitmq-system rollout restart deploy/messaging-topology-operator
   ```

3. **Direct re-push when (1) and (2) are blocked** (verified 2026-05-27):
   set the broker password straight to the Secret's current value. Use
   this when the operator can't be restarted (its new pod is `Pending` on
   the dev vCPU quota) AND delete-CR is risk-elevated (`platform-identity`
   ArgoCD app was `OutOfSync/Degraded`, so selfHeal recreate isn't
   trustworthy). Zero-gap, deterministic, convergent with declarative
   intent (sets broker == the operator's own `importCredentialsSecret`,
   so a later operator reconcile PUTs the same value — no drift).

   ```bash
   pw=$(kubectl get secret -n platform-identity platform-rmq-service-<svc> \
        -o jsonpath='{.data.password}' | base64 -d)
   kubectl exec -n rabbitmq rabbitmq-0 -c rabbitmq -- \
     rabbitmqctl change_password <svc>_user "$pw"
   ```

   Enumerate the stale set first (broker username is `<svc>_user`, NOT the
   User CR name `<svc>`):

   ```bash
   kubectl exec -n rabbitmq rabbitmq-0 -c rabbitmq -- \
     rabbitmqctl authenticate_user <svc>_user "$pw"   # fail = stale
   ```

## 2026-05-27: only the MANUALLY-provisioned users drift

On dev-platform, exactly 3 users were stale — `commission`, `document`,
`notification` — the #880 follow-up trio whose KV rmq passwords were set
by hand (`az keyvault secret set`), not minted by `random_password` in
the `platform-key-vault-secrets` TF module. The 9 TF-managed users all
authenticated fine. The manual set-and-reset is what desynced the broker
from the Secret; the gotcha then froze it there. **Auth fix ≠ service
recovery:** clearing the PLAIN-login 403 exposed a *second*, unrelated
403 — `configure access to exchange 'acme.trading' refused` — because
the shared consumer (`libs/platform/event-bus/src/lib/setup-rabbit-consumer.ts:60`)
does an **active** `assertExchange(sourceExchange)` on cross-BC exchanges
it only has `read` on (and whose owner service is down so they don't
exist). That's a code/design issue, tracked separately — not a rotation
problem.

## Upstream tracking

Filed 2026-05-15 as
[rabbitmq/messaging-topology-operator#1181](https://github.com/rabbitmq/messaging-topology-operator/issues/1181).
Original drafted body lives in `docs/follow-ups/upstream-rmq-operator-secret-watch.md`
for reference. Watch the upstream thread for maintainer feedback on the
proposed `Watches(&corev1.Secret{}, ...)` patch before opening any PR.

Proposed upstream fix is the standard controller-runtime cross-resource
watch pattern (~20 lines of Go): add a `Watches(&corev1.Secret{}, ...)`
to the `User` controller's `SetupWithManager` with an
`EnqueueRequestsFromMapFunc` that maps a changed Secret back to every
`User` referencing it via `spec.importCredentialsSecret.name`. Mirrors
cert-manager's `CertificateRequest` controller pattern in
`pkg/controller/certificaterequests/controller.go`.

## In-repo automation — DEFERRED to upstream

#772 closed 2026-05-15. Building a custom in-repo controller would be
the first Go service in this TypeScript monorepo, requires full Platform
PM ceremony, and adds non-trivial CI/chart/RBAC surface to mitigate a
gap upstream is best positioned to fix. At current dev-platform scale the
manual operator-pod-restart per rotation is acceptable.

Path forward: watch upstream `rabbitmq/messaging-topology-operator#1181`.
If maintainers land the `Watches(&corev1.Secret{}, ...)` patch in v1.20+,
bump the operator chart and the gap closes for free. Reopen tracking
(new issue) if upstream stalls beyond ~6 months OR rotation cadence
becomes high enough that the workaround is painful.

Design doc kept at `docs/follow-ups/in-repo-rmq-rotation-watcher-design.md`
as reference if this ever needs revisiting.
