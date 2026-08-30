# DDD Best Practices

Comprehensive Domain-Driven Design practices for the Acme Platform modular monolith. Supplements the DDD Tactical Design Pipeline defined in `/rules/readiness-gate.md` Rule 6.

## Practice 1: Context Map with Relationship Patterns

Every multi-module system needs a formal Context Map documenting how bounded contexts relate. Not just WHAT they are, but the power dynamics and integration patterns.

### Relationship Types

| Pattern | Meaning | When to Use |
| ------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------- |
| **Shared Kernel**               | Two BCs share a small, co-owned model | Tightly coupled BCs that evolve together (e.g., Auth + Tenant sharing UserId) |
| **Customer-Supplier**           | Upstream BC serves downstream, downstream can negotiate | Reference Data → Trading (Trading needs product data, can request changes)    |
| **Conformist**                  | Downstream accepts upstream's model without negotiation | Conforming to Entra ID token format, external API schemas |
| **Anti-Corruption Layer (ACL)** | Translation layer between models | Legacy Express ↔ new NestJS modules, ERP integration |
| **Open Host Service (OHS)**     | BC publishes a well-defined, stable API                 | Auth module exposing JWT validation for all consumers |
| **Published Language**          | Shared interchange format (events, schemas)             | Domain Event contracts between modules |
| **Partnership**                 | Two BCs evolve together, coordinating releases | Trading ↔ Invoicing (tightly coupled business process)                        |
| **Separate Ways**               | No integration needed | Reporting ↔ Notification (fully independent)                                  |

### Context Map Artifact

Location: `docs/platform/context-mapping/context-map.md`

Format:

```markdown
# Context Map: Platform

## Relationships

| Upstream BC    | Downstream BC | Pattern | Integration | Notes |
| -------------- | ------------- | ----------------- | --------------------- | -------------------------------- |
| Auth (OHS)     | All modules | Open Host Service | JWT token validation | Auth exposes stable API          |
| Tenant | Auth | Shared Kernel | Shared TenantId VO    | Co-owned, co-evolved |
| Reference Data | Trading | Customer-Supplier | Domain Events | Trading requests product changes |
| Trading | Invoicing | Partnership | Domain Events | Coordinated releases |
| Legacy Express | New NestJS    | ACL               | Adapter interfaces | Temporary during migration |
| ERP           | Finance | ACL               | Anti-corruption layer | External system translation |

## Diagram

[Mermaid or ASCII diagram showing BC relationships with labeled arrows]
```

### When to Create

- During `/pm:arch-create` for the first epic in a milestone
- Updated when new BCs are added or relationships change

### Impact on Code

- **Shared Kernel** → shared library with co-ownership rules
- **Customer-Supplier** → upstream publishes events, downstream subscribes
- **Conformist** → no translation, use upstream types directly
- **ACL** → adapter interface in domain layer, implementation in infrastructure
- **OHS** → stable public API with versioning
- **Published Language** → event schema registry/catalog

---

## Practice 2: Anti-Corruption Layer Strategy for Legacy Migration

During the strangler fig migration (Express/TypeORM → NestJS/MikroORM), new modules must NOT directly depend on legacy code. ACL prevents legacy model leakage.

### ACL Decision Framework

For each new BC that needs legacy data:

````markdown
## ACL Assessment: {New BC} → {Legacy Module}

### What legacy services does this BC call?

- List specific endpoints or functions needed

### Translation mapping

| Legacy Model | New Domain Model | Translation |
| ------------------------------- | -------------------------- | ------------------------------- |
| LegacyCustomer (TypeORM entity) | Customer (MikroORM entity) | CustomerTranslator.fromLegacy() |

### Adapter interface (domain layer)

```typescript
// Domain layer — no knowledge of legacy
interface CustomerDataPort {
  findById(id: CustomerId): Promise<Customer | null>;
  findByTenant(tenantId: TenantId): Promise<Customer[]>;
}
```
````

### Adapter implementation (infrastructure layer)

```typescript
// Infrastructure layer — knows about legacy
class LegacyCustomerAdapter implements CustomerDataPort {
  constructor(private legacyDb: DataSource) {} // TypeORM connection

  async findById(id: CustomerId): Promise<Customer | null> {
    const legacy = await this.legacyDb.getRepository(LegacyCustomer).findOne(id.value);
    return legacy ? CustomerTranslator.fromLegacy(legacy) : null;
  }
}

// After migration, swap to:
class MikroOrmCustomerRepository implements CustomerDataPort {
  constructor(private em: EntityManager) {}
  // Direct MikroORM implementation
}
```

