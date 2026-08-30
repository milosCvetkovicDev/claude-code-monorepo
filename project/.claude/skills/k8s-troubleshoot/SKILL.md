# Kubernetes Troubleshoot

Debug Kubernetes issues for Platform services running on AKS.

## Arguments

`$ARGUMENTS` — optional: service name, namespace, or pod name. If empty, shows overview of all platform namespaces.

## Step 1: Namespace Overview

```bash
# List all platform namespaces and pod status
kubectl get pods -A -l app.kubernetes.io/part-of=platform --no-headers 2>/dev/null | \
  awk '{print $1, $2, $4, $5}' | column -t

# Or specific namespace
kubectl get pods -n platform-{bc} -o wide
```

## Step 2: Pod Status Check

```bash
# Get pod details
kubectl get pods -n platform-{bc} -l app={service}

# Check for non-Running pods
kubectl get pods -n platform-{bc} --field-selector=status.phase!=Running
```

## Step 3: Diagnose Based on Status

### CrashLoopBackOff

```bash
# Check current logs
kubectl logs {pod} -n platform-{bc} --tail=50

# Check previous container (crashed version)
kubectl logs {pod} -n platform-{bc} --previous --tail=50

# Check events
kubectl describe pod {pod} -n platform-{bc} | grep -A20 "Events:"
```

### OOMKilled

```bash
# Check resource usage
kubectl top pod -n platform-{bc}

# Check limits
kubectl describe pod {pod} -n platform-{bc} | grep -A5 "Limits:"

# Fix: increase memory in charts/values/{service}.yaml
```

### ImagePullBackOff

```bash
# Check image reference
kubectl describe pod {pod} -n platform-{bc} | grep "Image:"

# Verify image exists in GHCR
# Check imagePullSecrets
kubectl get pod {pod} -n platform-{bc} -o jsonpath='{.spec.imagePullSecrets}'
```

### Init Container Stuck (Migration Failure)

```bash
# Check init container logs
kubectl logs {pod} -n platform-{bc} -c migrate

# Check init container status
kubectl describe pod {pod} -n platform-{bc} | grep -A10 "Init Containers:"
```

### Pending

```bash
# Check scheduling events
kubectl describe pod {pod} -n platform-{bc} | grep -A5 "Events:"

# Check node capacity
kubectl describe nodes | grep -A5 "Allocated resources"

# Check if node pool needs scaling
kubectl get nodes -o wide
```

### Readiness Probe Failing

```bash
# Check readiness endpoint
kubectl exec {pod} -n platform-{bc} -- curl -s http://localhost:3000/ready

# Check dependencies
kubectl exec {pod} -n platform-{bc} -- curl -s http://localhost:3000/health
```

## Step 4: Service Connectivity

```bash
# Check service endpoints
kubectl get endpoints -n platform-{bc} {service}

# Check ingress
kubectl get ingress -n platform-{bc}

# DNS resolution
kubectl exec {pod} -n platform-{bc} -- nslookup {other-service}.platform-{bc}.svc.cluster.local
```

## Step 5: ArgoCD Status

```bash
# Check sync status
argocd app get platform-{service}

# Check sync history
argocd app history platform-{service}

# Force sync if needed
argocd app sync platform-{service}

# Rollback to previous version
argocd app rollback platform-{service} {revision}
```

## Step 6: RabbitMQ Connectivity (if messaging issues)

```bash
# Check RabbitMQ from inside pod
kubectl exec {pod} -n platform-{bc} -- curl -s http://rabbitmq.platform-infra:15672/api/healthchecks/node

# Check queue depth
kubectl exec {pod} -n platform-infra -- rabbitmqadmin list queues name messages
```

## Step 7: Collect Diagnostic Bundle

```bash
# Events for namespace
kubectl get events -n platform-{bc} --sort-by=.lastTimestamp | tail -30

# Resource usage across namespace
kubectl top pods -n platform-{bc}

# All pod statuses
kubectl get pods -n platform-{bc} -o wide
```

## Quick Reference — Common Fixes

| Problem | Fix |
| ------------------- | ------------------------------------------------------- |
| OOMKilled | Increase `resources.limits.memory` in Helm values |
| CrashLoop on config | Check ConfigMap/Secret mounted correctly |
| Migration stuck | Fix migration SQL, delete pod to retry |
| Image not found | Check GHCR tag, verify CI pushed the image |
| No endpoints | Check service selector matches pod labels |
| Probe timeout | Increase `initialDelaySeconds` or fix `/ready` endpoint |
