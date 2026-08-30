---
name: arc-setup-workspace-subpath
description: "`mountpoint -q /cache` always returns false on ARC pods because the chart mounts /cache/npm + /cache/nx via subPath — /cache itself is a regular kubelet-created directory, not a mountpoint. Check children."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

When a K8s pod mounts the same PVC twice at different paths via `subPath`, kubelet creates the PARENT directory as a regular dir (just `mkdir -p`) and bind-mounts only the children. `mountpoint -q <parent>` always returns false; only the children are real mountpoints.

The acme ARC chart (`charts/arc/templates/runner-scale-set-arc-linux-x64.yaml`) mounts `arc-shared-cache` PVC into the runner pod via:

```yaml
volumeMounts:
  - name: shared-cache
    mountPath: /cache/npm
    subPath: npm
  - name: shared-cache
    mountPath: /cache/nx
    subPath: nx
```

So `/cache` is a regular directory; `/cache/npm` and `/cache/nx` are the mountpoints.

**Why:** 2026-05-26 the original `arc-setup-workspace` composite (`.github/actions/arc-setup-workspace/action.yml`) checked `mountpoint -q /cache` to enforce that the composite only runs on ARC pods with the Azure Files PV bound. The check always failed live on PR #939's chore/phase-c-ci-v2 branch (commit `32d0d5f0` was the first fix). No production workflow had exercised `arc-setup-workspace` end-to-end before that PR, so the bug survived the chart-and-composite review board.

**How to apply:** When using subPath mounts in K8s + writing a workspace setup script that fails fast on missing mount, loop over the actual mountpoint children, not the parent:

```bash
for mp in /cache/npm /cache/nx; do
  if ! mountpoint -q "$mp"; then
    echo "::error::$mp is not a mountpoint — Azure Files PV subpath not bound"
    exit 1
  fi
done
```

Generalisable rule: **`mountpoint -q` targets must match the kubelet's `mountPath`, not a logical parent**. If the chart uses `subPath`, the parent is never a mountpoint.

[[feedback_gha_npm_ci_heartbeat_timeout]] caught the next bug down the chain (npm ci silently running for 10+ min and the pod dying to heartbeat timeout).