### Direction

- [ ] New calls legacy (most common during migration)
- [ ] Legacy calls new (reverse proxy or shared DB view)
- [ ] Both (dual-write period)

### Lifecycle

- Created: When new BC needs legacy data
- Removed: When legacy module is fully migrated
- Tracked in: project-context.md migration state

````

### Rules
1. **NEVER** import directly from `apps/legacy-api/` in new NestJS code
2. **ALWAYS** go through a port interface defined in the domain layer
3. **Adapter lives in infrastructure layer** — swappable without domain changes
4. **Track all ACLs** in `project-context.md` for migration progress visibility
5. **Remove ACL** when legacy module is decommissioned (update context map)

### ACL Artifact Location
- Per-BC: section in `.claude/epics/{name}/architecture.md`
- Summary: `docs/platform/context-mapping/acl-registry.md`

---

## Practice 3: Domain Service vs Entity Logic Guidelines

Clear rules for WHERE domain logic lives. Prevents anemic domain models (all logic in services) and god objects (all logic in entities).

### Decision Matrix

| Logic Type | Where It Goes | Example |
|---|---|---|
| **Single-aggregate invariant** | Entity/Aggregate Root method | `deal.addLineItem()` validates total |
| **Value object behavior** | Value Object method | `money.add(other)` checks currency match |
| **Cross-aggregate business rule** | Domain Service | `PricingService.calculateMargin(deal, exchangeRate)` |
| **Stateless calculation using domain concepts** | Domain Service | `CommissionCalculator.calculate(deal, rules)` |
| **Workflow orchestration** | Application Service (Use Case) | `CreateSaleUseCase.execute()` coordinates aggregates |
| **External system interaction** | Infrastructure Service (behind Port) | `ErpAdapter.syncInvoice()` |
| **Data retrieval** | Repository (behind Port) | `dealRepository.findById()` |

### Anemic Domain Model Detection

**Red flags** (the ddd-expert agent should check for these):
- Entity has only getters/setters, no business methods
- All validation lives in application services, not entities
- Entity methods are just `setField(value)` rather than intention-revealing names
- Business rules are in `if` statements inside services rather than entity methods

```typescript
// ANEMIC (bad) — entity is just a data bag
class Deal {
  status: DealStatus;
  total: Money;
  setStatus(status: DealStatus) { this.status = status; }
  setTotal(total: Money) { this.total = total; }
}

class DealService {
  confirm(deal: Deal) {
    if (deal.status !== 'DRAFT') throw new Error('...');
    if (deal.total.isZero()) throw new Error('...');
    deal.setStatus('CONFIRMED');
  }
}

// RICH (good) — entity protects its own invariants
class Deal {
  private status: DealStatus;
  private total: Money;

  confirm(): void {
    if (this.status !== DealStatus.DRAFT) {
      throw new DealNotDraftError(this.id);
    }
    if (this.total.isZero()) {
      throw new DealHasNoValueError(this.id);
    }
    this.status = DealStatus.CONFIRMED;
    this.domainEvents.push(new DealConfirmed(this.id, this.total));
  }
}
````

### Domain Service Rules

1. Domain services are **stateless** — no instance variables, no lifecycle
2. Domain services operate on **domain objects** — parameters and returns are entities/VOs
3. Named using **ubiquitous language** — `PricingService`, not `DealHelper`
4. Live in the **domain layer** — no infrastructure imports
5. Only created when logic **genuinely doesn't belong** to a single aggregate

---

## Practice 4: Domain Event Infrastructure Pattern

Architectural decision for how domain events are published, subscribed to, and handled within the modular monolith.

### Options for NestJS + MikroORM Modular Monolith

| Option | Mechanism | Persistence | Replay | Best For |
| --------------------------------------------- | ---------------------------------------------- | ---------------------------- | ------ | --------------------------------------------------- |
| **A: NestJS EventEmitter**                    | `@nestjs/event-emitter`                        | No | No | Simple notifications, low-risk events |
| **B: MikroORM Entity Events**                 | `@OnInit`, `@BeforeCreate`, lifecycle hooks | No | No | Entity lifecycle reactions |
| **C: Aggregate Domain Events + EventEmitter** | Entities collect events, flushed after persist | Transactional with aggregate | No | DDD-proper event publishing |
| **D: Transactional Outbox**                   | Events stored in DB table alongside aggregate | Yes | Yes | Guaranteed delivery, future microservice extraction |

### Recommended Pattern: Option C (Aggregate Domain Events)

```typescript
// Base class for all aggregate roots
abstract class AggregateRoot {
  private _domainEvents: DomainEvent[] = [];

