# CLAUDE.md - Data Seeding Library

Library-specific instructions for Claude Code. See also the parent `../../CLAUDE.md` for project-wide conventions.

> **Note**: For comprehensive documentation with architecture diagrams, ADRs, and detailed examples, see [README.md](./README.md).

## Overview

`@acme/data-seeding` is a Clean Architecture library for generating realistic fake data for testing and development. It provides type-safe factories for all Acme entities without compile-time dependencies on `legacy-api`.

## Quick Reference

```bash
# Build the library
npx nx build data-seeding

# Run tests
npx nx test data-seeding

# Run specific test
npx nx test data-seeding --testPathPattern=BaseFactory

# Seed remote database (run locally, connect to Azure DB via env vars)
npx nx run legacy-api:db:seed:fake:fast
```

## AI Assistant Guidelines

### When Modifying This Library

1. **Never import from legacy-api** - Use runtime entity injection pattern
2. **Domain layer has zero dependencies** - No TypeORM, Faker, or external imports
3. **All factories extend BaseFactory or ContextualBaseFactory**
4. **Use `big.js` for all decimal calculations** - Never use native JS numbers for money/quantity
5. **Non-nullable relations are sacred** - a factory must never emit a child whose required parent link is unset

### Common Tasks

#### Adding a New Factory

```typescript
// 1. Define entity interface in the factory file
export interface NewEntityEntity {
  id?: number;
  name: string;
  tradingCompany: TradingCompanyEntity;
  // ... only fields the factory needs
}

// 2. Define options interface
export interface NewEntityOptions {
  name?: string;
}

// 3. Extend BaseFactory (or ContextualBaseFactory for child entities)
export class NewEntityFactory<T extends NewEntityEntity> extends BaseFactory<T, NewEntityOptions> {
  private tradingCompany?: TradingCompanyEntity;

  withTradingCompany(tc: TradingCompanyEntity): this {
    this.tradingCompany = tc;
    return this;
  }

  build(options?: NewEntityOptions): T {
    const entity = new this.entityClass();
    entity.name = options?.name ?? this.generator.companyName();
    entity.tradingCompany = this.tradingCompany!;
    return entity;
  }

  reset(): void {
    this.tradingCompany = undefined;
  }
}

// 4. Export from infrastructure/factories/index.ts
// 5. Add to EntityClasses interface in FakeDataSeeder if needed
```

#### Adding a Contextual Factory (Child Entity)

```typescript
// For entities that REQUIRE parent context at creation time
export interface LineItemContext {
  parent: ParentEntity;
  product: ProductEntity;
}

export class LineItemFactory<T extends LineItemEntity> extends ContextualBaseFactory<
  T,
  LineItemContext,
  LineItemOptions
> {
  build(context: LineItemContext, options?: LineItemOptions): T {
    const entity = new this.entityClass();
    entity.parent = context.parent;
    entity.product = context.product;
    entity.quantity = options?.quantity ?? this.generator.number(10, 100);
    return entity;
  }
}
```

#### Modifying FakeDataSeeder

When adding new entities to the seeder:

1. Add entity class to `EntityClasses` interface
2. Initialize factory in constructor
3. Add creation logic in correct dependency level order
4. Update `SeedResult` interface with new count
5. Update `estimateEntityCounts()` in SeedConfig.ts

#### Adding a New Seed Configuration

```typescript
// In application/seeders/SeedConfig.ts
export const CUSTOM_CONFIG: SeedConfig = {
  randomSeed: 99999,
  tradingCompanies: 4,
  usersPerCompany: 10,
  customersPerCompany: 50,
  // ... all required fields
};
```

### Test Patterns

