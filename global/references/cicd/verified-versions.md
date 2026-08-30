# Verified Versions — Acme CI/CD

Last verified: 2026-04-09

**CRITICAL: When writing CI/CD configs, ONLY use versions listed here. If a version is not listed, CHECK the existing workflows first — do NOT guess from memory.**

## GitHub Actions (SHA-Pinned)

| Action | SHA | Tag | Notes |
|--------|-----|-----|-------|
| actions/checkout | `de0fac2e4500dabe0009e67214ff5f5447ce83dd` | v6.0.2 | Always use `filter: tree:0` |
| azure/login | `532459ea530d8321f2fb9bb10d1e0bcf23869a43` | v3.0.0 | Used in `./.github/actions/azure-login-oidc` + `./.github/actions/terraform-setup` composites only. Don't inline; always go through a composite. |
| docker/setup-buildx-action | `c47758b77c9736f4b2ef4073d4d51994fabfe349` | v3.7.1 | |
| docker/login-action | `9780b0c442fbb1117ed29e0efdff1e18412f7567` | v3.3.0 | |
| docker/metadata-action | `369eb591f429131d6889c46b94e711f089e6ca96` | v5.6.1 | |
| docker/build-push-action | `4f58ea79222b3b9dc2c8bbdd6debcef730109a75` | v6.9.0 | |

## CLI Tools (Checksum-Pinned)

| Tool | Version | SHA256 | Notes |
|------|---------|--------|-------|
| yq (linux/amd64) | v4.44.1 | `6dc2d0cd4e0caca5aeffd0d784a48263591080e4a0895abe69f3a76eb50d1ba3` | Used in platform-deploy.yml |

## Runtime Versions

| Runtime | Version | Where Used |
|---------|---------|------------|
| Node.js | 22 | CI env, Dockerfiles, .nvmrc |
| Bun | 1.1.45 | domain-api, helix-agent |
| npm | (bundled with Node 22) | CI, Dockerfiles |

## Docker Base Images (Digest-Pinned)

| Image | Digest | Used For |
|-------|--------|----------|
| `node:22-slim` | `sha256:f3a68cf41a855d227d1b0ab832bed9749469ef38cf4f58182fb8c893bc462383` | Platform deps stage |
| `node:22` | `sha256:ecabd1cb6956d7acfffe8af6bbfbe2df42362269fd28c227f36367213d0bb777` | Platform build stage |
| `gcr.io/distroless/nodejs22-debian12:nonroot` | `sha256:13593b7570658e8477de39e2f4a1dd25db2f836d68a0ba771251572d23bb4f8e` | Platform production stage |
| `oven/bun:1.1.45-alpine` | (not yet pinned) | Bun service stages |

## Infrastructure Images

| Image | Version | Used For |
|-------|---------|----------|
| `postgres` | 16 | docker-compose.platform.yml |
| `redis` | 7 | docker-compose.platform.yml |
| `rabbitmq` | 3-management | docker-compose.platform.yml |

## Azure Container Registry

| Registry | Purpose |
|----------|---------|
| `developmentacmeacr.azurecr.io` | Platform service images |

## Helm Chart

| Chart | Version |
|-------|---------|
| platform-base | 0.1.0 (apiVersion: v2) |

## How to Update This File

When upgrading a version:
1. Test in CI first (PR workflow must pass)
2. Update this file with the new version
3. Update all workflows that reference the old version
4. Verify with `gh run list --workflow=ci.yml --limit=1`