  protected addDomainEvent(event: DomainEvent): void {
    this._domainEvents.push(event);
  }

  pullDomainEvents(): DomainEvent[] {
    const events = [...this._domainEvents];
    this._domainEvents = [];
    return events;
  }
}

// Aggregate uses it
class Deal extends AggregateRoot {
  confirm(): void {
    // ... validation ...
    this.status = DealStatus.CONFIRMED;
    this.addDomainEvent(new DealConfirmed(this.id, this.total));
  }
}

// Application service publishes after persist
class ConfirmDealUseCase {
  async execute(dealId: DealId): Promise<void> {
    const deal = await this.dealRepo.findById(dealId);
    deal.confirm();
    await this.dealRepo.save(deal); // MikroORM flush

    // Publish collected events AFTER successful persist
    for (const event of deal.pullDomainEvents()) {
      await this.eventBus.publish(event);
    }
  }
}
```

### Event Contract (Published Language)

All domain events should follow a standard envelope:

```typescript
interface DomainEvent {
  eventId: string; // UUID
  eventType: string; // 'DealConfirmed'
  aggregateId: string; // Source aggregate ID
  aggregateType: string; // 'Deal'
  occurredAt: Date; // When the event happened
  version: number; // Schema version (see Practice 10)
  payload: unknown; // Event-specific data
  metadata?: {
    correlationId?: string;
    causationId?: string;
    userId?: string;
    tenantId?: string;
  };
}
```

### Where to Decide

- Master architecture: the pattern choice (A/B/C/D)
- Per-BC architecture: which events are published and consumed
- Event catalog: `docs/platform/context-mapping/event-catalog.md`

---

## Practice 5: Bounded Context Canvas

A structured one-page document per BC providing everything a developer needs to understand and work within that context.

### Canvas Template

Location: `docs/platform/context-mapping/canvases/{bc-name}.md`

```markdown
# Bounded Context Canvas: {BC Name}

## Identity

- **Classification:** Core | Supporting | Generic
- **Strategic Role:** {Why this BC exists for the business}
- **Owner Team/Module:** {NestJS module path}

## Ubiquitous Language

| Term | Definition | NOT to be confused with |
| ------ | ----------------------------- | ----------------------- |
| {term} | {precise business definition} | {common confusion}      |

## Inbound Communication

| Message | Source BC | Pattern | Notes |
| --------------------- | --------- | -------------------- | ----- |
| {Command/Event/Query} | {source}  | {Command/Event/Sync} |       |

## Outbound Communication

| Message | Consumer BCs | Pattern | Notes |
| ---------------- | ------------ | ------------- | ----- |
| {Event/Response} | {consumers}  | {Event/Reply} |       |

## Key Business Rules

1. {Invariant or policy in plain language}
2. {Another invariant}

## Aggregates

| Aggregate | Root Entity | Key Invariants |
| --------- | ----------- | -------------- |
| {name}    | {entity}    | {rules}        |

## Dependencies

- **Upstream:** {BCs this depends on}
- **Downstream:** {BCs that depend on this}
- **ACL Required:** {Yes/No — if legacy integration needed}

## Technical Notes

- **Module Path:** `src/modules/{bc-name}/`
- **DB Schema:** `{schema_name}`
- **Event Prefix:** `{bc-name}.` (e.g., `trading.DealConfirmed`)
```

### When to Create

- During Phase A (Event Modeling) or Phase 1b (Architecture)
- One canvas per BC, kept up to date as BC evolves

---

## Practice 6: Example Mapping

A structured technique for discovering edge cases BETWEEN Event Modeling (Phase A) and BDD Scenario writing (Phase D).

### Process (25-minute session per feature/rule)

```
1. Start with a RULE (business rule from event model)
   Example: "Customers cannot exceed their credit limit"

2. For each rule, list concrete EXAMPLES:
   ✅ Customer with £10k limit, deal for £8k → approved
   ✅ Customer with £10k limit, deal for £12k → rejected
   ✅ Customer with £10k limit, existing deals £6k, new deal £8k → ???