```typescript
describe('NewEntityFactory', () => {
  let factory: NewEntityFactory<MockEntity>;
  let mockDataSource: DataSource;
  let mockGenerator: IDataGenerator;

  beforeEach(() => {
    mockDataSource = createMockDataSource();
    mockGenerator = new FakerDataGenerator(12345); // Deterministic
    factory = new NewEntityFactory(mockDataSource, mockGenerator, MockEntity);
  });

  afterEach(() => {
    factory.reset();
  });

  it('should build entity with defaults', () => {
    factory.withTradingCompany(mockCompany);
    const entity = factory.build();
    expect(entity.tradingCompany).toBe(mockCompany);
  });

  it('should respect provided options', () => {
    factory.withTradingCompany(mockCompany);
    const entity = factory.build({ name: 'Custom' });
    expect(entity.name).toBe('Custom');
  });
});
```

## Architecture

### Clean Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  FakeDataSeeder (orchestrator), SeedConfig (configurations) │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                     Domain Layer                             │
│  Re-exports from @acme/domain-types:                       │
│    Interfaces, Value Objects, Services, Errors               │
│  *** NO EXTERNAL DEPENDENCIES ***                           │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                        │
│  FakerDataGenerator, BaseFactory, 26+ Factory Classes       │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Test Data Layer                           │
│  test-data/uk/: UK banking, geography, company fixtures     │
│  test-data/trading/: Prices, status distributions, FX       │
│  *** SEEDING-ONLY - NOT FOR PRODUCTION ***                  │
└─────────────────────────────────────────────────────────────┘
```

### Runtime Entity Injection Pattern

The library uses **runtime entity injection** to avoid circular dependencies:

```typescript
// Library defines minimal interface (no TypeORM decorators)
export interface CustomerEntity {
  id?: number;
  name: string;
  // ... only fields the factory needs
}

// Factory is generic over entity type
export class CustomerFactory<T extends CustomerEntity> extends BaseFactory<T, Options> {
  constructor(
    dataSource: DataSource,
    generator: IDataGenerator,
    entityClass: ObjectType<T> // Actual class passed at runtime
  ) {
    super(dataSource, generator, entityClass);
  }
}

// legacy-api injects actual TypeORM entities
const factory = new CustomerFactory(dataSource, generator, Customer);
```

### Factory Types

| Type | Base Class | Use Case |
| ---------- | -------------------------------- | ------------------------------------------- |
| Standalone | `BaseFactory<T, O>`              | Entities with context via `withX()` methods |
| Contextual | `ContextualBaseFactory<T, C, O>` | Child entities requiring parent context |

### Entity Dependency Hierarchy

Understanding creation order is critical. The seeder groups entities into dependency
**levels** and creates them level by level: level 0 is reference data that depends on
nothing, each later level may only reference entities from a level already created, and
line-item / invoice style leaves come last. `FakeDataSeeder` encodes that order once, so a
new entity is placed by asking "what must already exist for this row to be insertable?"
rather than by where it happens to be convenient in the code.

The map it encodes:

```
Level 0: Currency, ErpCompany
    │
Level 1: TradingCompany, Unit, Country, User, AccountingMonth, ExchangeRate
    │     ErpCurrency, ErpNominalCode, ErpVatCode
    │
Level 2: Customer, ProductGroup, BankAccount, Deal
    │     ErpCustomer, ErpSupplier, ErpBank
    │
Level 3: Product, CustomerSite, CustomerContact, Purchase, Sale
    │     Haulage, Overhead, PurchaseCreditNote, SaleCreditNote, ErpSupplierBank
    │
Level 4: PurchaseLineItem, SaleLineItem (each SaleLineItem MUST link to a PurchaseLineItem)
    │
Level 5: PurchaseInvoice, SaleInvoice, HaulageInvoice, OverheadInvoice
    │
