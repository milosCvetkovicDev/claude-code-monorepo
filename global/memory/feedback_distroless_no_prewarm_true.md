---
name: distroless-no-prewarm-true
description: "Distroless container images ship without coreutils — `command: [\"true\"]` crashes with `executable file not found in $PATH`"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

The ARC cache-warmer DaemonSet uses `command: ["true"]` for every pre-warm initContainer (the kubelet pulls the image to start the container, then `true` exits 0 so the side effect is to populate the node's image cache). This works for any image with coreutils (postgres, rabbitmq, debian-based node, etc.). It does NOT work for distroless — distroless images intentionally omit `/usr/bin/true` along with the rest of coreutils:

> exec: "true": executable file not found in $PATH: unknown

**Why:** 2026-05-24 the cache-warmer pod was in CrashLoopBackOff with 383 restarts in 32 h because `gcr.io/distroless/nodejs22-debian12` was in `preWarm.images` despite the template's own header comment saying distroless shouldn't be in the list. PR #908 removed it and added an explicit "NEVER add distroless here" comment to both `charts/arc/values.yaml` and `charts/values/arc.yaml`.

**How to apply:** Never add distroless images to `preWarm.images`. If pre-warming distroless is needed, change `charts/arc/templates/cache-warmer-daemonset.yaml` to per-image command tuples first (e.g. for distroless nodejs, use `["/nodejs/bin/node", "-e", ""]`). This pattern also applies to any other "pull a thing and exit immediately" container that uses a generic command — confirm the command exists in the target image.