3. Mark QUESTIONS for anything uncertain:
   ❓ Does existing allocation count against credit limit?
   ❓ What about pending (unconfirmed) deals?
   ❓ Is the limit per-deal or cumulative?

4. Questions become conversations with domain experts BEFORE writing Gherkin
```

### Color-Coded Card Format

```markdown
## Example Map: {Feature}

### 🟡 RULE: {Business rule statement}

#### 🟢 EXAMPLES:

- Given {context}, When {action}, Then {outcome}
- Given {context}, When {action}, Then {outcome}

#### 🔴 COUNTER-EXAMPLES:

- Given {context}, When {action}, Then {rejection/error}

#### 🔵 QUESTIONS:

- {Unresolved question} → RESOLVED: {answer} | PENDING
- {Another question} → RESOLVED: {answer} | PENDING
```

### Integration with Pipeline

- **Runs after:** Phase A (Event Modeling) — rules come from event model invariants
- **Runs before:** Phase D (BDD Scenarios) — examples become Gherkin scenarios
- **Output:** `docs/platform/context-mapping/example-maps/{bc-name}/{feature}.md`
- **Questions feed back into:** Phase A refinement or stakeholder conversations

### When to Use

- **Always for Core BCs** (Trading, Invoicing) — too many edge cases to skip
- **Recommended for Supporting BCs** (Customers, Finance) — business rules have nuance
- **Skip for Generic BCs** (Auth, Platform) — well-understood technical rules

---

## Practice 7: Specification Pattern

Composable business rule objects for complex, combinable domain rules. Replaces scattered `if` statements with named, testable, reusable rule objects.

### Pattern

```typescript
// Base specification interface
interface Specification<T> {
  isSatisfiedBy(candidate: T): boolean;
  and(other: Specification<T>): Specification<T>;
  or(other: Specification<T>): Specification<T>;
  not(): Specification<T>;
}

// Abstract base with composition
abstract class CompositeSpecification<T> implements Specification<T> {
  abstract isSatisfiedBy(candidate: T): boolean;

  and(other: Specification<T>): Specification<T> {
    return new AndSpecification(this, other);
  }

  or(other: Specification<T>): Specification<T> {
    return new OrSpecification(this, other);
  }

  not(): Specification<T> {
    return new NotSpecification(this);
  }
}

// Concrete business rule specifications
class CustomerHasSufficientCreditSpec extends CompositeSpecification<Customer> {
  constructor(private dealAmount: Money) {}

  isSatisfiedBy(customer: Customer): boolean {
    return customer.availableCredit.isGreaterThanOrEqual(this.dealAmount);
  }
}

class CustomerIsVerifiedSpec extends CompositeSpecification<Customer> {
  isSatisfiedBy(customer: Customer): boolean {
    return customer.verificationStatus === VerificationStatus.VERIFIED;
  }
}

class CustomerIsNotBlockedSpec extends CompositeSpecification<Customer> {
  isSatisfiedBy(customer: Customer): boolean {
    return !customer.isBlocked;
  }
}

// Usage in domain service
class DealEligibilityService {
  canCreateDeal(customer: Customer, dealAmount: Money): boolean {
    const eligible = new CustomerHasSufficientCreditSpec(dealAmount)
      .and(new CustomerIsVerifiedSpec())
      .and(new CustomerIsNotBlockedSpec());

    return eligible.isSatisfiedBy(customer);
  }
}
```

### When to Use

- Core domain with 3+ combinable business rules
- Rules that are reused across multiple use cases
- Rules that need to be tested independently
- Query filters that mirror business rules (specification → query criteria)

### When NOT to Use

- Simple single-condition checks (overkill)
- Generic BCs with straightforward validation
- One-off validations that won't be reused

---

## Practice 8: Factory Pattern for Complex Aggregate Creation

Encapsulate complex aggregate creation logic that involves lookups, calculations, or cross-aggregate validation.

### When to Use a Factory

| Scenario | Use Factory? | Why |
| -------------------------------------------------------------- | ------------ | --------------------------------------- |
| Simple entity with few fields | No | Constructor is sufficient |
| Creation requires external lookups | **Yes**      | Constructor shouldn't call repositories |
| Complex validation at creation time | **Yes**      | Keeps entity constructor clean |
| Multiple creation paths (from command, from import, from copy) | **Yes**      | Each path is a named factory method |
| Creation involves default value calculation | **Yes**      | Defaults may depend on external state |

### Pattern

```typescript
// Factory as domain service
class DealFactory {
  constructor(
    private readonly exchangeRateProvider: ExchangeRatePort,
    private readonly customerRepository: CustomerRepositoryPort
  ) {}

