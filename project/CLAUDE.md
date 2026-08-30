# CLAUDE.md - Acme Monorepo

## General Guidelines

- When the user asks for a simple command or quick answer, provide it directly. Do not explore the filesystem or codebase unless explicitly asked. Keep responses minimal for straightforward requests.
- Do not run Read, Grep, or Glob unless the answer genuinely requires codebase context.

## Project Context

This project uses TypeScript with Azure Container Apps, Terraform for infra, and GitHub Actions for CI/CD. Database is SQL with snake_case columns — always use snake_case in raw SQL queries, not camelCase.

Nx monorepo: **legacy-api** (Express/TypeORM/PG), **legacy-web** (React/MUI/Vite), **legacy-web-e2e** (Playwright), **infra** (Terraform/Azure), **docs**.

> **CRITICAL: Always Use Nx Commands**
>
> - Generate: `nx generate @nx/<plugin>:application|library` — NEVER manually scaffold
> - Tasks: `nx run <project>:<target>` — NEVER run jest/tsc/eslint directly
> - Multi: `nx run-many -t test` or `nx affected -t test`
> - Before creating anything: use `nx_generators` and `nx_generator_schema` MCP tools

## Strategy & Principles

- **Single root `package.json`**, trunk-based dev (`main` always deployable), squash merge, branch naming: `feat/`, `fix/`, `chore/`
- **DDD** (bounded contexts, value objects, domain services) + **Clean Architecture** (domain→app→infra) + **SOLID** + **Clean Code**
- **Nx** tags for boundaries (`scope:`, `layer:`, `type:`), path aliases in `tsconfig.base.json`

## Quick Reference

Backend: `npm run dev / build / test / lint` | Frontend: `npm run frontend:dev / frontend:build / frontend:test / frontend:lint` | DB: `docker compose up -d && npm run db:recreate`

## Shared Libraries

**Check before creating types:** `@acme/domain-types` (Money, Quantity, DateRange, errors), `@acme/shared-constants` (commission configs, export formats), `@acme/data-seeding` (test data, backend only)

Module boundaries (ESLint enforced): backend→backend+shared, frontend→frontend+shared, shared→shared only. Layer: domain→domain, app→domain+app, infra→all.

New lib: `npx nx generate @nx/node:library shared/<name> --buildable --tags="scope:shared,type:lib,layer:domain"` — import as `@acme/<name>`

## Conventions

- **TypeScript**: Strict mode. Never `--transpileOnly` or `skipLibCheck: true`
- **Numbers**: `Big` from `big.js`. API: strings. DB: `numeric`
- **Dates**: UTC always. API: ISO/`YYYY-MM-DD`. DB: `timestamptz`/`date`
- **Style**: Prettier + ESLint. Named imports (lodash default)

## Rules

- Fix code to match specs, NOT docs to match code
- Limit tangential debugging to 2-3 attempts, then ask user
- Azure: preserve existing env vars on updates, run `terraform validate` + `plan` before committing
- Env vars: access through helper functions, not `process.env`
- Before running any destructive command (`git push --force`, `terraform destroy`, `DELETE`/`UPDATE` SQL, `az resource delete`, `rm -rf`), always show the command and ask for explicit confirmation. Never auto-execute destructive operations.

## Local Development

- Never start dev servers (`nx serve`, `npm run dev`) in Claude shell — Nx hangs in non-interactive mode. Output the exact commands for the user to run in their own terminal instead.
- When debugging local issues, test against the running services the user started — don't try to start your own.

## Git Workflow

- Always run `npx nx format:write` before staging and committing to avoid Prettier pre-commit hook failures.
- For git push: if pre-push hooks cause SSH timeouts, retry with `git push --no-verify` (only after hooks have passed separately).
- Before committing or pushing, always confirm you are on the correct branch. Run `git branch --show-current` and verify it matches the intended target branch. Never commit to a hotfix or merged branch without explicit user confirmation.

## Deployment

- This project uses Azure Container Apps with Terraform. Known pitfalls:
  1. Terraform Phase 2 can recreate Container App Environment causing FQDN mismatches
  2. `az containerapp update` registry args can fail in prod
  3. Always verify FQDN after deploy