Level 6: CreditNoteInvoice variants
```

Two things the shape tells you, before you read a line of the seeder. Mirrored external-system
rows (the `Erp*` entities) sit at the same level as the local entities they shadow, not below
them, because nothing local depends on them — they are a parallel spine, joined by code at
level 2+. And the leaves are invoices, which is why an invoice is the entity most likely to be
seeded orphaned: everything it needs already exists, so creating it succeeds and only the read
path notices.

## Key Architectural Constraints

### Non-Nullable Relations (CRITICAL)

Where a child entity's parent relation is not nullable, the factory must take that parent
as **context**, not as an option — a factory that lets the caller forget it produces rows
the database rejects (or worse, accepts with a placeholder):

```typescript
// The required parent is part of the context argument, so it cannot be omitted
const childLineItem = await childLineItemFactory.create(
  { parent, requiredParentLineItem, currency, priceUnit }, // required, not optional
  { quantity: 50, price: 300 }
);
```

Domain services then validate the aggregate-level invariants over those links (see
[Domain Services](#domain-services)).

### Aggregates Reached Through Their Children (CRITICAL)

Some aggregates are read through a child rather than through a direct relation: the
serializer reaches its data via `lineItems[0].<parent>` and throws if the collection is
empty. Two consequences, both of which have bitten this seeder:

1. **Creating the parent row alone is NOT enough** — you must also link its children
2. **The API 500s**, rather than returning an empty shell, when the link is missing — the
   getter throws instead of returning `null`

```typescript
// WRONG - creates an orphan row that causes API 500 errors
await invoiceFactory.create({ tradingCompany });

// CORRECT - link the children to the row you just created
const invoice = await invoiceFactory.create({ tradingCompany });
for (const lineItem of parent.lineItems) {
  lineItem.invoice = invoice;
}
await dataSource.getRepository(LineItem).save(parent.lineItems);
```

`FakeDataSeeder` does this in one step — create, then batch-link — so the orphan state
never exists between two awaits.

### Composite Primary Keys

Rows mirrored from an external system keep that system's key shape, `(id, externalCompanyId)`,
so a mirrored row is unique per source company rather than globally.

Sequence-style entities are keyed `(number, type, tradingCompanyId)` — sequential per tenant
and per document type, not globally sequential.

### Multi-Tenancy

Most entities are scoped to `TradingCompany` with compound uniqueness:

- `(name, tradingCompanyId)` not just `(name)`

## Project Structure

```
libs/data-seeding/
├── src/
│   ├── __tests__/                    # Jest test suite
│   │   ├── factories/                # Factory tests
│   │   ├── generators/               # Generator tests
│   │   ├── helpers/                  # Helper tests
│   │   └── seeders/                  # Config tests
│   │
│   ├── application/                  # Use Cases
│   │   └── seeders/
│   │       ├── FakeDataSeeder.ts    # Main orchestrator
│   │       └── SeedConfig.ts        # Named seed profiles
│   │
│   ├── domain/                       # Pure Business Logic
│   │   ├── interfaces/              # IDataGenerator, IEntityFactory, IRepository
│   │   ├── value-objects/           # Money, Quantity, DateRange, Address
│   │   ├── services/                # StockBalanceService, MarginCalculationService
│   │   └── errors/                  # Domain-specific exceptions
│   │
│   ├── infrastructure/               # External Adapters
│   │   ├── factories/
│   │   │   ├── BaseFactory.ts       # Abstract base classes
│   │   │   ├── reference/           # Currency, Unit, Country, etc.
│   │   │   ├── erp/                # the ERP integration
│   │   │   └── trading/             # Core trading entities
│   │   └── generators/
│   │       └── FakerDataGenerator.ts
│   │
│   ├── test-data/                    # Test Fixtures (NOT production data)
│   │   ├── uk/                      # UK-specific test data
│   │   │   ├── banking.ts           # Sort codes, IBAN, BIC
│   │   │   ├── geography.ts         # Cities, counties, road suffixes
│   │   │   └── company.ts           # Company suffixes, VAT generators
│   │   └── trading/                 # Trading test patterns
│   │       ├── commodity-pricing.ts # Price range baselines
│   │       ├── status-distributions.ts # Status weights per entity
│   │       └── exchange-rates.ts    # FX rates and generators
│   │
│   ├── helpers/                      # Re-exports (legacy compatibility)
│   │
│   └── index.ts                      # Public API
│
├── CLAUDE.md                         # This file
├── README.md                         # Full documentation
└── project.json                      # Nx configuration
```

## Seed Configurations

`SeedConfig.ts` holds a handful of **named profiles** rather than a pile of flags at the call
site. Each profile fixes the entity counts per tenant, the share of rows put into a cancelled
state, and — crucially — a `randomSeed`, so the same profile produces the same database every
time. `PCN`/`SCN` below are purchase and sale credit notes per deal.

| Profile | Companies | Customers | Deals | PCN/Deal | SCN/Deal | Cancelled% | Use case |
| ------------ | --------- | --------- | ----- | -------- | -------- | ---------- | ----------------------- |
| **FAST**     | 2         | 10        | 20    | 0        | 0        | 0%         | Local dev (recommended) |
| **STANDARD** | 4         | 25        | 25    | 1        | 1        | 15%        | Realistic manual testing |
| **LOCKABLE** | 2         | 15        | 30    | 0        | 0        | 0%         | Lock/commission flows |
| **DEFAULT**  | 8         | 80        | 80    | 8        | 8        | 15%        | Integration tests |
| **LARGE**    | 16        | 400       | 400   | 16       | 16       | 15%        | Load testing |

Pick by intent, not by count: FAST when you want the loop short, STANDARD when the screen under
test needs credit notes and cancelled rows to look real, LOCKABLE when the flow you are
exercising consumes records in a specific terminal state, LARGE only when the size *is* the
test. Every profile also creates 25 additional guaranteed-lockable deals per company, each with
one finalised purchase credit note and one invoiced sale credit note, so a lock-driven flow
always has a fixture regardless of what the random draw produced.

Two of these numbers are load-bearing rather than cosmetic. `Cancelled%` at 0 is what makes FAST
and LOCKABLE safe to assert against — a randomised cancellation is a randomised test. And the
per-deal credit-note counts are the only reason the credit-note code paths are reachable at all
in STANDARD and above; a profile with zeroes there will pass a test suite that never touches
them. Treat the table as documentation of intent and read `SeedConfig.ts` for the current values
if a number matters to a failure you are chasing.

### cancelledPercentage Safety Constraint

`cancelledPercentage` randomly cancels a share of the seeded rows — but only entity types that
**nothing with a non-nullable relation depends on**. Cancelling a row that a required relation
points at orphans its children and leaves the seeded database in a state the application can
never produce. The safe set is decided per entity by asking "does any non-nullable FK reference
this?", and it is enforced in the seeder rather than left to the config author.

```typescript
// Use a predefined profile
await seeder.run(FAST_DEV_CONFIG); // Recommended for local dev

