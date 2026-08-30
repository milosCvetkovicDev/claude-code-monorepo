---
checked: 2026-07-02T11:48:08Z
epic: platform-trading-hardening
verdict: READY
critical_count: 0
major_count: 1
minor_count: 5
fr_coverage: 100%
overridden: false
note: CRITICAL-1 RESOLVED 2026-07-02T12:19:42Z — RED suite landed and was independently verified (10 features/25 scenarios, 9 tc specs, 5 unit stubs, 1 message-pact, manifest; zero existing files modified; import-RED targets confirmed absent; typecheck fails with exactly the 5 expected missing-module errors).
---

# Readiness Report: platform-trading-hardening

## FR Coverage Matrix

Every FR is covered by one implementation task **plus** task 001 (RED tests) and task 010 (production verification) — no single-touchpoint FRs.

| FR ID | PRD Requirement | Task Coverage | Status |
| ----- | ----------------------------------------------------- | ----------------- | ------ |
| FR-1  | Consume `accounting.invoice.processed` → transition    | 001, **002**, 010 | Full |
| FR-2  | Trading inbox (transactional dedup)                   | 001, **002**, 010 | Full |
| FR-3  | Parked messages (never drop / never crash-loop)       | 001, **002**, 010 | Full |
| FR-4  | Inventory consumer idempotency | 001, **003**, 010 | Full |
| FR-5  | Quota-check serialization (concurrent-claim race)     | 001, **004**, 010 | Full |
| FR-6  | Optimistic locking (version, 409 STALE_WRITE)         | 001, **005**, 010 | Full |
| FR-7  | Idempotency-Key on state-changing mutations | 001, **005**, 010 | Full |
| FR-8  | Soft delete across the trading schema | 001, **006**, 010 | Full |
| FR-9  | Delete/cancel audit entries | 001, **006**, 010 | Full |
| FR-10 | List server-side filters + derived status in payload  | 001, **007**, 010 | Full |
| FR-11 | Command endpoints for the missing transitions | 001, **008**, 010 | Full |
| FR-12 | New child-entity fields + ownership validation | 001, **008**, 010 | Full |
| FR-13 | Bounded batch action + CSV export                     | 001, **007**, 010 | Full |
| FR-14 | Integration-pipeline observability | 001, **009**, 010 | Full |
| FR-15 | Tenant-config wiring audit | **009**, 010      | Full |

**Coverage: 100% (15/15 Full)**

## Findings

### CRITICAL (0) — resolved

1. **DDD Phase D — epic BDD scenarios not yet on disk.** The existing trading `.feature` files cover the core flows, not this epic's acceptance features. `/pm:tests-generate` is generating them **right now** (agent in flight, launched 11:46 UTC). **Resolution path: wait for landing + independent verification; this report will be updated and the verdict flipped to READY. Do NOT override.**

### MAJOR (1)

1. **Rule 10 — Example Mapping not extended for the hardening rules (Core BC).** `example-maps/trading/` has maps for the core flows but none for the write-back, the serialized quota check, idempotency, or soft delete. Mitigation: the PRD Gherkin carries concrete worked examples for each of those (a two-writer race on one quota, a version 3-vs-4 stale write, a reused idempotency key), which encode the same intent an example map would. Recommended fix during task 001: add `example-maps/trading/hardening-{writeback,concurrency,governance}.md` (~1 h), not blocking.

### MINOR (5)

1. **Phase E use-case mapping not extended** — the DDD use-case register lags the commands this epic adds (the batch action, the new lifecycle commands, the explicit create, the export). Update during implementation; a register that drifts silently stops being a gate.
2. **Context map missing the new consume edge** — `context-mapping/context-map.md` has no Trading⇐Accounting relationship (architecture.md §6.1 documents it). Sync during task 002.
3. **DDD artifact location drift** — trading artifacts live under `docs/platform/ddd/context-mapping/…` while the gate's canonical root is `docs/platform/context-mapping/…` (both trees exist). Consolidation is a docs chore, out of epic scope.
4. **Migration numbering placeholders** — tasks 005/006/008 say "renumber to next free"; coordinate at implementation to avoid collisions across parallel worktrees.
5. **Test manifest pending** — arrives with the in-flight generation.

## Validation Checks

| Check | Result |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. User-facing value | PASS — 002–008 deliver user-visible correctness; 001 is the mandated test-first task; 009 operator-facing; 010 verification |
| 2. Forward dependencies | PASS — all `depends_on` internal + backward (001 → impl → 009 → 010); external dep (accounting events) is MERGED work; #1548/#1549/#1581 referenced, not depended on |
| 3. BDD acceptance criteria | PASS — every task has `(AC: n)` cross-refs mapped to PRD Gherkin |
| 4. Architecture cohesion | PASS — every task references architecture.md §X.Y and/or ADR-0066/0067/0068 (grep-verified); file patterns match architecture §4                                                                                                                                                  |
| 5. Cross-epic dependencies | PASS — no dependency on in-progress epics; #1439 (FE) consumes this epic, not vice versa; the ADR-numbering conflict with an in-flight branch was pre-empted (0065 reserved)                                                                                                          |
| 6. DDD pipeline (Core BC)      | A ✓ · A.1 ✓ · A.2 ✓ · B ✓ · C ✓ · C.1 ✓ (aggregates + architecture §6.5) · D.0 ⚠ MAJOR-1 · **D ✗ CRITICAL-1 (in flight)** · E ⚠ MINOR-1 · F = this epic |
| 7. Context map completeness | PASS with MINOR-2 (edge to add; pattern named in architecture §6.1: Published Language)                                                                                                                                                                                           |
| 8. ACL for legacy | N/A — no legacy involvement |
| 9. Domain event infrastructure | PASS — outbox inherited (ADR-0018/0037); inbox decided (ADR-0068); **the event catalog already carried the inbound contract at v1 with trading-service listed as a consumer**, so this epic implements against a published contract rather than inventing one; epic produces no new events |
| 10. Example mapping | ⚠ MAJOR-1 (see above)                                                                                                                                                                                                                                                             |
| 11. K8s manifests | PASS — no new services; existing trading/inventory charts unchanged; RabbitMQ topology is an operator-applied addition documented in tasks 002/010                                                                                                                                |
| 12. Event contract validation | PASS — contract exists in `libs/platform/event-contracts` (grep-verified); v1 + tenantId per catalog; consumer idempotency guard is FR-2 (the epic's core)                                                                                                                           |

## Verdict

**READY (0 CRITICAL, 1 MAJOR, 5 MINOR)** — the sole CRITICAL (Phase D) resolved at 12:19 UTC: the RED suite landed (60 test cases across 4 layers) and was independently verified — file counts match the manifest, zero existing test files modified, the five import-RED module targets confirmed absent, both services' typechecks fail with exactly the expected missing-module errors and nothing else. Also of note: writing the RED specs against the contract surfaced that the implementation returned a different error code and HTTP status than the contract specifies for a rejected write — the kind of drift only a test written from the contract catches. Task 004 includes the remap.

## Next Steps

1. Await the tests-generate agent; independently verify (file glob, manifest review, spot-run one unit spec, RED-reason audit).
2. Update this report: verdict → READY, critical_count → 0.
3. (Optional, recommended) fold MAJOR-1 example-maps into task 001's scope — 1 h.
4. Proceed: `/pm:epic-sync platform-trading-hardening`.
