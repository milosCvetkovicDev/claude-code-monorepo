---
name: typeorm-cascade-save-bug
description: TypeORM cascade:true + spread operator causes silent save failures — a subset of rows kept a stale status, fixed PR #263
type: project
---

## TypeORM Cascade + Spread = Silent Status Update Failure

**Symptom:** rows that should have advanced to the next status silently kept the old one. Nothing threw, nothing logged, no error path ever fired — the drift surfaced only when a person read a screen and disagreed with it.

**Scale:** a subset of the affected rows had carried the stale status ever since the cascade relation was introduced. Silent means silent: elapsed time, not detection, bounded the blast radius.

**Root cause:** the update used `{ ...entity, status: NEXT }` with `.save()`. The spread copied every loaded relation onto the object handed to TypeORM. Combined with `cascade: true` on a relation two levels down, TypeORM tried to cascade-save the entire loaded graph. That silently failed for the rows with the biggest graphs — the stuck rows had markedly more child rows on average than the ones that updated correctly. **A failure that scales with graph size looks exactly like a random subset**, which is why the pattern reads as flakiness rather than a bug.

**Why only one entity:** the sibling entities carry NO `cascade: true`, so none of them were affected — the blast radius was exactly the set of entities with a cascade relation.

**Fix (PR #263):** all 5 creation functions changed to pass `{ id, status }` only. Code review on the same diff caught a second defect of the same family: a `as X` return-type cast hiding a partial object, which had silently broken a downstream webhook.

**Repairing the drift:** a one-off UPDATE joined the stale table to the table that proves the transition already happened, so the repair derived the correct state from data rather than from a hand-written list of ids.

**Why:** Never spread a TypeORM entity into `.save()` when the entity has `cascade: true` relations. Pass only the fields you want to update.

**How to apply:** When writing `.save()` calls for status updates, always use the `{ id, status }` pattern. Grep for `...entity.*status` + `.save()` to find similar call sites. ADR-0012 documents this decision, and a scheduled reconciliation script re-checks the invariant so a silent recurrence is caught by the system rather than by a person.
