---
name: feedback-docker-default-shell-dash
description: Docker RUN uses /bin/sh (dash on Ubuntu/Debian/noble), NOT bash. `set -o pipefail` fails with `Illegal option -o pipefail`. Use `set -eu` (no pipefail) or switch shell explicitly via SHELL directive.
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

Docker's default shell for `RUN <cmd>` is `/bin/sh`, which on Ubuntu/Debian/noble bases is dash, NOT bash. Dash does NOT support `-o pipefail`. PR #863 CI build failed in production with:

```
/bin/sh: 1: set: Illegal option -o pipefail
```

**Why:** I added `set -euo pipefail` to a sanity-check RUN after a tech-lead review noted that `az --version | head -1` was swallowing failures (`head` exits 0 on empty stream, masking missing `az`). The real fix for that finding was DROPPING the pipe — not adding pipefail. After dropping the pipe, the heredoc no longer has any pipes, so pipefail is pointless AND breaks portability.

**How to apply:**

When the RUN has no pipes:

```dockerfile
RUN set -eu && \
    cmd1 && \
    cmd2 && \
    cmd3
```

When the RUN genuinely needs pipefail, switch to bash via SHELL directive at the top of the Dockerfile:

```dockerfile
SHELL ["/bin/bash", "-c"]
RUN set -euo pipefail && \
    cmd1 | grep -q foo && \
    cmd2
```

Or use `bash -c` inline:

```dockerfile
RUN bash -c 'set -euo pipefail && cmd1 | grep foo && cmd2'
```

**Anti-pattern to avoid:** Don't reflexively add `pipefail` just because shell scripts in CI do. Verify there's an actual pipe that needs it; otherwise it's a portability footgun.

Fixed in: PR #863 commit `f59f2fd6` (drop pipefail, retain `set -eu`).
