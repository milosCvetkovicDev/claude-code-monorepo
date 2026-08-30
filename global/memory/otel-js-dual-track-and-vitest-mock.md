---
name: otel-js-dual-track-and-vitest-mock
description: OpenTelemetry JS dual-track versioning rule + vitest cannot mock dynamic require() of externalised node_modules (Platform
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000016
---

OpenTelemetry-JS ships **two release tracks that must stay aligned**:

- **Stable** (`api` 1.x, `resources` 2.x, `sdk-metrics` 2.x, `sdk-trace-base` 2.x,
  `semantic-conventions` 1.x)
- **Experimental** (`sdk-node`, `exporter-*-otlp-*`, `auto-instrumentations-node`,
  `instrumentation-*`) — versioned `0.2xx`, where `0.217.x` pairs with stable `2.x`.

Mixing tracks ⇒ `npm ci` cannot resolve a consistent `@opentelemetry/core` (1.x vs 2.x peer
conflict). The #1286 blocker: someone pinned `sdk-metrics ^1.25.1` + `exporter-metrics-otlp-http
^0.52.1` (mid-2024) into a `sdk-node ^0.217 / resources ^2.7.1` stack. Fix = bump metrics to the
matching track: `sdk-metrics ^2.7.1`, `exporter-metrics-otlp-http ^0.217.0`. `sdk-node@0.217.0`
already pulls both transitively, so the aligned pins dedupe cleanly (OTel-scoped lockfile diff only).
**To find the right pins:** `npm view @opentelemetry/sdk-node@<ver> dependencies` shows the exact
versions it expects for every sibling package.

**vitest gotcha (durable):** vitest _externalises_ `@opentelemetry/*` (all node_modules) by default,
so `vi.mock`/`vi.doMock` **cannot intercept a production module's dynamic `require('@opentelemetry/
…')`** — the real module loads and `MockNodeSDK.mock.calls` stays empty even though the SDK actually
started (the success log prints, which is what unmasks it). Don't fight the mock; test the
**observable contract** against the real packages instead: import the module with `OTEL_ENABLED=true`,
assert `sdk` is defined + the metrics try/catch did NOT emit its "metrics initialization failed"
degradation `console.warn`. Stronger anyway — it exercises the real version-resolved tree. Point the
exporter at `http://127.0.0.1:<port>` (not a hostname) so a missing collector refuses instantly
instead of stalling shutdown on DNS, and cap with `OTEL_EXPORTER_OTLP_TIMEOUT`.

**Platform determinism ESLint guard** (`no-restricted-syntax`, #1014/#1016) bans literal
`await new Promise(r => setTimeout(r, ms))` **even in test teardown** — 2-core OOM/flake risk.
Use a fast-failing endpoint + plain awaited shutdown (no race/sleep) instead.

**Platform RED metrics come from the collector spanmetrics connector, NOT app HTTP
histograms** (AC:6): the burn-rate/error-ratio rules query `calls_total` and p95
queries `duration_milliseconds_bucket` — both derived from **traces** by the
otel-collector spanmetrics connector (dims trimmed to http.method/http.status_code,
service.name). So the app just needs traces flowing (otel.enabled); no
`OTEL_SEMCONV_STABILITY_OPT_IN` / `http_server_request_duration_seconds` needed.

**`OTEL_SERVICE_NAME` MUST be set explicitly per service** (#1188, PR #1286 commit
7c2d561b): the spanmetrics `service_name` label = the app's `service.name` =
`OTEL_SERVICE_NAME`, and the RED rules filter on canonical `platform-<svc>-service`.
Binding it to the Helm `fullname` is wrong — fullname is release-prefixed
(`platform-identity-auth-service`, `platform-ai-ai-service`), so 12/13 mismatch and the
RED surface stays dark even though traces flow. Fix = `platform-base` `otel.serviceName`
value → `OTEL_SERVICE_NAME = serviceName | default fullname`; set canonical names in
the dev overlays (standalone flat; the 11 bundle services under `<alias>.otel.*`
since flat overlay keys don't reach umbrella subcharts). The app-metrics slice is
OTLP→collector→Mimir = **ungated by AD-3** (collector live since #1311), but its
DEPLOY (rolling restart of 13 svcs) is Milos-gated.

**State 2026-06-18:** #1286 rebased onto main (merge resolved: dropped the dup
`templates/otel-collector.yaml`, took main's cutover `otel-collector-values.yaml`,
registered its new argocd apps in the discovery drill). The **ungated app-metrics
RED slice was then split out → PR #1325** (DRAFT, off main): otel enablement on all
13 svcs + canonical `otel.serviceName` + spanmetrics alert/AnalysisTemplate adoption
(`calls_total`/`duration_milliseconds_bucket`) + OTLP SDK metrics deps. #1325 merges
first (ungated, Milos-gated deploy = rolling restart) → then #1286 rebases and its
diff collapses to the AD-3-gated remainder (kube-prometheus-stack, ServiceMonitors,
LGTM-under-ArgoCD apps, grafana ESO, mimir storage/ruler, AppProject, ADR-0050).
Post-deploy verify: Mimir `count by (service_name)(calls_total)` → expect 13.

**Deploy-smoke caught a SECOND blocker (2026-06-18):** #1325 merged + deployed
cleanly (services healthy, no OOMKills) but OTel **still didn't initialize** —
`@opentelemetry/sdk-node → @opentelemetry/configuration → yaml: Cannot find
module '../doc/directives.js'` → "telemetry disabled" on every service → no
traces → spanmetrics/RED stayed dark. Root cause (3-way confirmed: clean
lockfile/local, live pod missing only `yaml/dist/doc/`, the build): the shared
`apps/platform/Dockerfile` deps-stage slim-prune did `find node_modules -type d
-name 'doc' -o -name 'docs' -exec rm -rf` — but **`yaml@2.x` ships RUNTIME code
under `dist/doc/`** (directives.js, Document.js), and sdk-node's `configuration`
eagerly `require()`s yaml at init. Dormant on main (otel off everywhere);
#1325 turning otel on surfaced it. **Fix = PR #1328**: drop `doc`/`docs` from
the dir-name prune (keep file-pattern prune + conventionally-non-runtime dir
names) + a **build-time guard** (`node -e "require('@opentelemetry/
configuration'); require('@opentelemetry/sdk-node')"` after the prune fails the
image build if any load-bearing module is pruned again). Verified RED→GREEN
against a real `--target deps` docker build. **Durable lesson: slim-node
prunes that delete dirs BY NAME (`doc`/`docs`/etc.) can delete runtime code —
prune by file-pattern, and assert the critical require-chain at build time.**
**RESOLVED 2026-06-18:** #1328 merged → rebuilt+redeployed all 13 (sha-2f386b50)
→ new-image pods log **`OpenTelemetry SDK started for service "platform-ai-service"
(traces + metrics + logs)`** (was "telemetry disabled") — fix proven live. The
build-time `node -e "require('@opentelemetry/configuration')…"` guard passed in CI
for every image. **Getting `main` green for the rebuild was whack-a-mole** (build-push
needs ci green): (1) 3 pre-existing HIGH CVEs blocked Trivy → bumped
platform-fastify/multer/protobufjs (#1330); (2) #1327 inserted REVOCATION_REDIS_URL
env, shifting #1185's positional RMQ helm-index — independently fixed by #1329 (deduped
my repin via merge); (3) `platform-frontend` missed #1208's 30s testTimeout → MfaSetupPage
axe `Test timed out in 5000ms` flake (#1330). Deploy = dispatch `platform-pipeline.yml
deploy=true`; the gitops **writeback auto-merge is enterprise-blocked** → manually merge
the `deploy: sha-… → development` bump PR (#1331). Rollouts are **time-based auto-promote
canary** (pause 2m steps; no manual promotion). **spanmetrics path is COMPLETE + UNGATED**
(collector config: traces→spanmetrics connector→metrics pipeline→`prometheusremotewrite/mimir`
direct; NOT a Prometheus-scrape/#1286 dependency) — but `count by(service_name)(calls_total)`
is **0 because dev services are IDLE** (no spans; health probes untraced), NOT a defect;
RED populates under real traffic. (Synthetic-traffic verify blocked by restricted PodSecurity.)
Separate pre-existing: gateway `JWT_SECRET` crashloop (recovered to Healthy post-roll).

See [[platform-dev-stabilization-epic]] (#1188 observability — PR #1325 app-metrics slice, PR #1286 gated remainder, PR #1328 image-prune fix).
