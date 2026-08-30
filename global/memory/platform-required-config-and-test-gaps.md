---
name: platform-required-config-and-test-gaps
description: "Platform traps when making a config var REQUIRED — validateConfig process.exit kills vitest workers, CI gates are blind to integration, and helm tests asserting deployment.yaml miss the Rollout that actually ships"
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000009
---

Learned the hard way while fixing #1589/#1661 (see [[platform-tenant-resolution-epic]]).

**1. Making a config var REQUIRED silently kills `test:integration`.** `validateConfig`
(`libs/platform/config/src/index.ts:212`) calls **`process.exit(1)`, it does NOT throw**. Services call it
at MODULE SCOPE (e.g. `apps/platform/<svc>/src/app.module.ts:49`), and `test/bootstrap.spec.ts` imports
`src/app.module` — so a missing required var **hard-kills the vitest worker** with no usable
diagnostic (and `singleFork: true` for isolated suites takes the whole integration suite down with
it). **ALWAYS add the var to `apps/platform/<svc>/test/setup.ts`** (`process.env['X'] ??= '…'`) in the
SAME commit; the bootstrap harness only supplies NODE_ENV/DATABASE_URL/RABBITMQ_URI/MIGRATIONS_PATH.
Precedent: gateway's setup.ts does this for REDIS_URL. Also update the service's `config.spec.ts`
`validEnv` (specs safeParse object literals, never `process.env`, so "fails when X is missing"
guards stay honest). Filed #1663 to make validateConfig throw under NODE_ENV=test.

**2. The Platform CI gates CANNOT see integration failures.** Do NOT trust green CI here:
`platform-ci.yml` is **DEPRECATED** (zero merge weight, `workflow_dispatch` only, superseded by
`platform-pipeline.yml` → `_ci.yml`). The live `_ci.yml` `bootstrap-harness` job is
`if: inputs.run_integration`, and `platform-pipeline.yml` sets **`run_integration=false` for any PR
without the `run-integration` label** → it never runs on the PR. Even post-merge on main it is
`continue-on-error: true`, and `platform-ci-gate: needs: [resolve, ci]` ignores it. Net: **merge green,
main green, integration suite silently dead.** Add the `run-integration` label to at least annotate,
and run `npx nx test:integration platform-<svc>` locally (needs Docker).

**3. helm-unittest asserting `deployment.yaml` guards NOTHING on dev/prod.** `charts/platform-base`
gates the two workload templates MUTUALLY EXCLUSIVELY — `deployment.yaml`:
`{{- if not .Values.rollout.enabled }}` vs `rollout.yaml`: `{{- if .Values.rollout.enabled }}` — and
`charts/overlays/dev/identity.yaml` sets `rollout.enabled: true` (live dev: all identity services are
`rollout.argoproj.io/*`, zero Deployments; prod inherits the canary). So a chart test targeting
deployment.yaml asserts a manifest that **never ships**. Target `rollout.yaml` too, with
`set: {<svc>.rollout.enabled: true}`. Also override `release: {name: platform-identity}` per-test — the
suite default (`identity-bundle`) renders Services the asserted host doesn't exist in.
**Prove a chart guard is real by mutating the value out and watching it go RED** — a render assertion
pointed at the wrong template is worse than no test (false confidence).

**4. Fail-open adapters make config drift invisible.** A `catch { return null }` on a cross-service
call turns a chart misconfig into a valid-looking **HTTP 200 with a wrong field** — no health gate,
rollout status or smoke test can ever see it. Always `logger.warn` in the catch. Corollary: only
**render-time** assertions can catch this class. #1662 tracks the real closer: a contract test
asserting each service's REQUIRED schema vars ⊆ what its chart supplies.

