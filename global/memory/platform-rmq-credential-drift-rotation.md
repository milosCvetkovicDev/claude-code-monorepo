---
name: platform-rmq-credential-drift-rotation
description: "Platform RMQ per-service credentials — two-KV-secret structure, how they drift to 403, and the purge-safe rotation recovery"
metadata: 
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000008
---

Platform per-service RabbitMQ auth (dev-platform), learned resolving the #983 mid-deploy 403 incident 2026-06-06.

**Structure (per service, from `infra/modules/platform-key-vault-secrets`):** TWO KV secrets,
both derived from ONE `random_password.rmq_user[svc]`:
- `platform-<svc>-rabbitmq-uri` → full `amqp://<svc>_user:<pw>@rabbitmq.rabbitmq.svc.cluster.local:5672/acme` → ESO projects to `<svc>-secrets:rabbitmq-uri` → **the POD** connects with this.
- `platform-<svc>-rabbitmq-password` → raw pw → ESO projects to `platform-rmq-service-<svc>:password` (ns `platform-identity`) → the **topology-operator** sets the **broker** user password from this.
- **Broker username is `<svc>_user`** (e.g. `commission_user`), NOT the User-CR name (`commission`). vhost `acme`.
- Both KV-secret resources have `lifecycle { ignore_changes = [value] }` → **Terraform never reconciles their values after creation** (apply won't fix drift; only create sets value).

**Failure mode:** if the two KV secrets carry different passwords (e.g. `random_password`
dropped from TF state — see #1154 / [[platform-dlq-not-deployed-stale-artifact]]), pod-uri-pw ≠
broker-pw → `Handshake terminated by server: 403 (ACCESS-REFUSED) … PLAIN`. Stays LATENT for
days because running pods hold cached AMQP connections; a redeploy/restart forces fresh auth
and exposes it. **Rollback does NOT help** (old-image pod reconnects fresh, fails identically).

**Recovery (purge-safe rotation — `development-acme-kv` has `purgeProtection:true`, so
delete+recreate is BLOCKED — a soft-deleted name can't be purged or re-created for the
retention window):**
1. (USER runs — credential write is classifier-blocked for the agent) for each svc generate ONE pw, `az keyvault secret set` BOTH `-password`(raw) and `-uri`(amqp URI w/ `<svc>_user`) consistently. `secret set` = upsert/new-version, no delete.
2. force-sync BOTH ESes: `kubectl annotate externalsecret <svc>-secrets -n <bundle-ns> force-sync=$(date +%s) --overwrite` AND `platform-rmq-service-<svc>` -n platform-identity. Confirm secret resourceVersion bumps.
3. re-sync broker user: `kubectl delete user.rabbitmq.com <svc> -n platform-identity` (ArgoCD `platform-identity` selfHeal recreates; operator pushes the NEW pw) — patch `argocd.argoproj.io/refresh=hard` on the app to recreate immediately.
4. `kubectl delete pod -n <bundle-ns> -l app.kubernetes.io/name=<svc>-service` (env injected at pod creation — must restart to pick up new uri).
5. verify: pod log `RabbitMQ connected (attempt 1/5)` + `Nest application successfully started`.

**Gotchas:** topology-operator does NOT re-push on secret-content change — rotation REQUIRES
deleting the User CR (rotation gotcha, also in [[rmq-topology-operator-rotation-gotcha]]).
`User CR Ready=True` is stale (reflects last create, not broker↔secret sync). zsh: `for x in
$VAR` does NOT word-split (use indexed arrays or `${=VAR}`); `declare -A` unsupported.
