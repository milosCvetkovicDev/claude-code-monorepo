# Implement Helm Chart

Create or update Helm chart values for a Platform service deployment to Kubernetes (AKS) via ArgoCD.

## Arguments

`$ARGUMENTS` — service name (e.g., `auth-service`, `gateway`, `tenant-service`)

## Step 1: Check Base Chart

Verify the base chart exists at `charts/acme-service/`:

```bash
ls charts/acme-service/Chart.yaml 2>/dev/null || echo "❌ Base chart missing — create it first"
```

## Step 2: Create Per-Service Values

File: `charts/values/{service}.yaml`

```yaml
replicaCount: 2

image:
  repository: ghcr.io/initech-trading-platform/acme/{service}
  tag: 'sha-latest' # Updated by CI

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 512Mi

livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 15
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5

initContainers:
  - name: migrate
    command: ['npx', 'mikro-orm', 'migration:up']

env:
  - name: NODE_ENV
    value: production
  - name: SERVICE_NAME
    value: { service }

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilization: 70
```

## Step 3: Create ArgoCD Application

If ApplicationSet doesn't exist, create Application CRD:

```yaml
# argocd/{service}.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-{service}
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: https://github.com/initech-trading-platform/acme
    path: charts/acme-service
    helm:
      valueFiles:
        - ../../values/{service}.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: platform-{bc}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Step 4: Create ExternalSecret

File: `charts/secrets/{service}-secrets.yaml`

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {service}-secrets
  namespace: platform-{bc}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-key-vault
    kind: ClusterSecretStore
  target:
    name: {service}-secrets
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: platform-{service}-database-url
```

## Step 5: Validate

```bash
helm lint charts/acme-service -f charts/values/{service}.yaml
helm template platform-{service} charts/acme-service -f charts/values/{service}.yaml
```

## Critical Rules

- NEVER use `latest` image tag — always SHA or semver
- NEVER put secrets in values.yaml — use ExternalSecret (ADR-0020)
- ALWAYS set resource requests AND limits
- ALWAYS include liveness + readiness probes
- ALWAYS include init container for services with DB migrations (ADR-0015)
