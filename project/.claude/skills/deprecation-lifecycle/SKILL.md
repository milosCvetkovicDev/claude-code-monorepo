---
name: deprecation-lifecycle
description: 'Manage structured code deprecation: detect candidates, create records, track migration, enforce removal gates, and scan for zombie code. Use when removing old code, migrating from legacy to Platform, or cleaning up unused exports.'
---

# Deprecation Lifecycle

Structured 4-phase workflow for safely deprecating and removing code.

## Invocation

- `/deprecation-lifecycle detect` — Find deprecation candidates
- `/deprecation-lifecycle deprecate <name>` — Create deprecation record and mark code
- `/deprecation-lifecycle status [name]` — Show migration progress
- `/deprecation-lifecycle remove <name>` — Remove deprecated code (with gate check)
- `/deprecation-lifecycle scan` — Find zombie code (unused exports, stale packages)

## Phase 1: Detect

Find code that should be deprecated.

### Detection Methods

1. **Legacy/Platform duplicates** — Code in `apps/legacy-api/` that has a replacement in `apps/platform/`

   ```bash
   # Compare Express routes vs NestJS controllers
   grep -rn "router\.\(get\|post\|put\|delete\)" apps/legacy-api/src/ | head -20
   grep -rn "@\(Get\|Post\|Put\|Delete\)" apps/platform/ | head -20
   ```

2. **Unused exports** — Symbols exported but not imported anywhere

   ```bash
   npx nx graph --file=/tmp/nx-graph.json
   # Analyze the graph for orphaned nodes
   ```

3. **Stale feature flags** — Flags that are always on or always off
   ```bash
   grep -rn "FEATURE_\|featureFlag\|isEnabled" --include='*.ts' apps/ libs/
   ```

### Output

List each candidate:

```
Deprecation candidate: {name}
  Type: legacy-migration | api-version | dead-code
  Location: {file:line}
  Reason: {why this should be deprecated}
  Replacement: {path to replacement or "none"}
```

## Phase 2: Deprecate

Create a formal deprecation record and mark the code.

### Step 1: Create Record

Create `docs/deprecations/{name}.md`:

```yaml
---
name: {identifier}
type: legacy-migration | api-version | dead-code
status: deprecated
deprecated_date: {ISO date}
removal_target: {ISO date or "when consumers reach zero"}
replacement: {path to replacement code}
consumers:
  - {file that imports/uses this}
  - {another consumer}
migration_guide: |
  1. Replace import of {old} with {new}
  2. Update call signature: {old sig} → {new sig}
  3. Run tests to verify
---

# Deprecation: {name}

## What is deprecated
{description of the deprecated code}

## Replacement
{description of the replacement and how to use it}

## Migration Steps
{step-by-step migration guide}
```

### Step 2: Mark Code

Add `@deprecated` JSDoc to all exported symbols:

```typescript
/**
 * @deprecated Use {replacement} instead. See docs/deprecations/{name}.md
 * Removal target: {date}
 */
export function oldFunction() { ... }
```

For API endpoints, add a dev-mode warning:

```typescript
if (getEnvVar('NODE_ENV') === 'development') {
  // Use env helper, not process.env directly
  console.warn(`DEPRECATED: ${req.path} — use ${replacement} instead`);
}
```

### Step 3: Update Record Status

Set `status: deprecated` in the record frontmatter.

## Phase 3: Migrate

Track consumer adoption of the replacement.

1. List current consumers: `grep -rn "import.*{old}" --include='*.ts' apps/ libs/`
2. As each consumer migrates, remove from the `consumers` list in the record
3. Update `status: migrating` when migration work begins
4. Track progress in the record body

## Phase 4: Remove

Remove deprecated code after passing the removal gate.

### Removal Gate

ALL conditions must be true:

| Condition | Check |
| ----------------------------- | ----------------------------------------------------------------------- |
| Zero active consumers | `grep -rn "import.*{old}" --include='*.ts' apps/ libs/` returns nothing |
| Replacement exists and tested | Replacement file exists; its tests pass |
| Migration guide exists | `docs/deprecations/{name}.md` has migration steps |
| Deprecated for ≥ 2 weeks | `deprecated_date` is at least 14 days ago |

If ANY condition fails:

```
❌ Removal gate failed for {name}:
  - [ ] Zero consumers (found: {list of remaining consumers})
  - [x] Replacement tested
  - [x] Migration guide exists
  - [ ] Deprecated ≥ 2 weeks (deprecated {N} days ago)
```

If ALL conditions pass:

1. Delete the deprecated code
2. Remove any dev-mode warnings
3. Update record: `status: removed`, add `removed_date`
4. Commit with message: `chore: remove deprecated {name} — see docs/deprecations/{name}.md`

## Zombie Detection Scan

Find potentially dead code that nobody owns.

### Checks

1. **Unused exports** — Exported symbols not imported elsewhere:

   ```bash
   # For each exported symbol, check if it's imported
   grep -rn "export " --include='*.ts' libs/ | while read line; do
     symbol=$(echo "$line" | grep -oP 'export (function|class|const|type|interface) \K\w+')
     if [ -n "$symbol" ]; then
       count=$(grep -rn "$symbol" --include='*.ts' apps/ libs/ | grep -v "export" | wc -l)
       if [ "$count" -eq 0 ]; then
         echo "ZOMBIE: $symbol in $line"
       fi
     fi
   done
   ```

2. **Unreferenced files** — Files not imported by any other file:

   ```bash
   # Check Nx dependency graph for orphan nodes
   npx nx graph --file=/tmp/nx-graph.json
   ```

3. **Unused npm packages** — Packages in package.json not imported in source:
   ```bash
   npx depcheck --ignores="@types/*,eslint-*,prettier,husky"
   ```

### Output

```
Zombie scan results:
  Unused exports: {count}
  Unreferenced files: {count}
  Unused packages: {count}

Top candidates for review:
  1. {symbol} in {file} — 0 consumers
  2. {package} — not imported in source
```

## Integration with PM Workflow

Deprecation records can be converted to tracked issues:

1. Create deprecation record (Phase 2)
2. Create a GitHub issue referencing the record
3. Track migration progress in the issue
4. Close issue when removal gate passes (Phase 4)