  async createFromCommand(command: CreateDealCommand): Promise<Deal> {
    // 1. Lookup external data
    const customer = await this.customerRepository.findById(command.customerId);
    if (!customer) throw new CustomerNotFoundError(command.customerId);

    const rate = await this.exchangeRateProvider.getRate(command.currency, customer.baseCurrency);

    // 2. Validate creation preconditions
    const eligibility = new CustomerHasSufficientCreditSpec(command.estimatedTotal);
    if (!eligibility.isSatisfiedBy(customer)) {
      throw new CustomerInsufficientCreditError(customer.id, command.estimatedTotal);
    }

    // 3. Create aggregate with calculated defaults
    return Deal.create({
      customerId: customer.id,
      tenantId: command.tenantId,
      currency: command.currency,
      exchangeRate: rate,
      status: DealStatus.DRAFT,
      createdBy: command.userId,
    });
  }

  // Alternative creation path
  async createFromImport(importData: DealImportRow): Promise<Deal> {
    // Different validation, different defaults
  }
}
```

### Rules

1. Factory is a **domain service** — lives in domain layer
2. Uses **ports** (interfaces) for external lookups, not concrete repositories
3. Returns a **fully valid aggregate** — never a half-constructed entity
4. Named using **ubiquitous language** — `createFromCommand`, not `buildDeal`
5. One factory per aggregate root (or static factory methods on the aggregate itself for simple cases)

---

## Practice 9: Repository Contract Rules

Repositories are the bridge between domain and infrastructure layers. Their contracts must preserve aggregate boundaries.

### Rules

1. **One repository per aggregate root** — never for child entities
2. **Interface in domain layer** — implementation in infrastructure layer
3. **Returns aggregate roots only** — never partial entities or child collections
4. **Persistence-ignorant interface** — no ORM-specific types in the contract
5. **Named after the aggregate** — `DealRepository`, not `DealDataAccess`

### Contract Template

```typescript
// Domain layer — interface
interface DealRepository {
  // Finding
  findById(id: DealId): Promise<Deal | null>;
  findByTenantId(tenantId: TenantId): Promise<Deal[]>;

  // Persisting (whole aggregate)
  save(deal: Deal): Promise<void>;
  saveMany(deals: Deal[]): Promise<void>;

  // Existence checks
  exists(id: DealId): Promise<boolean>;

  // Domain-specific queries (named using ubiquitous language)
  findActiveDealsByCustomer(customerId: CustomerId): Promise<Deal[]>;
  findDealsAwaitingConfirmation(tenantId: TenantId): Promise<Deal[]>;
}

// Infrastructure layer — MikroORM implementation
class MikroOrmDealRepository implements DealRepository {
  constructor(private readonly em: EntityManager) {}

  async findById(id: DealId): Promise<Deal | null> {
    return this.em.findOne(
      Deal,
      { id: id.value },
      {
        populate: ['lineItems', 'allocations'], // Load full aggregate
      }
    );
  }

  async save(deal: Deal): Promise<void> {
    this.em.persist(deal);
    await this.em.flush(); // MikroORM Unit of Work
  }
}
```

### Anti-Patterns to Detect

```typescript
// BAD: Repository for child entity
class InvoiceLineItemRepository { ... } // LineItem is part of Invoice aggregate!

// BAD: Returning partial data
interface DealRepository {
  findDealTotals(): Promise<{ id: string; total: number }[]>; // Use a Read Model instead
}

// BAD: ORM-specific return type
interface DealRepository {
  findById(id: string): Promise<EntityManager<Deal>>; // Leaking MikroORM!
}