- For CI: watch for Trivy CVE failures, npm lock file drift, and OIDC token expiry.
- Never run deploys while Terraform is still provisioning.

## CI/CD Pipeline

**Self-hosted runner** (`Standard_D8as_v5`, 8 vCPU, 32GB RAM) at `development-acme-runner`. Auto-shuts 17:00 UTC, auto-starts 06:00 UTC Mon-Fri. CI starts VM on demand via `az vm start` if off. Falls back to GitHub-hosted 2-core runners automatically when VM unavailable.

**Nx remote cache** — custom Bun+Elysia server on Azure Container App (`development-acme-bun-nx-cache`). Azure Blob Storage backend with L1 in-memory LRU. Dual-token auth: read token for PRs, write token only on main pushes. Cache health checked before every Nx task (non-blocking fallback to local cache).

**Key CI optimizations:**

- `NX_PARALLEL=6` on self-hosted runner (exploits 8 cores vs default 3)
- `node_modules` cached via `actions/cache` in fallback path — shared across `fallback-main` and 4 frontend test shards (eliminates redundant `npm ci`)
- `domain-api` and `nx-cache-server-bun` build targets have explicit `cache: true` (required for `nx:run-commands` executor)
- `label-critical.yml` auto-adds `run-integration` label when `apps/legacy-api/src/` or `libs/` change — triggers integration tests automatically
- Pre-push hook optionally sources `~/.acme/nx-cache.env` for remote cache hits locally

**Required CI checks for merge:** `main` (CI) and `Validate Terraform` only. Trivy, Security Scan, Label Critical are informational.

## Testing

- When fixing code, always update corresponding test files. If you change a function signature, API response shape, or component output, search for and update all related test expectations before committing.
- Run the full test suite before pushing. Never push a fix without verifying tests pass.

## Database

- This is a TypeScript monorepo using Nx. Database columns use snake_case but TypeScript uses camelCase — always check actual column names in migration files before writing SQL. When writing raw SQL against the commission database, use snake_case column names.

## Production Debugging

- When investigating production data issues, always use actual deal/invoice IDs from the database — never confuse database IDs with business-facing reference numbers.

## Code Review

- When reviewing documentation vs code discrepancies, ask the user which is the source of truth BEFORE making changes. Never assume docs should match code — the user may want code-first OR doc-first approach.

## GitHub

Repo: `initech-trading-platform/acme` — NEVER use `--repo` flag with `gh` CLI

## Platform Documentation

For the Platform NestJS / AKS platform (separate stack from the legacy
legacy-api + legacy-web apps):

- **Deployment topology** — `docs/platform/operations/deployment-guide.md` (not in this export):
  single-branch GitOps on `main`, AppOfApps, 7 ArgoCD Applications (5 BC
  bundles + gateway + ai), Argo Rollouts canary, Workload Identity,
  versioned event routing. Read this first when working on the Platform
  deploy path or CI/CD.
- **Architecture** — `docs/platform/architecture/` (not in this export)
- **Operations runbooks** — `docs/platform/operations/` (not in this export)
  (rollback, monitoring, secret-rotation, service-onboarding, security)
- **ADRs** — `docs/adr/` (not in this export) (numbered 0032–0036 cover the
  current Platform platform redesign)
- **Platform UI / design ("Platform v2")** — trading & finance screens are built from
  the approved **"Platform v2"** hi-fi prototype (Claude Design project `00000000…`,
  vendored at
  [`docs/platform/design/platform-v2-prototype/`](docs/platform/design/platform-v2-prototype/))
  on the `@acme/ui` kit (`libs/platform/ui`; `apps/platform-design-demo` is the live
  reference). Use the **`platform-ui`** subagent or the **`/implement-screen <name>`**
  command for any deal/invoice/commission/accounting/reference-data/communication
  screen — both apply the kit + the Platform domain invariants. For **kit** work
  (shared components/tokens) use the **`acme-ui-author`** subagent or
  **`/new-component <Name>`**; author a missing primitive in `@acme/ui` first,
  then consume it in the app (policy AD-7). The kit ships the full **config matrix**
  (6 accents · light/dark/system · comfortable/compact · wireframe · reduced-motion).
  Feature specs under
  `docs/platform/doc-site/platform/features/` (not in this export) are
  **authoritative for business rules**; the prototype governs appearance. Mapping,
  invariants + config-surface support status:
  `docs/platform/design/platform-v2-alignment.md` (not in this export).
