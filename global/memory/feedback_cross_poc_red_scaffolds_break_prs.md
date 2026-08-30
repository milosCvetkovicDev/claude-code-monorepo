---
name: Cross-POC RED scaffolds on shared base break independent-PR CI
description: When Stream T pre-commits RED test scaffolds for ALL POCs of an issue on the shared parent commit, each downstream POC branch transitively carries the OTHER POC's RED specs — whose imports resolve to modules that only exist on the OTHER branch. Every POC branch then fails CI on cross-POC import errors even though its own work is GREEN.
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000038
---
Pre-committing all-POCs RED scaffolds on a shared base commit means each per-POC PR branch carries the OTHER POCs' RED specs — and those specs import modules from POCs the branch doesn't have. Independent-PR CI breaks even when each POC's own tests are GREEN.

**Why:** during the 2026-05-12 cnpg-outbox issue #698 work, Stream T pre-committed all three RED specs (`outbox-schema-parameterized.tc.spec.ts` for C1-prep, `deal-lock-to-commission.spec.ts` for C1-prep, `audit-entry-no-user-email.spec.ts` for C4) onto commit `89faf615`, intended as the shared parent for both POC PR branches. After history-rewrite, `poc/c4` and `poc/c1-prep` both descended from `89faf615`, so both carried all three scaffolds:

- `poc/c4` had the C1-prep RED specs, which `import { createOutboxEntity } from '.../outbox-entry.factory'` — the factory is only on `poc/c1-prep`. Verified locally with vitest on the specific spec file (GREEN, because module resolution skipped the missing import), but `nx test platform-event-bus` on the full project FAILED in CI with ERR_MODULE_NOT_FOUND.
- `poc/c1-prep` had the C4 RED spec, which `import { UserEmailLookupService } from '.../user-email-lookup.service'` — only on `poc/c4`. Same symmetric failure.

Each PR's CI showed:
```
NX  Running target test for 16 projects failed
Failed tasks:
- platform-audit-service:test     (on poc/c1-prep — C4 spec can't import)
- platform-event-bus:test         (on poc/c4 — C1-prep spec can't import)
```

The local verification didn't catch it because I ran `npx vitest run <specific-spec.tc.spec.ts>` per spec, not `npx nx test <project>` which runs ALL specs in the project.

**How to apply:**

1. **Don't pre-commit RED scaffolds for POCs on a shared base when each POC will be its own independent PR.** Each POC's RED spec belongs on the SAME branch as its GREEN implementation — they ship together.
2. **OR** if you want all RED scaffolds up front (for visibility / planning), commit them to a separate "scaffolds" branch that gets merged AFTER both POC PRs land. Each POC PR branches from BEFORE the all-scaffolds commit.
3. **OR** mark cross-POC specs with `describe.skip` / `it.skip` gated on environment / file existence, so CI doesn't try to compile them on branches missing the impl. This is fragile — prefer (1) or (2).
4. **Always verify with the project-wide test runner before push**: `npx nx test <project>` (not `npx vitest run <file>`). The project-wide runner catches discovery-only failures that single-file invocation skips.

**Symptoms to recognise:**
- Single-spec `vitest run` passes; `nx test <project>` fails.
- Module-not-found errors in CI on imports that LOOK like they should exist (because the file is in the branch).
- Same failure on both PRs of a pair, each blaming the other POC's spec.

**Cross-references:**
- `parallel-sessions.md` §"Quality safeguards" #4: "One POC per PR" — this rule's blast radius extends to *each PR's full test scope*, not just the changed files.
- `agent-skills:test-driven-development` and `superpowers:test-driven-development` — RED-phase scaffolds are good, but they must live in the same commit graph as the GREEN that makes them pass.
- `verification-before-completion` skill — run the same target that CI runs, not a subset.
