---
name: platform-deploy-trigger-and-writeback
description: "How Platform services actually reach dev-platform — deploy is NOT automatic on main merge, and the deploy job's GitOps writeback to main is branch-protection-blocked; image-tag bumps go via manual PR"
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000007
---

How a merged Platform PR actually rolls to **dev-platform** (learned 2026-06-09 doing #1200 AC#4).

**1. Deploy does NOT auto-fire on a main merge.** `platform-pipeline.yml`'s
`resolve` job sets `run_deploy=true` ONLY for `workflow_dispatch` with the
`deploy=true` input; a **main push gets `run_deploy=false`** (auto-deploy-on-main
is intentionally still commented out — a planned future flip, lines ~182-190).
So merging a Platform PR **builds + pushes the image to ACR but does not roll it**.
Trigger the deploy manually:
`gh workflow run platform-pipeline.yml --ref main -f sha=<merge-sha> -f deploy=true -f environment=development`

**2. The deploy job's GitOps writeback to main is currently BROKEN.**
`_deploy.yml`'s "Update image tags on main" step commits the image-tag bump to
`charts/bundles/<bc>-bundle/values.yaml` via the GitOps-pusher App, then
`git push origin main` → **rejected by branch protection**:
`GH006 … 3 of 3 required status checks are expected … protected branch hook
declined`. Affects EVERY Platform deploy (build/Trivy pass first).

**Root cause is REQUIRED STATUS CHECKS, not identity/permissions** (verified
2026-06-09 via #1207 expert review + live API + GitHub docs). `main` is on
**classic** branch protection (NO rulesets): 3 required checks (`Validate
Terraform`, `ci-gate`, `platform-ci-gate`, strict) **+ 1 review**, `enforce_admins=
false`. On classic protection, **required status checks have NO per-actor bypass
and gate direct pushes too** → any non-admin push (App, github-actions[bot],
human) is rejected identically. Classic `bypass_pull_request_allowances` (POC-1
#670) exempts only the PR/review rule, NOT status checks. So "register the App
as a bypass actor" (the original #1207 ask, and the #747 runbook's old
"Branch protection compatibility" wording) is **WRONG/impossible on classic
protection** — #747 runbook just gives an audit identity, not a bypass.
**Durable fixes:** (a) institutionalize the manual admin bump-PR (#1206/#1035),
or (b) migrate `main` classic→**ruleset** with the App as a bypass actor (rulesets
DO exempt from status checks; delete classic rule only after verifying). The
ONLY classic lever is admin + enforce_admins=false (how human admin-merges work).
Tracked: #1207. Docs corrected in #1210 (runbook + ADR-0032 erratum).

**3. Working remediation = manual image-tag bump PR.** Edit
`charts/bundles/<bc>-bundle/values.yaml` → `<svc>.image.tag: sha-<short>`, open a
normal PR, merge (checks run; charts-only is usually CLEAN, no admin needed).
ArgoCD does the rest. Pattern used by #1035 and #1206. (`sha-<short>` = first 7
of the merge SHA, e.g. `sha-8bb893e`.)

**4. ArgoCD auto-syncs.** Each BC Application (`platform-<bc>`, ns `argocd`) has
`syncPolicy.automated {prune:true, selfHeal:true}`, `targetRevision: main`. It
reconciles `main` (~3 min poll) and rolls the new tag — no manual sync needed.

**5. Deploy gate is prod-only for time windows.** `_deploy.yml` weekend +
business-hours (08:00-17:00 UTC) blocks are gated on `ENVIRONMENT=production`;
**dev only blocks on the `DEPLOYMENT_FREEZE` repo var** (not set).

**6. Migrations run in an init-container, not on bootstrap.** values have
`migrations.enabled: true` + `SKIP_BOOTSTRAP_MIGRATIONS: 'true'` → the
`migrations` init-container runs `migrate-cli` (`@acme/service-bootstrap`)
applying pending MikroORM migrations; the app itself skips them. Verify a
migration landed via `kubectl -n platform-<bc> logs <pod> -c migrations`.

Verifying a BC read-path without DB creds: direct **header-identity smoke** —
`kubectl port-forward svc/platform-<bc>-<svc> L:PORT`, then
`curl -H 'x-tenant-id: <uuid>' -H 'x-user-id: <uuid>' …/api/v1/<resource>`
(gateway is the trust boundary; BC services trust those headers). A 200 (even
empty) vs 500 proves tables exist. Decoding the `DATABASE_URL` secret / `exec`
running a query with it is classifier-blocked — use the HTTP smoke instead.
See [[no-platform-to-prod]], [[platform-redesign-topology]].

---

**Update 2026-06-29 (identity sha-a7830a2 deploy):**

- **Pipeline `deploy=true` targets nx-AFFECTED services only.** `_deploy.yml`'s
  "Resolve target services" deploys only services changed in the dispatched SHA's
  diff; build-push likewise only PUSHES affected images (unchanged-service legs go
  green but no-op). So a service UNCHANGED in the SHA (e.g. identity when the SHA's
  only change is reporting) is NOT redeployed AND gets no new image — even though
  its running tag is stale. ACR proof: dispatching `c1f58c8` pushed `sha-c1f58c8`
  for reporting-service ONLY; auth/user/tenant still had just their old
  `sha-e6a9563`. → To roll an UNCHANGED service onto a newer build, bump its bundle
  tag to a **pre-existing** tag (its last affected build) via the manual bump PR
  (§3) — the pipeline cannot target it. Verify the image exists in ACR first:
  `az acr repository show-tags --name developmentacmeacr --repository <svc> --orderby time_desc --top 10`.
- **`gh workflow run -f sha=` needs the FULL 40-char SHA.** A short sha (e.g.
  `a945f88c`) fails the CI checkout: `##[error]A branch or tag with the name
'a945f88c' could not be found` (actions/checkout treats a non-40-char ref as a
  branch/tag name). Pass the full SHA, or omit `sha` (defaults to dispatch-ref HEAD).
- **Trivy can block a deploy via an UNRELATED service.** build-push fails if any
  affected service's image fails Trivy (HIGH/CRITICAL), skipping deploy. Dev
  unblock = dispatch with `-f skip_trivy=true` (informational gate); fix the CVE
  separately. (2026-06-29: `linkify-it` CVE-2026-48801 on reporting-service blocked
  it; fixed via root `overrides` bump + dual-lockfile regen, #1489.)
- **Current dev-platform identity state:** auth/user/tenant on `sha-a7830a2` (deployed
  via #1488; migration pre-sync job OK; `POST /api/v1/auth/login` returns 401 on bad
  creds — was 404 on the stale `sha-e6a9563`). reporting-service on `sha-c1f58c8`
  (#1490). Live URL `https://dev.platform.acme-example.co.uk`; `/health` 200 at ROOT (not
  `/api/v1/health`).
- **Writeback still blocked** — re-confirmed live: `_deploy.yml` "Update image tags
  on main" failed → "Wait for ArgoCD sync" skipped → nothing rolled. Durable-fix
  issue re-filed as **#1487** (likely DUP of #1207 from this file). The deploy job
  DOES auto-open a writeback PR (e.g. #1490) but cannot auto-merge it.
- **auth-service input-validation gap** (surfaced by this deploy, masked by the 404):
  request DTOs had no class-validator decorators + no global `ValidationPipe` → a
  malformed login (missing `tenantId`) 500'd instead of 400. Fixed #1492 / #1493.

---

**Update 2026-07-17 (identity hardening batch — the writeback fails PARTIALLY, per-bundle):**

- **The writeback is per-bundle and can die mid-way — some affected services ship,
  others silently don't.** A single `deploy=true` dispatch at a SHA touching services
  in TWO bundles (tenant-service→identity-bundle, audit-service→ops-bundle) built BOTH
  images fine (ACR had `tenant-service:sha-b08953f` AND `audit-service:sha-f59789a` —
  note **each service is tagged by its OWN nx content-hash / last-change SHA, NOT the
  dispatched SHA**), but the writeback step opened ONLY the identity-bundle PR (#1700)
  then the job errored on the GH-App-identity limit before creating the ops-bundle PR.
  Net: tenant shipped, **audit-service was silently left on its old tag** — and the
  job's red "Deploy to AKS" conclusion looked like the usual writeback false-negative.
  **Do NOT judge a deploy by "images built" or by the job conclusion — enumerate the
  per-service chart tags vs the running rollout image for EVERY affected service.**
  Probe: `kubectl -n platform-<ns> get rollout <rollout> -o jsonpath='{.spec.template.spec.containers[0].image}'`
  and compare to `az acr repository show-tags --repository <svc>`. The fix was a manual
  ops-bundle bump PR (#1701, §3 pattern) pinning `audit-service.image.tag: sha-f59789a`.
- **ops-bundle Application is `platform-ops` (auto-sync prune+selfHeal), like the others**
  — a merged bump PR rolls within ~3min, no manual sync. (Contrast: `platform-frontend`
  is manual-sync — needs an Application-CR patch to trigger.) The bundle→app→ns map
  seen this session: identity-bundle→`platform-identity`, ops-bundle→`platform-ops`
  (audit-service, reporting-service), comms-bundle→`platform-comms` (notification).
- **`--delete-branch` on a squash-merge of a workflow-spawned PR fails to delete the
  LOCAL branch** when a `.claude/worktrees/wf_*` worktree still holds it — harmless
  (remote branch IS deleted), but clean up with `git worktree remove --force <path>`
  then `git branch -D <branch>` so the next merge's cleanup is quiet. See
  [[feedback_gh_pr_merge_delete_branch_worktree_quirk]].
