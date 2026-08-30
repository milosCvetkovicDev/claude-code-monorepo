---
name: platform-image-build-uami-epic-pending
description: Pre-prod-readiness Platform image-build UAMI work scoped under
metadata: 
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000008
---

Tracking issue **#963** scopes the dedicated per-environment `platform-image-build-identity` UAMI work (one UAMI per env with AcrPush scoped to that env's Platform ACR only). Filed 2026-05-27 after a cascade of inline → composite consolidation PRs (#953/#954/#955/#960) cleaned up the *workflow* surface but left the *identity* surface still overloaded (one `AZURE_CLIENT_ID_RUNNER_IMAGE` UAMI doing double duty for the runner VM image AND every Platform service container image, with no env isolation).

**Why this is a tracking issue, NOT yet an epic:** The body is sized for triage (1-2 week L-sized estimate, 6 ACs, references to #669 + #481 + ADRs to write). Before implementation begins it MUST go through the full PM ceremony — `prd-new platform-image-build-uami` → `prd-parse` → `arch-create` → `epic-decompose` → `tests-generate` → `readiness-check` → `epic-sync`. Treat #963 as the parking lot; the epic will be a new artifact under `.claude/prds/` + `.claude/epics/` when prioritized.

**Why:** [[no-platform-to-prod]] keeps the existing legacy stack on prod-acme-legacy untouched; the dedicated UAMI is for ANY future Platform environment beyond dev-platform. It does NOT block #669 (which scopes out "any new code changes" and verifies against dev-platform only). It is NOT on M6's (#481) current critical path either — M6 is the legacy launch, frozen on #483. The link to M6 is forward-looking: if/when M6 unblocks and the cutover plan is later amended to include a Platform pivot, #963's work must land before per-env identity can be exercised in pre-prod. Cross-reference comment filed on #481 as a breadcrumb for that future cutover-rehearsal checklist.

**How to apply:**
- If user asks for "the UAMI epic" or "the Platform image-build UAMI work", point them at #963 first; then propose `prd-new platform-image-build-uami` to convert it into a proper PM artifact before any code lands.
- If user mentions any future Platform pre-prod environment (pre-prod-platform ACR, pre-prod-platform AKS, Platform cutover within M6 unblock), surface #963 as a prerequisite.
- If user touches the existing `AZURE_CLIENT_ID_RUNNER_IMAGE` secret (e.g. the sibling rename follow-up `RUNNER_IMAGE` → `IMAGE_BUILD`), confirm that's hygiene-only and DOES NOT supersede the architectural work in #963.
- Sibling follow-up: rename `AZURE_CLIENT_ID_RUNNER_IMAGE` → `AZURE_CLIENT_ID_IMAGE_BUILD` (legacy use case, no architectural change). Tracked separately, no GitHub issue yet — user is gated on `gh secret set` authorization before that PR can land.
- Initially filed as a sub-issue of #669 (per first read of "Connect #5 → #669"), then detached 2026-05-27 after re-checking #669's scope which explicitly excludes new code/ADRs. The relationship is "shared pre-prod-readiness lineage", not "blocker". #963 is now a standalone task with cross-references to #669 + #481.

**References:**
- Tracking issue: https://github.com/initech-trading-platform/acme/issues/963
- Cross-ref breadcrumb filed on M6 epic #481 (comment id 4554777386, 2026-05-27)
- Upstream cleanup PRs: #953 (ACR OIDC + AcrPush UAMI swap), #954/#955 (inline → composite sweep), #960 (azure/login v3 bump)
