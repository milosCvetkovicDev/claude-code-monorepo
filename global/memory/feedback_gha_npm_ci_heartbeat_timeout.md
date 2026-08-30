---
name: gha-npm-ci-heartbeat-timeout
description: "GHA can kill long-silent ARC pods via stdout-silence heartbeat, AND can OOMKill pods when npm ci RSS exceeds the runner memory limit. The two failure modes LOOK IDENTICAL (step in_progress + log blob gone) but have different fixes — verify which before assuming."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

## TL;DR

Two distinct failure modes on ARC pods running `npm ci` look identical from the GitHub side:

1. **Stdout-silence heartbeat kill** — GHA runner self-reports unhealthy after ~10 min of zero stdout. Fix: emit heartbeat (background `echo` loop OR `npm ci --loglevel=http` on COLD cache).
2. **OOMKill by kubelet** — `npm ci` resident-set exceeds the runner pod's memory limit. Fix: bump memory limit OR shrink working set. NO log-level change helps.

**Always verify which mode you're in via `kubectl get events -A | grep OOMKilling` before iterating on a fix.** The original 2026-05-26 PR #939 diagnosis attributed three sequential failures to (1) — that was wrong; cause was (2). A heartbeat fix landed but did not unblock the PR.

## How to tell them apart

Both modes produce:
- Step `in_progress` at job-completion time, zero log content uploaded
- `gh api .../logs` returns `BlobNotFound`
- Job conclusion = `failure`
- `failures: {<uid>: true}` on the EphemeralRunner status

OOMKill ADDITIONALLY produces (and silence kill does NOT):
- `kubectl get events -A | grep OOMKilling` shows the node + the dying process name and RSS at kill time, e.g.:
  ```
  OOMKilling node/aks-arcpool-...
  Memory cgroup out of memory: Killed process N (npm ci)
  total-vm:3178060kB, anon-rss:1876068kB
  ```
- Pod restartCount may stay 0 if ARC recreates the pod with the same name (deterministic naming from EphemeralRunner CR); look at `kubectl get events --field-selector involvedObject.name=<pod>` instead.

Silence kill ADDITIONALLY produces:
- The runner kept printing heartbeat events to k8s pod log right up to the kill (visible via `kubectl logs --previous`).
- No OOMKilling event anywhere.

## What I had wrong on 2026-05-26

Original belief: "Moving from `arc-linux-x64` (6Gi) to `arc-linux-x64-large` (12Gi) did NOT change failure time → not OOM." False premise: the dev override in `charts/values/arc.yaml` forces ALL runner sizes (standard / large / builder) to `memLimit: 2Gi` on dev. The 6Gi and 12Gi chart defaults are PROD numbers; they never apply to dev. Switching size class on dev had no resource effect, so the falsification test had no signal.

PR #939 commits:
- `946da86b` `--loglevel=notice`: died at 11–12 min
- `92674279` `--loglevel=http`: died at 10m 55s
- `cf58d2cd` background heartbeat + pipefail: died at 13m 17s
All three actually OOMKilled. Survival time variance is RSS-growth-curve variance, not stdout heartbeat reaching the timeout.

## How to apply

For any `npm ci` (or `pnpm/yarn install`) on a self-hosted runner where install might take >5 min:

1. **First check resource limits** vs the workload's known RSS. Acme `npm ci` peaks at ~1.9 GiB on Node 22; 2 GiB pod limit is not enough. Use `kubectl top pod` during a live run or grep prior OOMKilling events.
2. **If pod has comfortable memory headroom**, then a silent npm ci IS the heartbeat-silence risk and either:
   - Background heartbeat side-process (works for any silent long-running command — preferred because it survives both cold AND warm cache):
     ```bash
     ( while true; do echo "heartbeat $(date -u +%T)"; sleep 60; done ) &
     HEARTBEAT_PID=$!
     trap "kill $HEARTBEAT_PID 2>/dev/null || true" EXIT
     npm ci --prefer-offline --no-audit --no-fund 2>&1 | tee /tmp/npm-ci.log
     ```
     (Use `set -o pipefail` if piping through tee — otherwise tee masks npm ci failures.)
   - Or `npm ci --loglevel=http` — emits one line per registry fetch on COLD cache. NOTE: silent on WARM cache because `--prefer-offline` serves tarballs locally without hitting the registry. Therefore not a durable fix.

## Acme-specific notes

- Dev `arc-runners` are hard-capped at `memLimit: 2 GiB` per `charts/values/arc.yaml` (ADR-0040 Amendment 1, single Standard_D2as_v7 node). Acme `npm ci` does not fit. Phase C ci-v2.yml validation on PR #939 is blocked on this until cluster gets larger nodes.
- Prod-sized runners default to `memLimit: 12 GiB` (large) / `8 GiB` (standard) — plenty of room.

[[feedback_arc_setup_workspace_subpath]] is a separate ARC-composite bug from the same PR #939 iteration cycle.
[[feedback_gha_pod_death_log_truncation]] explains why the log blob is gone for BOTH failure modes — orthogonal to which mode you're in.