// Custom config
await seeder.run({ ...FAST_DEV_CONFIG, tradingCompanies: 4 });

// Estimate counts before running
const estimates = estimateEntityCounts(LARGE_CONFIG);
```

### Remote Database Seeding

Seeding is done from a local machine (CI workflow removed — timed out at the 10 min job limit).

```bash
# Connect to the remote DB via env vars, then seed locally
npx nx run legacy-api:db:seed:fake        # default profile
npx nx run legacy-api:db:seed:fake:fast   # smaller, faster profile
```

Available config options: `fast`, `standard`, `default`, `large`

## Domain Services

### StockBalanceService

Splits an available quantity across N children without the parts ever exceeding the whole —
the seeder's answer to "generate random children that still satisfy the aggregate's
invariant". It takes the available quantity, the number of children, and a minimum per
child, and returns quantities that sum to no more than what was available:

```typescript
const allocations = stockBalanceService.allocateStock(
  Quantity.of(1000, unit, unitId), // Available
  3, // Number of children
  Quantity.of(100, unit, unitId) // Minimum per child
);
// Returns: [Quantity(350), Quantity(420), Quantity(230)]
```

Random seed data that ignores an aggregate invariant is worse than no seed data: it makes
the application look broken in ways production never reproduces.

### Value Objects

- **Money**: Currency-aware amounts with `big.js`
- **Quantity**: Unit-aware quantities with conversion to a base unit
- **DateRange**: Date boundaries with overlap detection
- **Address**: Multi-line address formatting

### Derived Status (CRITICAL)

Several entities expose `status` as a **computed getter** over stored fields rather than as a
stored column — a terminal flag first, then a predicate over the children:

```typescript
get status(): EntityStatus {
  if (this.isTerminal) return EntityStatus.TERMINAL;
  return isReadyForTerminal(this) ? EntityStatus.READY : EntityStatus.OPEN;
}
```

**What this means for seeding:** you cannot ask for a status. You set the fields the getter
reads and let it derive. To seed a row that the UI shows as *ready for* the terminal action,
leave the terminal flag `false` and bring every child into the state the predicate requires;
the getter then reports READY, and the row still offers the action in the UI.

**The common mistake** is setting the terminal flag directly, because the status you want
sounds terminal. That produces a row already past the state under test — the action is gone,
the fixture is useless, and nothing errors. Whenever a status is derived, seed its inputs and
assert on the getter's output.

The UI in turn renders each derived status as an icon plus a colour plus a text label — never
colour alone, so the state survives a greyscale screenshot and a colour-blind reader.

## Standard Data Constants

Two kinds of constant, and they must never be mixed:

- **Production constants** — currencies, units and similar reference data — live in
  `@acme/domain-types` and are imported by production code and seeders alike.
- **Test fixtures** — sample geography, bank identifiers, price baselines, status weights —
  live under `test-data/` and exist for seeding only.

The values themselves are read from those modules rather than restated here. Importing a
`test-data/` fixture from production code is exactly the failure this split exists to
prevent — see rule 7 below.

## Important Rules

1. **big.js Required**: All decimals use `Big` - never native JS numbers for money
2. **No Direct Entity Import**: Never import TypeORM entities - use interfaces
3. **Deterministic Seeding**: Use `FakerDataGenerator(12345)` for reproducible data
4. **Reset Between Tests**: Call `factory.reset()` to clear state
5. **Domain Purity**: Domain layer must have zero external dependencies
6. **Factory State**: Fluent builders preserve state - call `reset()` when reusing
7. **Import Patterns**:
   - Production constants → `import { STANDARD_CURRENCIES } from '@acme/domain-types'`
   - Test fixtures → `import { UK_TEST_SORT_CODES } from '../test-data/uk'`
   - Never use test fixtures in production code
8. **Seed the terminal-ready state, not a nearby one**: factories usually offer several
   `createX()` variants for the same entity, only one of which satisfies a downstream
   predicate. Picking the wrong variant produces a fixture that looks right in the database
   and never reaches the state you were trying to exercise. Check what the predicate reads.
9. **Reproduce the status transitions the production service performs**: when a service writes
   several rows' statuses as part of one operation, seed data that writes only the primary row
   leaves the aggregate in a state the application can never produce, and every downstream
   state becomes unreachable. Mirror the whole transition, not just the row you were thinking
   about.
10. **Canonical company names**: the first trading companies take their names from a shared constant, identical across environments, because downstream config rows are keyed by name. Do NOT modify them locally — a renamed company silently stops matching its config row, and the failure surfaces far away as "no rule found" rather than as a seeding error. (Seed by id where you can; this is the constraint when you cannot.)
11. **Populate the FK the downstream service keys off**: a consumer that aggregates by some
    assigned relation returns an empty result — not an error — when the seeder left that
    relation null. "The endpoint returns zero rows" is far more often missing seed linkage
    than a broken consumer; check the FK before you debug the consumer.
12. **Never cancel a row that a non-nullable relation points at**: cancelling it orphans its
    children and breaks referential integrity in a way the application itself cannot produce.
    Restrict randomised cancellation to leaf entities (see the safety constraint above).
13. **Pre-set terminal states need their derived columns backfilled**: the seeder sets the terminal flag directly rather than calling the domain method that normally sets it, so every column that method would have computed must be backfilled by SQL afterwards. Miss one and the rows are invisible to any report that filters on it — present in the database, absent from the UI, with no error anywhere. When you bypass a domain transition for speed, enumerate what it writes and reproduce all of it.

## Related Documentation

- [README.md](./README.md) - Full documentation with diagrams and ADRs
- [legacy-api/CLAUDE.md](../../apps/legacy-api/CLAUDE.md) - Backend patterns
- [Root CLAUDE.md](../../CLAUDE.md) - Project-wide guidelines
