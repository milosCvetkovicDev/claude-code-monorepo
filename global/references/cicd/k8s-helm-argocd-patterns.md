# Kubernetes, Helm & ArgoCD Patterns — Acme

VERIFIED patterns from the acme repository. Use ONLY these patterns when working with K8s, Helm, or ArgoCD configs.

## Architecture Overview

- **AKS** (Azure Kubernetes Service) — managed K8s cluster
- **Helm** — platform-base shared chart for all 10 services
- **ArgoCD** — GitOps deployment, automated sync from main branch
- **ArgoCD Image Updater** — auto-tracks new image tags from ACR
- **ESO** (External Secrets Operator) — syncs Azure Key Vault → K8s Secrets
- **Traefik** — ingress controller (only gateway is externally exposed)

## Service Registry

`charts/services.yaml` is the **single source of truth** for all Platform services:

| Service | Namespace | Port | BC | SyncWave | DB | RabbitMQ |
|---------|-----------|------|-----|----------|-----|----------|
| gateway | platform-gateway | 3000 | gateway | 0 | No | No |
| auth-service | platform-auth | 3001 | auth | 0 | Yes | Yes |
| tenant-service | platform-platform | 3002 | platform | 1 | Yes | Yes |
| user-service | platform-identity | 3003 | identity | 1 | Yes | Yes |
| trading-service | platform-trading | 3005 | trading | 1 | Yes | Yes |
| inventory-service | platform-inventory | 3006 | inventory | 1 | Yes | Yes |
| accounting-service | platform-accounting | 3010 | accounting | 2 | Yes | Yes |
| commission-service | platform-commission | 3012 | commission | 2 | Yes | Yes |
| notification-service | platform-notification | 3020 | notification | 2 | Yes | Yes |
| document-service | platform-document | 3021 | document | 2 | Yes | Yes |

**SyncWave ordering**: 0 = core infra first, 1 = platform services, 2 = domain services.

## Helm Chart Structure

```
charts/
├── platform-base/             # Shared base chart for ALL services
│   ├── Chart.yaml          # apiVersion: v2, version: 0.1.0
│   ├── values.yaml         # Default values (security, probes, HPA, etc.)
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml    # Traefik IngressRoute
│       ├── hpa.yaml        # HorizontalPodAutoscaler
│       ├── pdb.yaml        # PodDisruptionBudget
│       ├── networkpolicy.yaml
│       ├── external-secret.yaml  # ESO SecretStore
│       ├── limitrange.yaml
│       └── resourcequota.yaml
├── values/                 # Per-service value overrides
│   ├── gateway.yaml
│   ├── auth-service.yaml
│   ├── tenant-service.yaml
│   └── ... (one per service)
├── overlays/               # Per-environment overrides
│   ├── dev/
│   │   ├── common.yaml     # Dev-wide settings
│   │   └── gateway.yaml    # Dev gateway-specific
│   └── prod/
│       ├── common.yaml
│       └── gateway.yaml
├── argocd/
│   ├── applicationset.yaml # Generates ArgoCD apps from service list
│   ├── appproject.yaml
│   └── notifications.yaml
├── infrastructure/         # Infra Helm values (ArgoCD, Traefik, Grafana, etc.)
└── services.yaml           # Service registry (single source of truth)
```

## Default Values (platform-base/values.yaml)

Key defaults that apply to ALL services unless overridden:

```yaml
replicaCount: 2
image:
  repository: developmentacmeacr.azurecr.io
  tag: ''           # Set by CI/ArgoCD Image Updater
  pullPolicy: Always

# PSS Restricted security context (UID 65534 = distroless nonroot)
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  runAsGroup: 65534
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ['ALL']
  seccompProfile:
    type: RuntimeDefault

# 3-probe health check strategy
probes:
  startup:
    path: /health
    initialDelaySeconds: 5
    periodSeconds: 5
    failureThreshold: 10
  liveness:
    path: /health/live
    periodSeconds: 10
    failureThreshold: 3
  readiness:
    path: /health/ready
    periodSeconds: 5
    failureThreshold: 3

# HPA
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Resource defaults
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Node scheduling
nodeSelector:
  workload: platform
```

## Per-Service Override Pattern

Each service has a `charts/values/{service}.yaml` that overrides only what differs:

```yaml
# Example: gateway.yaml
nameOverride: gateway
bc: gateway

image:
  repository: developmentacmeacr.azurecr.io/gateway

service:
  port: 3000

migrations:
  enabled: false  # Gateway has no DB

resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    cpu: 250m
    memory: 256Mi

# ESO secrets
externalSecret:
  enabled: true
  targetName: gateway-secrets
  data:
    - secretKey: jwt-secret
      remoteRef:
        key: platform-gateway-jwt-secret

# Cross-namespace service URLs (FQDNs)
env:
  - name: AUTH_SERVICE_URL
    value: 'http://auth-service.platform-auth.svc.cluster.local:3001'
  # ... etc
```

## Cross-Namespace Communication

