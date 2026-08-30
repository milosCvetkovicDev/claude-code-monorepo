---
name: platform-dlq-not-deployed-stale-artifact
metadata: 
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000008
---

Found 2026-06-05 during #669 P5-S2 verification (DLX message-loss protection).

**Proven (read-only broker inspection, dev `rabbitmq-0` ns `rabbitmq`):** 12 `*.dlx`
exchanges exist but only ONE `*.dlq` queue — `audit-service.events.dlq`. The broker's
quorum `started cluster …` log over the full window (broker up 9d, 0 restarts since
2026-05-26, no data loss) records only audit's DLQ ever forming. Work queues (e.g.
`commission-service.trading`) form at a logged timestamp but their sibling DLQ —
declared on the line *immediately before* the work queue in the same linear,
try/catch-free setup path (`commission .../trading-event-consumer.ts:124-140`) — has
NO creation log line, even on initial connect or across 4 days of reconnects. So the
running compiled JS never executes `assertQueue(<svc>.dlq)`.

**Net effect:** for the 11 non-audit DLX exchanges, dead-lettered/nacked messages route
to an exchange with no bound queue → **silently discarded**. The exact black-hole that
#1008 ("bind DLQ to every consumer DLX", 574a6b61, merged 2026-05-29) set out to fix is
**live in dev** for 11/12 services. Only audit-service has the full live chain.

**NOT a code gap** — `main` declares DLX+DLQ+binding for every consumer (shared
`setup-rabbit-consumer.ts:80-92`; inline in commission/inventory/notification/
accounting/document). **NOT a permission gap** — `commission_user configure
^(acme\.commission(\..*)?|commission-service\..*)$` matches `commission-service.trading.dlq`.

**Root cause:** STALE BUILD ARTIFACT. Deployed commission image is tagged `sha-20313cd`
(commit 20313cd1, has #1008 in ancestry) yet ships JS that predates #1008's DLQ lines. audit
built fresh → DLQ live. **NOT an Nx remote-cache hit** (corrected by arch-board 2026-06-05):
the Nx remote cache is NOT consulted inside the Docker build (no `NX_SELF_HOSTED_REMOTE_CACHE`
build-arg passed to `docker/build-push-action` in `_build-push.yml`; it uses `cache-from/to:
type=gha,mode=max` — the **Docker BuildKit GHA layer cache**). Candidate mechanisms: (1) Docker
BuildKit GHA layer cache serving a stale `RUN npm ci && nx build` layer; (2) `_build-push.yml`
affected-detection (#1050) seal-fallback to a pre-#1008 image for a later non-affecting SHA.
**Gotcha (RESOLVED 2026-06-05, mechanism now PROVEN on CI):** bumping
`.github/ci-cache-version.txt` did NOT bust the Docker build — it's in `nx.json` sharedGlobals
(busts Nx cache only), NOT in the Docker context. **Two failed fixes, then the working one:**
(1) `#1143` added `COPY .github/ci-cache-version.txt ./` before the build RUN — FAILED: `.github`
is `.dockerignore`-excluded. (2) `#1147` changed `.dockerignore` `.github` → `.github/**` +
`!.github/ci-cache-version.txt` negation — passed LOCALLY, still FAILED in CI with
`"/.github/ci-cache-version.txt": not found`. **Root gotcha: CI's shared BuildKit daemon
(ADR-0040) PRUNES the excluded `.github` subtree before the `!`-negation can re-include the one
file; local BuildKit does NOT prune, so local builds mask the bug.** (3) **WORKING fix `#1148`:**
stop COPYing entirely — read the file on the runner and pass `--build-arg CI_CACHE_VERSION="$(cat
.github/ci-cache-version.txt)"`; Dockerfile declares `ARG CI_CACHE_VERSION=0` referenced in the
build RUN (`RUN echo "ci-cache-version=${CI_CACHE_VERSION}" && npm ci && nx build`) so a bumped
value changes the layer cache key. Covered ALL build sites: `_build-push.yml` (matrix, via a
read-step → step-output), `_ci.yml` ci+ci-fallback gateway/trading scan builds, `platform-ci.yml`.
`.dockerignore` reverted to plain `.github`. Proven green on the exact `Build gateway image for
scanning` step that was RED on main. **Lesson: never rely on `.dockerignore` `!`-negation under a
shared/persistent BuildKit daemon — use a build-arg.**
Remediate (Phase 1): bump `.github/ci-cache-version.txt` (sharedGlobal → ALL 12 Platform services
"affected" → `_build-push.yml` rebuilds them; the build-arg now busts the Docker layer too), then
**prove each new image carries the DLQ code via `crane`/`skopeo` export + grep of `dist/`
(distroless blocks in-pod grep)** with `scripts/ci/verify-image-dlq.sh`, deploy, then re-check the
broker forms the 11 DLQs (`rabbitmqctl list_queues -p acme name | grep dlq`). Build/push is
shadow (health-neutral); **redeploy = shared-dev write → needs user OK.**

This is the deployment-integrity layer on OPEN code-level issues #983 (consumer-DLX DLQ
binding), #1009 / #984 (outbox-relay DLX retention). Connects to the "bust Nx cache on
workflow build changes" gotcha and the [[platform-dev-deploy-recovery]] image-staleness
theme. Evidence written to #669 prod-verify-phase-5 / PR #1113 (commit 16ed61dc).

**RESOLVED 2026-06-06 — #983 CLOSED.** Surgical 6-service rebuild (#1151, build-arg fix
#1148) → images verified FRESH (carry #1008) → deployed `sha-221cbf3` to dev-platform (#1153,
admin-merged tag change; bot-push to protected main can't work). Final broker state:
**12/12 `*.dlq` live and bound to their `*.dlx` with routing-key `dead-letter`** (was 1).
The remaining DLQ work (#1009/#984 outbox-relay retention) is separate. **Mid-deploy a
RMQ-credential incident surfaced** (commission/document/notification 403'd) — NOT a #1008
issue; it was a Terraform state-loss → KV uri/password drift. See
[[platform-rmq-credential-drift-rotation]] + #1154. Fixed via purge-safe `az keyvault secret
set` rotation.
