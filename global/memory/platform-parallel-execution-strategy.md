---
name: platform-parallel-execution-strategy
description: 'Run independent Platform workstreams in parallel (concurrent epics + parallel subagents/workflows) to save calendar time; the M2-milestone "program.md" model is retired.'
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000016
---

**Principle (durable):** advance independent Platform workstreams in PARALLEL, not sequentially — saves ~30–50% calendar time. Two layers:

1. **Concurrent epics** — platform/infra, identity, testing, and data-tier epics run alongside each other, not one-after-another.
2. **Parallel subagents/workflows WITHIN an epic** — fan out read-only investigation, drift-verify, and review (one agent per PR/dimension, isolated worktrees to avoid git-add races), then adjudicate centrally. E.g. 2026-06-19: 1 soak-audit + 4 isolated-worktree drift-verify agents in parallel, then a single consolidation. The harness `Workflow` tool / `parallel-worker` agent formalise this when scale warrants.

**Current parallel tracks (state 2026-06-19, post-session):**

- **#1180 platform-dev-stabilization** — ACTIVE. app-metrics + OTel live fleet-wide; 3 gated DRAFTs **drift-verified GREEN on main** (#1301 RMQ / #1287 OpenBao / #1286 observability), operator-apply behind §5 soak (**RESET → ~2026-06-26**). Merge-tail LANDED 2026-06-19: **#1297** (KV state-reconcile runbook + preflight, incl. revocation-redis-url catalogue fix) + **#1338** (Trivy PR-time→informational, deploy-time hard gate kept) both MERGED to main. See [[platform-dev-stabilization-epic]].
- **#1265 platform-identity + #1247 real-DB identity** — ACTIVE, mostly shipped to main. This session: **#1337 (#1280 event-exchange) MERGED**; closed #1267 (RS256) + #1269 (cookie/MFA/SessionIssuer) [verified on main] + #1168 (dup of #1277). Remaining: **#1277** admin-bootstrap seed (operator/sign-off gated → runs LAST), #1304 docs (--admin), **#1266** RED-harness (held OPEN — delivery unconfirmed, recon's #1302 evidence was actually #1293/#1295). See [[platform-identity-epic-prep]], [[platform-outbox-atomicity-pattern]].
- **#1166 platform-testing + #1248 M2-readiness** — harness MERGED (PR #1213, epic ~38%). **#1254 gateway reverse-proxy (ProxyModule) MERGED 2026-06-19** (PR #1341, squash `aad2bf11`; closed #1254). In-process `@All('api/v1/*')` + undici wrapped in CircuitBreakerService; **2-reviewer pass (correctness+security) before merge** fixed 5 findings — most notably the **gateway guards are now registry-aware**: `JwtValidationGuard` + `TenantResolutionGuard` honor service-registry `requiresAuth:false` (via `resolveService(req.url)`) so `/api/v1/auth/*` bypasses gateway auth and proxies to auth-service (THE public-route mechanism now — not `@Public()` for proxied routes). Also: undici dev-only→prod-dep ≥7.28.0 (CVE-2026-9697); per-path body-limit re-checked on buffered length; x-forwarded-\* set authoritatively; `..`/`%2e` rejected in resolveService; x-mfa-enabled forwarded (ADR-0054). Unblocks **#1172** (journeys via gateway). Remaining tiers (#1173–#1179) still need login (#1277 seed)/relay/RBAC. #1168 reconciled → #1277 owns the seed. See [[platform-testing-harness-epic]], [[platform-test-dynamic-import-tripwire]].
- **#693 platform-cnpg-per-bc-data-tier** — POC authoring COMPLETE on main; this session **#1146 (restore-verify) + #1163 (restore-test fed cred) MERGED** (evidence, no deploy). Activation DRAFTs #1152/#1156 (live operator/cluster on merge) PARKED behind #669/#1116–#1118. See [[platform-cnpg-data-tier-poc-gated]].
- **platform-redesign** — the LIVE topology (single-branch GitOps + AppOfApps + Rollouts canaries + ESO WIF + versioned events). Open: #669 prod-verify. See [[platform-redesign-topology]].
- **#481 platform-m6-production-launch** — production-launch epic (downstream).

**Retired (do NOT cite):** the M2/M3-milestone parallel matrix at `.claude/milestones/platform/program.md` is GONE; the "Track A/B/C/D milestone" framing (M2 traders / AKS provisioning / M3 architecture / legacy-CI) is historical. The legacy-CI track folded into ARC/CI work (#844). Platform is **single-branch-GitOps + epic-based**, not milestone-sequenced.
