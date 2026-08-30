---
name: db-migration
description: 'Create or modify TypeORM database migrations safely with rollback support. Use when the user needs to add, change, or remove database tables, columns, indexes, or constraints. Do not use for querying data or running one-off SQL.'
model: sonnet
---

# Database Migration Workflow

You are orchestrating a database schema change with proper validation and review.

## Workflow Steps

### Step 1: Domain Model Review

Use the **ddd-expert agent** to:

- Verify entity design aligns with aggregates
- Check if new entity should be value object instead
- Ensure proper aggregate boundaries
- Validate entity relationships follow DDD patterns

### Step 2: Design Migration

Use the **database-migration-expert agent** to:

- Design the schema change
- Plan migration strategy (zero-downtime compatible)
- Identify data migration needs
- Consider rollback approach

**Project Requirements:**

- All tables MUST have `tradingCompanyId` for multi-tenancy
- Decimals use `numeric(19,4)` type
- Timestamps use `timestamptz`
- Index on `tradingCompanyId` for every table

### Step 3: Create Migration

Generate or create the migration:

```bash
# Generate from entity changes
npm run typeorm migration:generate -- -d apps/legacy-api/src/data-source.ts apps/legacy-api/src/migrations/MigrationName

# Create empty migration
npm run typeorm migration:create -- apps/legacy-api/src/migrations/MigrationName
```

**Migration Requirements:**

- Reversible `down()` method
- Use `CREATE INDEX CONCURRENTLY` for indexes
- Batch large data updates
- Compatible with running application (zero-downtime)

### Step 4: Update Entity

Update the TypeORM entity to match:

```typescript
@Entity()
export class NewEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'numeric', precision: 19, scale: 4 })
  amount: string; // Decimals as strings

  @Column({ type: 'timestamptz' })
  createdAt: Date;

  // REQUIRED: Multi-tenancy
  @ManyToOne(() => TradingCompany)
  @JoinColumn({ name: 'tradingCompanyId' })
  tradingCompany: TradingCompany;

  @Column()
  tradingCompanyId: string;
}
```

### Step 5: Test Migration

```bash
# Run migration locally
npm run db:migrate

# Verify schema
npm run db  # Opens psql shell

# Test with seed data
npm run db:recreate
```

### Step 6: Code Quality Review

Use the **review-tech-lead agent** to verify:

- Entity follows project patterns
- Repository uses factory pattern with TradingCompany
- Service uses namespace imports

### Step 7: Test Coverage Review

Use the **review-test-architect agent** to verify:

- Tests cover new entity operations
- Integration tests for repository methods
- Multi-tenancy isolation tested

## Zero-Downtime Migration Pattern

For breaking changes, use multi-step approach:

**Step 1 - Add (backward compatible):**

```sql
ALTER TABLE "entity" ADD "new_column" varchar;
```

**Step 2 - Deploy code that writes to both columns**

**Step 3 - Migrate data:**

```sql
UPDATE "entity" SET "new_column" = "old_column" WHERE "new_column" IS NULL;
```

**Step 4 - Deploy code that only uses new column**

**Step 5 - Remove old column:**

```sql
ALTER TABLE "entity" DROP COLUMN "old_column";
```

## Output

Provide:

- Migration file created
- Entity changes made
- Rollback instructions
- Testing verification
- Review findings addressed

---

## Platform Migration (MikroORM)

**Detection:** If the migration targets `apps/platform/` or uses MikroORM entities, use this variant.

### Create Migration

```bash
# Auto-generate from entity changes
nx run {service}:migration:create
# Or manually:
npx mikro-orm migration:create --schema={bc}
```

### Entity Convention

- Extends `TenantBaseEntity` (unless TENANT_EXEMPT)
- `@Entity({ schema: '{bc}' })` + `@Filter({ name: 'tenant', ... })`
- Decimals: `@Property({ type: DecimalType, columnType: 'numeric(19,4)' })`
- Timestamps: `@Property({ type: 'timestamptz' })`

### K8s Deployment

Migrations run as init container before service starts (ADR-0015):

```yaml
initContainers:
  - name: migrate
    command: ['npx', 'mikro-orm', 'migration:up']
```

### Run Locally

```bash
nx run {service}:migration:up
nx run {service}:migration:pending  # Check what's pending
```


## Assumptions Gate

Before starting implementation, explicitly state your assumptions:

```
ASSUMPTIONS:
- [ ] {assumption about requirements}
- [ ] {assumption about architecture}
- [ ] {assumption about scope}
→ Correct me now or I will proceed with these.
```

Present assumptions as a checkbox list. Wait for user confirmation before proceeding. Do not silently fill in ambiguous requirements.
