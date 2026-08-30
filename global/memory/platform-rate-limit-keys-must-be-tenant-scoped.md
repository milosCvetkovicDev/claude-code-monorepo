---
name: platform-rate-limit-keys-must-be-tenant-scoped
description: "Platform multi-tenant Redis rate-limit keys must include tenantId or one tenant can poison another's bucket"
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000013
---

Platform auth rate limiters are Redis `INCR key` + `EXPIRE` counters (`IRateLimitStore`,
`RedisRateLimitStore`). In a multi-tenant system the bucket key MUST include the resolved
`tenantId`, else the same email across two tenants shares ONE bucket and tenant A's attacker
can exhaust tenant B's user's quota (cross-tenant bucket poisoning).

Password-reset was keyed `password-reset:{email}` (bug); fixed in PR #1638 (`f61058c6`) to
`password-reset:{tenantId}:{email.toLowerCase()}`. Login already scoped by `(tenantId, email)` —
follow that shape for ANY new limiter (MFA verify, OTP resend, etc.). `@IsUUID()` on the tenantId
DTO field forecloses key-injection/collision/cardinality-blowup (UUID has no `:`).

**Why:** surfaced in the PR #1635 security review; it's a recurring class of bug whenever a
per-user throttle is added to a multi-tenant endpoint.

**How to apply:** when adding/reviewing a rate limiter on a tenant-scoped auth endpoint, check the
key literal includes `{tenantId}`. Reset-TOKEN store keys (`password-reset:{tokenHash}`) are a
DIFFERENT namespace (single-use GET+DEL, keyed by token hash) — leave those alone. The accepted
tradeoff: an email in N tenants gets N×3/hour to one inbox — correct vs cross-tenant griefing.
Related tenant-isolation: [[platform-fail-closed-tenant-filter-forked-em]], [[platform-tenant-resolution-epic]].
