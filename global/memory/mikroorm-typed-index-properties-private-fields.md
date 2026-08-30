---
name: mikroorm-typed-index-properties-private-fields
description: "MikroORM v6 @Index/@Unique typed `properties` rejects private _-field names at compile time — cast `as any`"
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000007
---

MikroORM v6 class-level `@Index({ properties: [...] })` / `@Unique({ properties: [...] })` derive their allowed-key union from the entity's **public** shape (getters: `deal`, `dealNumber`, `entityType`), so the **private mapped-field names** (`_deal`, `_dealNumber`, `_entityType`) are **rejected at compile time** with `tsc TS2820: ... Did you mean 'deal'?`.

But the underscore field names are the **correct runtime** property names — every trading-service repo references them as `{ _deal: … } as never` / `populate: ['_deal'] as never`, and the bootstrap harness builds the indexes from them. Using the compiler-suggested non-underscore name would break runtime (no such metadata property).

**Fix:** cast the `properties` array `as any` — e.g. `@Index({ properties: ['tenantId', '_deal'] as any })`. Precedent already in the codebase: `currency.entity.ts` → `@Unique({ properties: ['_code', 'tenantId'] as any })`. Compile-time only; runtime metadata resolution unchanged. (`as any` is lint-clean for Platform entities.)

Gotcha: `lint` and `test:unit`/`test:integration` all pass with the typed (broken) form — only the separate `typecheck` target (`tsc --noEmit`) catches it. The integration harness applies the migration's raw DDL, so runtime "works" while `typecheck` fails. Always run `nx run platform-<svc>:typecheck` after adding entity index/unique decorators. Cost a full CI cycle on #1205/#1211 (2026-06-09). Single-column FK `index: true` on `@ManyToOne` is fine (boolean, no `properties`). See [[feedback_always_use_nx]].
