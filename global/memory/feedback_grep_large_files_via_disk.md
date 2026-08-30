---
name: grep-large-files-via-disk-not-shell-variable
description: Storing a large file in a shell variable truncates it silently — always pipe to disk before grep'ing
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000050
---
When verifying a deployed JS bundle (or any file >~1 MB), **never** load it into a shell variable and then grep it. The variable is silently truncated and grep returns 0 hits even when the strings are present.

**Why:** During cancel-receipted-purchase dev verification (2026-04-30), I curl'd the legacy-web bundle (~1.7 MB) into `BUNDLE=$(curl ...)` and grep'd the variable for `PurchaseCancellationAudit`, `cancelledBy`, etc. Got 0 hits across 7 different tokens. Concluded the feature wasn't deployed and re-triggered the workflow. The bundle WAS correct — saving to `/tmp/bundle.js` first and grep'ing the file showed 7 hits for `Receipted`, 4 for `cancelledBy`, etc. The shell-variable approach had truncated the bundle.

**How to apply:** Bundle/file verification pattern:

```bash
# WRONG — silently truncates on macOS bash/zsh for >1 MB content
BUNDLE=$(curl -sL "$URL/$JS_FILE")
echo "$BUNDLE" | grep -c "myToken"   # returns 0 even when present

# RIGHT
curl -sL "$URL/$JS_FILE" > /tmp/bundle.js
grep -c "myToken" /tmp/bundle.js
```

Same applies to any large output: artefact JSON, log dumps, OpenAPI specs over a few hundred KB. **If the size matters, the file matters.**