// BAD: Generic CRUD (loses domain meaning)
interface DealRepository {
  findAll(): Promise<Deal[]>;     // What does "all" mean in business terms?
  delete(id: string): void;       // Deals probably shouldn't be hard-deleted
  update(deal: Deal): void;       // "Update" is not a domain concept
}
```

### MikroORM-Specific Notes

- Use `populate` to load full aggregate in one query
- Use `em.persist()` + `em.flush()` (Unit of Work) — not individual saves
- Custom repositories extend `EntityRepository<T>` but expose domain interface
- Use `@Filter()` decorator for tenant isolation at repository level

---

## Practice 10: Domain Event Versioning Strategy

As the system evolves, event schemas change. A versioning strategy prevents breaking consumers.

### Version Rules

1. **Every event has a version number** — starts at 1
2. **Additive changes = same version** — new optional fields don't bump version
3. **Breaking changes = new version** — renamed fields, type changes, removed fields
4. **Consumers declare which versions they handle** — explicit version matching
5. **Upcasters convert old → new** — transform old events to latest version

### Event Versioning Pattern

```typescript
// Versioned event
class DealConfirmed implements DomainEvent {
  readonly eventType = 'DealConfirmed';
  readonly version = 2; // Current version

  constructor(
    readonly dealId: DealId,
    readonly total: Money, // v1: was `amount: number`
    readonly confirmedBy: UserId, // v2: added
    readonly occurredAt: Date
  ) {}
}

// Upcaster: transforms v1 → v2
class DealConfirmedV1Upcaster implements EventUpcaster<DealConfirmedV1, DealConfirmed> {
  canUpcast(event: DomainEvent): boolean {
    return event.eventType === 'DealConfirmed' && event.version === 1;
  }

  upcast(v1: DealConfirmedV1): DealConfirmed {
    return new DealConfirmed(
      v1.dealId,
      Money.of(v1.amount.toString(), v1.currency), // Translate primitive to VO
      UserId.unknown(), // v1 didn't track who confirmed
      v1.occurredAt
    );
  }
}
```

### Event Catalog

Location: `docs/platform/context-mapping/event-catalog.md`

```markdown
# Domain Event Catalog

## Trading Context

| Event | Version | Payload | Producers | Consumers |
| -------------- | ------- | ------------------------------------- | --------------- | ------------------ |
| DealCreated | v1      | { dealId, customerId, tenantId }      | Deal aggregate | Invoicing, Stock |
| DealConfirmed | v2      | { dealId, total: Money, confirmedBy } | Deal aggregate | Invoicing, Finance |
| StockAllocated | v1      | { dealId, productId, quantity }       | Stock aggregate | Logistics |

## Version History

| Event | Version | Change | Date |
| ------------- | ------- | -------------------------------------- | ---------- |
| DealConfirmed | v1→v2   | Added confirmedBy, amount→total(Money) | 2026-xx-xx |
```

### When to Create

- Event catalog started during Phase A (Event Modeling)
- Updated whenever event schemas change
- Version bumps require ADR if breaking change affects 3+ consumers

---

## Cross-Reference: Practice → Workflow Phase

| Practice | When in Pipeline | Who Does It |
| ------------------------------ | -------------------------------- | ---------------------------------------- |
| #1 Context Map | Phase 1b (arch-create)           | Architect + domain expert |
| #2 ACL Strategy | Phase 1b (arch-create)           | Architect |
| #3 Domain Service Guidelines | Phase F (implementation)         | Developer (ddd-expert reviews)           |
| #4 Domain Event Infrastructure | Phase 1b (arch-create, one-time) | Architect |
| #5 BC Canvas | Phase A (event modeling)         | Architect + domain expert |
| #6 Example Mapping | Between Phase A and D            | Developer + domain expert |
| #7 Specification Pattern | Phase F (implementation)         | Developer (ddd-expert reviews)           |
| #8 Factory Pattern | Phase F (implementation)         | Developer (ddd-expert reviews)           |
| #9 Repository Contracts | Phase C (aggregate design) + F   | Architect (C), Developer (F)             |
| #10 Event Versioning | Phase A (initial) + ongoing | Architect (initial), Developer (ongoing) |

## Adoption by BC Type

| Practice | Core | Supporting | Generic |
| ------------------------------ | --------------------- | ------------- | ------------- |
| #1 Context Map | Required | Required | Required |
| #2 ACL Strategy | If legacy dep | If legacy dep | If legacy dep |
| #3 Domain Service Guidelines | Required | Required | Optional |
| #4 Domain Event Infrastructure | Required | Required | Optional |
| #5 BC Canvas | Required | Recommended | Optional |
| #6 Example Mapping | Required | Recommended | Skip |
| #7 Specification Pattern | When 3+ rules | Optional | Skip |
| #8 Factory Pattern | When complex creation | Optional | Skip |
| #9 Repository Contracts | Required | Required | Required |
| #10 Event Versioning | Required | Required | Optional |
