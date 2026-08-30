---
name: platform-up-local-bringup-gotchas
description: "Gotchas bringing the Platform stack up locally via `npm run platform:up` — BuildKit lease corruption, stale db container losing its host-port publish, seed admin/superadmin creds"
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000045
---

Running the full Platform stack locally = **`npm run platform:up`** (repo root; `.env.platform` must exist — copy from `.env.platform.example`). Order: build (one image at a time, memory-safe) → db up+healthy → **migrate** (before app services, because the seed overlay seeds on `OnApplicationBootstrap`) → services + seed → wait-healthy → bootstrap-login. `PLATFORM_FULL=1` adds the 8 extra BC services. Frontend is NOT in compose — run `npx nx serve platform-frontend` (Vite :5173, proxies `/api` → gateway :3000). Ports: db 5433, redis 6380, rabbit 5673/15673, pact 9292, gateway 3000, auth 3001, tenant 3002, user 3003, trading 3005.

**Gotcha 1 — BuildKit lease corruption on a base image.** A service build can fail with `failed to solve: node:22-slim@sha256:…: unable to lease content: lease does not exist: not found`. It's a corrupted BuildKit content-store lease, not a code error. Fix: `docker pull node:22-slim@sha256:<pinned-digest>` to repair the content store, then rebuild. (`docker builder prune -f` also works but is heavier.)

**Gotcha 2 — stale db container loses its host-port publish.** If a `platform:up` run fails while a port is occupied (e.g. another worktree's Platform db holds 5433), the `acme-db-1` container is CREATED but not started. A later `platform:up` `docker start`s that existing container, which comes up **healthy but WITHOUT the host port published** (`docker inspect`: `HostConfig.PortBindings` has 5433 but `NetworkSettings.Ports` is empty) — Docker Desktop's `start` on a container created during a port conflict doesn't re-establish the port proxy. Symptom: `migrate.sh` → "DB not reachable on localhost:5433" even though the container is healthy. Fix: `docker compose … down` (removes the stale container + network, keep volume) then `platform:up` so the db is **created fresh** with the port. Only ONE Platform stack can run at a time (fixed ports) — `docker ps --format '…{{.Label "com.docker.compose.project"}}'` to find a conflicting worktree stack and `down` it first.

**Seed creds (dev/local, `SEED_ON_BOOTSTRAP`):** the seeded tenant id, admin address, password and TOTP secret all live in the seed constants and the gitignored env file — read them from there, never from a note like this one. Dev SUPERADMINs (roster in `@acme/platform-contracts` `DEV_SUPERADMINS`) share one password with per-user TOTP; print login + current code via `npx tsx scripts/platform/dev-superadmin-mfa.ts <email>`. Generate any TOTP: `node tests/platform/lib/totp.mjs <secret>`. Login needs a valid tenant — backend now accepts the tenant NAME (see [[platform-login-tenant-name-resolution]]). See also [[platform-dev-superadmin-seed]], [[platform-local-sso-setup]].