Services in different namespaces MUST use FQDNs:
```
http://{service}.{namespace}.svc.cluster.local:{port}
```

Example: `http://auth-service.platform-auth.svc.cluster.local:3001`

**NEVER use short names** (`http://auth-service:3001`) across namespaces — they won't resolve.

## ArgoCD ApplicationSet

`charts/argocd/applicationset.yaml` generates one ArgoCD Application per service.

**Critical**: `ignoreApplicationDifferences` prevents the ApplicationSet controller from
overwriting helm parameters patched by CI (image.tag). Without this, the controller resets
parameters to template defaults every ~3 minutes.

```yaml
spec:
  ignoreApplicationDifferences:
    - jsonPointers:
        - /spec/source/helm/parameters
  generators:
    - list:
        elements: [...]  # 10 services
  template:
    spec:
      source:
        repoURL: https://github.com/initech-trading-platform/acme.git
        targetRevision: main
        path: charts/platform-base
        helm:
          ignoreMissingValueFiles: false  # Fail loudly on missing overlays
          valueFiles:
            - '../../{{.valuesFile}}'                          # Per-service values
            - '../../charts/overlays/{{.environment}}/common.yaml'  # Env-wide
            - '../../charts/overlays/{{.environment}}/{{.name}}.yaml' # Env+service
          parameters:
            - name: environment
              value: '{{.environment}}'
            - name: image.tag
              value: 'latest'  # Bootstrap default — CI sets real tag via kubectl patch
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=false
          - ApplyOutOfSyncOnly=true
```

## Deployment Template Guards

The deployment template has FAIL guards:

```yaml
# Guard 1: DB services MUST have migrations enabled
{{- if and .Values.hasDB (not .Values.migrations.enabled) }}
{{- fail "hasDB=true requires migrations.enabled=true — refusing to deploy without migration strategy" }}
{{- end }}

# Guard 2: Image tag MUST be set
{{- if not (or .Values.image.tag .Chart.AppVersion) }}
{{- fail "image.tag or Chart.AppVersion must be set — refusing to deploy without an image tag" }}
{{- end }}
```

## Migration Init Container

Services with `hasDB: true` run migrations via init container:

```yaml
initContainers:
  - name: migrations
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
    command: ["/nodejs/bin/node", "node_modules/@acme/service-bootstrap/src/lib/migrate-cli.js"]
```

## Graceful Shutdown

```yaml
# preStop hook: 5s delay for connection draining
lifecycle:
  preStop:
    exec:
      command: ["/nodejs/bin/node", "--eval", "setTimeout(() => {}, 5000)"]
terminationGracePeriodSeconds: 30
```

## Adding a New Service

1. Add entry to `charts/services.yaml`
2. Create `charts/values/{service}.yaml` with overrides
3. Add entry to `charts/argocd/applicationset.yaml` generators list
4. Add Docker build matrix entry in `.github/workflows/platform-build-push.yml`
5. Create environment overlay if needed: `charts/overlays/{env}/{service}.yaml`
6. Run: `bash scripts/platform/validate-deployment.sh`

## Security Hardening (Phase 1-3, implemented 2026-04-09)

These are NOW active in the codebase:

- **Egress NetworkPolicies**: Per-service egress rules in `values/{service}.yaml` via `egressPolicy.extraEgress`
- **automountServiceAccountToken: false**: All pods, configured in `values.yaml`
- **Traefik Middlewares**: Rate limiting (1000 req/s), security headers (HSTS, X-Frame, CSP), compression — all in separate template files
- **Per-namespace SecretStores**: ESO uses `SecretStore` (not ClusterSecretStore), needs `vaultUrl` per service
- **DB readiness wait**: Init container uses TCP probe before migrations run
- **ResourceQuota + LimitRange**: Enabled in `charts/overlays/prod/common.yaml`
- **ArgoCD HA**: 2 replicas for server/repoServer/controller, notifications enabled
- **ignoreMissingValueFiles: false**: ArgoCD fails loudly on missing overlays (intentional — prevents silent misconfig)
- **RabbitMQ HA**: 3-node cluster, quorum queues, 20Gi persistence
- **Observability**: 30-day retention, 10% trace sampling, increased OTel collector resources

## Common Mistakes to Avoid

1. **NEVER commit image tags to main** — CI sets tags via `kubectl patch` on ArgoCD Application CRDs
2. **NEVER use short service names across namespaces** — must use FQDNs
3. **NEVER set `CreateNamespace=true`** in syncPolicy — namespaces are pre-provisioned
4. **NEVER skip the hasDB/migrations guard** — it prevents data loss
5. **NEVER set `readOnlyRootFilesystem: false`** — PSS Restricted requires it
6. **NEVER use `allowPrivilegeEscalation: true`** — security violation
7. **NEVER put secrets in values files** — use ESO (External Secrets Operator)
8. **When adding a service**: update ALL of services.yaml, values file, applicationset, build matrix
9. **Overlays are layered**: base values → service values → env common → env+service
10. **`helm template` locally to verify** before pushing chart changes