- **Dev environment (live, 2026-06-26)** — the Platform frontend + gateway are
  served at **`https://dev.platform.acme-example.co.uk`** (browser-trusted Let's Encrypt
  cert; LB public IP `203.0.113.10`). Key facts before touching the dev deploy /
  ingress / TLS:
  - **Public ingress needs an explicit subnet-NSG rule.** AKS's cloud-controller
    adds the LoadBalancer `Internet → 80,443` allow only to the NSG **it** manages
    (the `MC_…` agentpool/NIC NSG) — it NEVER touches the Terraform-owned **subnet**
    NSG (`development-acme-nsg-aks-nodes`). Without an explicit subnet rule all
    public traffic dies at `deny-all-inbound` (80 _and_ 443 time out, invisible to
    every gate). The dev network module sets `enable_public_web_ingress = true`
    (see `infra/modules/network/main.tf`).
  - **Traefik is a standalone Helm release** (`traefik/traefik` v39, ns
    `traefik-system`, values `charts/infrastructure/traefik-values.yaml`) — **NOT
    ArgoCD-managed**; config changes need a manual `helm upgrade`. TLS = Traefik's
    built-in **HTTP-01** ACME resolver (production Let's Encrypt), **not**
    cert-manager. Traefik does not auto-retry a failed `obtain` — restart it to
    trigger one.
  - **Dead hostnames** (do not reuse): `platform-dev.acme-example.net`,
    `dev.platform.acme-legacy.co.uk`. The Azure-managed zone is `acme-example.co.uk`.

<!-- nx configuration start-->
<!-- Leave the start & end comments to automatically receive updates. -->

## General Guidelines for working with Nx

- For navigating/exploring the workspace, invoke the `nx-workspace` skill first - it has patterns for querying projects, targets, and dependencies
- When running tasks (for example build, lint, test, e2e, etc.), always prefer running the task through `nx` (i.e. `nx run`, `nx run-many`, `nx affected`) instead of using the underlying tooling directly
- Prefix nx commands with the workspace's package manager (e.g., `pnpm nx build`, `npm exec nx test`) - avoids using globally installed CLI
- You have access to the Nx MCP server and its tools, use them to help the user
- For Nx plugin best practices, check `node_modules/@nx/<plugin>/PLUGIN.md`. Not all plugins have this file - proceed without it if unavailable.
- NEVER guess CLI flags - always check nx_docs or `--help` first when unsure

## Scaffolding & Generators

- For scaffolding tasks (creating apps, libs, project structure, setup), ALWAYS invoke the `nx-generate` skill FIRST before exploring or calling MCP tools

## When to use nx_docs

- USE for: advanced config options, unfamiliar flags, migration guides, plugin configuration, edge cases
- DON'T USE for: basic generator syntax (`nx g @nx/react:app`), standard commands, things you already know
- The `nx-generate` skill handles generator discovery internally - don't call nx_docs just to look up generator syntax

<!-- nx configuration end-->

## Skill Precedence

When multiple skills overlap, follow this order:

1. **PM commands (`/pm:*`)** — project tracking, GitHub sync, status. Always the backbone.
2. **Agent-skills (addyosmani)** — engineering process (build, test, review, debug). Preferred over superpowers equivalents.
3. **Custom skills** — only for project-specific logic (deploy, hotfix, db-migration, etc.).
4. **Superpowers** — meta-workflows only (brainstorm, write-plan, execute-plan, dispatching-parallel-agents, using-git-worktrees). NEVER for TDD, debugging, or code review — use agent-skills instead.

Skills: Manual `/security-audit` `/performance` `/incident` `/full-review` `/infra-change` `/erp-issue` `/explore-codebase` `/update-deps` `/implement-*` `/validate-phase` `/scaffold-project` `/system-design` `/design-*` `/requirements-changed` `/dev-ephemeral` `/implement-all` | Auto: bug-fix, new-feature, api-change, frontend-change, db-migration, refactor, hotfix, pr-create, new-app, add-docs, cleanup, env-status, test-affected, github-refresh, technical-spec, cicd-troubleshoot, commit, deploy
