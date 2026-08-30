---
name: bash-set-e-in-if-condition
description: "`set -e` does NOT trip on test failures inside `if` conditions — bash arithmetic compare on an empty/malformed variable silently falls through to the success path"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

`set -euo pipefail` does NOT cause the shell to exit on command failures that appear as the CONDITION of an `if`, `while`, `until`, `||`, or `&&`. This is documented bash behavior, not a bug. The combination most likely to bite in CI scripts is `[ "$X" -lt N ]` when `$X` is empty or non-numeric:

```bash
set -euo pipefail
COUNT=""  # e.g. wrong JMESPath, null field, command exited 0 but stdout was empty
if [ "$COUNT" -lt 1 ]; then  # emits "integer expression expected" to stderr
  echo "::error::degraded"   # NEVER reached
  exit 1
fi
echo "healthy"               # FALLS THROUGH to here, script exits 0
```

**Why:** 2026-05-25 PR #918 round-2 review caught this exact pattern in `.github/workflows/platform-runner-health.yml` — `NODE_COUNT=$(az aks nodepool show --query 'count' -o tsv)`; if the query succeeded but returned empty (wrong JMESPath, null field, az CLI version mismatch), the workflow would silently report "arc-pool healthy" while arc-pool was actually broken. A reliability monitor that silently passes when broken is worse than no monitor.

**How to apply:** ALWAYS add an explicit `[ -z "${VAR:-}" ]` guard BEFORE any arithmetic or string comparison on a variable captured from an external command. Pattern:

```bash
if [ -z "${COUNT:-}" ]; then
  echo "::error::COUNT query returned empty — check JMESPath / API version"
  exit 1
fi
if [ "$COUNT" -lt 1 ]; then
  echo "::error::degraded"
  exit 1
fi
```

Applies to: any `if [ "$X" <op> ... ]` where `$X` came from `$(cmd)` substitution. Especially common with `az`/`kubectl`/`gh`/`jq` queries that can return empty strings on edge cases.