**5. The gateway proxy forwards headers from an ALLOW-LIST — nothing implicitly.**
`apps/platform/gateway/src/modules/proxy/proxy.service.ts buildOutboundHeaders`: only
`FORWARDABLE_REQUEST_HEADERS` (content-type/accept/accept-language), `CORRELATION_HEADER`,
`IDENTITY_HEADERS` (authed routes only), opt-in `authorization`/`cookie`, and (since #1676)
`RESOLVED_TENANT_HEADER`. **Any new cross-service header silently vanishes at the proxy** unless
added to a list — the middleware setting `req.headers[...]` on the gateway does NOT mean the
upstream sees it. This dropped `x-resolved-tenant-id` and 401'd the SSO handoff exchange
deterministically (4th onion layer of #1589: state-cookie → ssoEnabled → AUTH_SERVICE_URL →
proxy drop), invisible because the exchange use-case's fail-closed 401 branches logged NOTHING
(now they name the failing gate — `hostResolved=false` ⇒ header/routing defect). Corollary of
rule 4: every fail-closed security gate needs a server-side warn naming which gate tripped.

**6. "Port + mock exists" ≠ "the pipeline works" — check WHO INJECTS the token.**
notification-service had `IEmailProvider` + MockEmailProvider + delivery entities + an operator
retry endpoint + a renderer + `NOTIFICATION_EMAIL_PROVIDER` config — and **zero injections of
`EMAIL_PROVIDER` anywhere**: no send worker was ever built, so every email sat QUEUED forever on
every provider _including the mock_ (apex discovery CTA silently no-oped). Grep
`Inject(TOKEN_NAME)` before trusting a port's existence. Fixed by `SendDeliveryUseCase` (#1678)

- AcsEmailProvider + fail-loud config refine + count-gated `platform-acs-email` TF. Related FE
  twin-bug: `workspace-memory` writer lived on the TENANT origin while the reader renders on the
  APEX origin — per-origin localStorage means the feature could never fire (#1677: remember on
  apex-side Open). **Cross-origin localStorage: writer and reader must share an origin.**

**7. The SSO five-layer saga (#1589) — full chain for reference.** state cookie on wrong host
(FE relative init → #1667 apex-absolute) → `ssoEnabled:false` (#1661 AUTH_SERVICE_URL) →
single-tenant redirect URI (#1667 slug-less callback + Migration_007 + Entra reg) → proxy
dropped `x-resolved-tenant-id` (#1676 allow-list) → **gateway(REAL secret)↔identity(SENTINEL)
INTERNAL_API_SECRET mismatch** (#1681 = the #1660 fix): gateway ESO had `platform-internal-api-secret`
wired since forever, identity bundle never did → every gateway→tenant internal call 401'd → the
tenant-resolution middleware deleted the header on EVERY request. Debugging key: the #1676
observability booleans (`sessionTenantFound/hostResolved/match`) named the gate instantly; live
pod probes (`kubectl exec <pod> -- /nodejs/bin/node -e 'fetch(...)'` using the POD's OWN env for
secrets, never printing them) proved each hop. **Rule: when two services must share a secret,
grep BOTH sides' charts for the KV key — a comment claiming "all sides read the same key" is not
wiring.**

**LAYER 6 (the real final hop, #1703 `c9e1ee77`, 2026-07-18) — Fastify onRequest hook ORDER.**
After all five layers above were fixed+deployed, SSO STILL 401'd `HANDOFF_CODE_INVALID` with
`hostResolved=false`. #1676 added `copy(RESOLVED_TENANT_HEADER)` to the proxy (correct) but had
NOTHING to forward: the gateway's anti-spoof strip hook (`strip-gateway-headers.hook.ts`, whose
`GATEWAY_INJECTED_HEADERS` set includes `x-resolved-tenant-id`) was registered AFTER NestJS's
middie hook. Fastify runs `onRequest` hooks in REGISTRATION ORDER, and Nest registers middie
(which runs `TenantHostResolutionMiddleware`, the header's SETTER) DURING `NestFactory.create()`.
`create-gateway-app.ts` called `wireGatewayFastifyHooks(fastify)` AFTER `NestFactory.create()`, so
strip ran AFTER the middleware and DELETED the trusted value the middleware had just set → header
left the gateway empty → auth-service `hostResolved=false`. **Fix: move `wireGatewayFastifyHooks`
to BEFORE `NestFactory.create()`** (same raw adapter instance) so order is strip→set: strip removes
only a CLIENT-supplied copy (anti-spoof intact), then the middleware injects the trusted value,
which survives to the proxy. Regression guard: `apps/platform/gateway/test/tenant-header-propagation.integration.spec.ts`
boots the REAL Fastify app (`createGatewayApp` + `.inject`) → stub upstream, asserts the header
arrives AND that a client `x-resolved-tenant-id` is stripped-and-replaced.
**Meta-rules this cost hours to learn:** (a) a "reasoned but never-reached-end-to-end" fix (#1676)
can mask a SECOND defect at the SAME hop — verify the actual runtime, not the reasoning. (b) When
a Nest+Fastify request-lifecycle bug is suspected, DUMP the live `onRequest` hook array order —
registration order across middie/plugins/global-hooks is the usual culprit and is invisible to
unit tests that exercise middleware and hooks separately. (c) LIVE canary-pod verification technique
that isolates gateway header delivery from the OIDC/Entra flow WITHOUT credentials: inject a
throwaway `handoff:{code}` into auth-service Redis (**DB 1**, via inline `node:tls` RESP AUTH+SELECT+SETEX
from the pod, never printing the password) with a VALID-hex-UUID `sessionId` (an invalid uuid makes
the session-lookup throw 500 before the cross-check runs), then replay through the gateway and read
the `hostResolved` boolean from the warn. To target a specific canary pod use `node http` (NOT
`fetch`/undici, which OVERRIDES the `Host` header with the URL authority) to send `Host:` verbatim.

**8. Revert hazard for required config.** The chart env and the `image.tag` revert INDEPENDENTLY (the
tag is bumped by the CI writeback). Once a required-config image ships, a lone `git revert` of the
chart PR → auto-sync (prune+selfHeal) applies it in minutes → pod fails Zod at boot. With dev's
`replicas=1` + canary `maxSurge:0/maxUnavailable:1` (replace-in-place) there is **no old pod to fall
back to** = hard outage. Revert `image.tag` in the SAME commit.
