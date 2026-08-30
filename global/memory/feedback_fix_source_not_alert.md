---
name: fix-source-not-alert
description: When an alert fires on expected/by-design behavior, fix the system to stop emitting the error signal — do not silence the alert.
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000012
---
When an alert fires and investigation confirms the underlying behavior is working as designed (e.g. an HTTP 422 returned for an input the system is deliberately configured to skip), the preferred fix is to change the code so the error signal is never emitted — return a success no-op carrying a discriminant (e.g. `reason: '<why-it-was-skipped>'`) so operators can tell "skipped" apart from "ran and produced zero".

Do NOT suppress the alert with a KQL filter or disable it. Keeping alerts honest (firing = real problem) is more valuable than the minor code change cost.

**Why:** Settled on a live P1 where a webhook-failure alert was firing on a by-design skip. Of the three options — (A) fix at source with a 200 no-op + reason field, (B) filter the alert's KQL, (C) stop calling the webhook upstream — only A leaves the alert honest, and that was the decisive argument over the smaller diffs of B and C.

**How to apply:** For any "why does this alert fire on normal operation?" finding:
1. Root-cause the current signal path (what emits the error, what consumes it).
2. Propose A/B/C options with the error-at-source fix first and framed as recommended.
3. Pair the source fix with a discriminant on the response + a distinct structured log (e.g. `[X] Skipped` vs `[X] Created`) so the new non-error path is still auditable.
4. Update reconciliation scripts / downstream alerts that would otherwise false-positive on the new state.
