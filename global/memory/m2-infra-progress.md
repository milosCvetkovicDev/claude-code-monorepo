---
name: m2-infra-session-progress
description: M2-INFRA milestone progress — AKS infrastructure provisioning session 2026-03-30
type: project
---

M2-INFRA AKS Infrastructure milestone — started and substantially completed 2026-03-30.

**Why:** Parallel Track B of the Platform program. Provisions production-like Kubernetes environment for the 5 NestJS services built in M1+M2.

**How to apply:** When continuing M2-INFRA work, reference the task files at `.claude/epics/aks-infrastructure/` and the design spec at `docs/superpowers/specs/2026-03-30-m2-infra-aks-infrastructure-design.md`.

## Live Azure Resources (development subscription)
- **AKS:** development-acme-aks (K8s v1.32.11, 2-3 nodes Standard_D4as_v5)
- **PG Flexible:** development-acme-platform-pg.postgres.database.azure.com (v16, B_Standard_B2ms)
- **Redis:** development-acme-platform-redis.redis.cache.windows.net (Basic C1, TLS)
- **Traefik:** Public IP 203.0.113.10 (LoadBalancer, ACME staging)
- **ArgoCD:** v3.3.6, admin password <ARGOCD_ADMIN_PASSWORD>, port-forward only
- **RabbitMQ:** Single node, raw manifest (Bitnami chart image broken on Docker Hub)
- **ESO:** v2.2.0, ClusterSecretStore azure-keyvault → development-acme-kv
- **Grafana stack:** Loki 6.55.0, Tempo 1.24.4, Mimir 6.0.6, OTel 0.147.1, Grafana 10.5.15

## Terraform
- Separate state: `infra/environments/development-platform/` with key `development-platform.terraform.tfstate`
- Subnets: AKS nodes 10.0.6.0/26, PG Flexible 10.0.7.0/28 (no overlap with domain-api 10.0.4.0/23)
- K8s version: 1.32 (not 1.30/1.31 — those are LTS-only requiring Premium tier)
- development `enable_aks_subnet = true` added to network module call
- terraform.tfvars created locally with gathered credentials (NOT committed)
- GHCR token issue: gh auth OAuth token (gho_) doesn't work for GHCR pulls — needs PAT (ghp_)

## Completed Tasks
- #252: TF modules (AKS, PG Flexible, Redis, development-platform root)
- #253: Network subnets
- #254: terraform apply — all resources live
- #255: ArgoCD + Image Updater bootstrap
- #256: Traefik, ESO, RabbitMQ
- #257: Grafana stack (Loki, Tempo, Mimir, OTel, Grafana)
- #260: CI/CD workflows (platform-build-push.yml, platform-deploy.yml, CI paths-ignore)

## Completed
- #259: K8s Secrets created in all 5 namespaces (direct kubectl, KV access denied locally)
- #258: ArgoCD ApplicationSet applied, Gateway running (2/2). Backend services have NestJS module wiring issues from M2.
- #260: CI/CD workflows created — deploy pipeline rewritten (2026-04):
  - **Deploy:** `kubectl patch application "platform-${svc}" -n argocd --type=merge` sets `spec.source.helm.parameters` (image.tag + environment). No git commits to trigger deploys.
  - **ApplicationSet:** `ignoreApplicationDifferences` prevents reconciliation from overwriting patched params.
  - **Rollback:** Same `kubectl patch` approach; show-history queries live cluster state.
  - **Audit:** GitHub Deployments API + workflow step summaries (replaced `deployments.log.json`).
  - **AppProject deny windows:** `manualSync: false` still allows manual emergency syncs.
  - **ArgoCD Image Updater:** Intentionally dormant — CI manages image tags directly.
- Docker images built (amd64) and pushed to GHCR for all 5 services

## Remaining
- #261: Production verification — Gateway passes, 4 backend services need M2 NestJS module wiring fixes
- Backend services crash due to M2 code issues (NOT infrastructure):
  - tenant-service: in-memory stubs not resolving (ITenantRepository)
  - user-service: IUserRepository not provided
  - auth-service: AuthEventPublisher needs EntityManager (no MikroORM configured)
  - trading-service: MikroOrmBaseModule export wiring issue

## Gotchas Discovered
- K8s 1.29-1.31 are LTS-only on AKS (require Premium tier) — use 1.32+
- Bitnami RabbitMQ Docker Hub images are broken (not found) — used raw manifest with official `rabbitmq:3-management-alpine` image
- PG Flexible Server requires `public_network_access_enabled = false` when using VNet integration
- Azure RBAC on AKS needs `kubelogin` + `Azure Kubernetes Service RBAC Cluster Admin` role assignment
- AKS admin credentials (`--admin` flag) bypass Azure RBAC — used for bootstrap
- Grafana alert rules can't be inlined in Helm values (tpl() conflicts with Grafana template syntax)
- Mimir single-binary mode doesn't work cleanly in v6 — used minimal distributed mode instead
