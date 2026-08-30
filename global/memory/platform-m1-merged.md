---
name: platform-m1-merged
description: M1 Platform Foundation merged to main — PR #215, epic #198 closed, 2026-03-27
type: project
---

M1 Platform Foundation merged to main on 2026-03-27.

**Why:** Sprint 1 (infra) + Sprint 2 (identity services) + Sprint 2.5 (hardening) complete.
**How to apply:** M1 is done. Start M2 with `/pm:prd-new platform-m2-traders-can-execute-deals`.

## Key Facts
- PR #215, squash-merged via admin (legacy CI pre-existing failure on main)
- Epic #198 closed, all 13 issues (#199-#211) closed
- 462 files, +54,280 lines, 687 tests
- Branch `epic/platform-m1-s2` deleted
- 9 ADRs (0013-0021), 7 docs (~5,500 lines), Helm chart, distroless Dockerfile

## What's NOT ready
- AKS deployment: no Terraform for AKS cluster, no ArgoCD, no managed PG/Redis/RabbitMQ
- Helm chart + Dockerfile ready but infra provisioning is M2 scope
- Legacy CI broken on main (legacy-api:build:production, legacy-web:build:production)
- SWC module bug: all .swcrc fixed to "commonjs" (was "nodenext", see platform-swcrc-module-bug.md)
