---
name: platform-azure-cache-redis-6-0-no-getdel
description: Platform auth talks to Azure Cache for Redis 6.0 (no GETDEL/6.2+ commands) — use portable Lua for atomic ops;
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000009
---

**Platform auth-service Redis is Azure Cache for Redis 6.0** (dev `REDIS_URL` secret → `rediss://…@development-acme-platform-redis.redis.cache.windows.net:6380`, TLS port 6380, DB 1). **Azure Cache for Redis (non-Enterprise) runs Redis 6.0 — it does NOT support `GETDEL` (added in 6.2)** or other 6.2+ commands. The in-cluster `charts/infrastructure/redis-identity.yaml` (Redis 8.2.1) is NOT deployed in `platform-identity` — the chart exists but auth points at the managed Azure cache.

**#1513 (fixed 2026-06-29, PRs #1514+#1515):** the single-use token stores (`apps/platform/auth-service/src/infrastructure/redis/redis.adapters.ts`: MFA challenge `consumeChallengeToken`, `RedisResetTokenStore`, `RedisOidcStateStore`) used raw `GETDEL` → on dev they 503'd (`AUTH_MFA_UNAVAILABLE`, `ERR unknown command 'getdel'`), breaking **2FA login (`/auth/mfa/verify`), password-reset, and OIDC**. `SET` (login) worked, `GETDEL` (verify) didn't — asymmetry that points straight at a version-specific command. Only surfaced once #1396 (CORS soft-reject) let dev-origin requests reach auth.

**Durable fix (provider-neutral, [[feedback_provider_neutral_no_azure_coupling]]):** replace `GETDEL` with an atomic Lua `GET`+`DEL` (`EVAL`, Redis 2.6+) in one shared helper — same single-use atomicity, works on any Redis. **Rule: never use Redis ≥6.2-only commands (`GETDEL`, `GETEX`, `COPY`, `SINTERCARD`, etc.) in Platform code — Azure Cache for Redis is 6.0. Use Lua `EVAL` for atomicity.**

**Test trap that hid it:** `redis-stores.tc.spec.ts` used `redis:7-alpine` (GETDEL works). Now **pinned to `redis:6.0-alpine`** (the Azure Cache floor) so the contract is enforced — verified 6/6 on real 6.0. Lesson = [[feedback_reproduce_ci_exact_env]]: test integration against the deployed version, not a newer default. Verified live: dev `POST /api/v1/auth/mfa/verify` flipped 503 → 200 + session. See [[platform-identity-epic-prep]], [[platform-ui-test-blindfold-and-icu-casing]] (the #1396 CORS deploy that exposed this).
