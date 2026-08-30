---
name: implement-nestjs-module
description: 'Scaffold a full DDD module for a Platform NestJS service: domain entities, value objects, events, repository ports, MikroORM implementations, application service, controller, DTOs, guards, and test stubs. Use for creating new bounded context modules.'
model: sonnet
args: <module-name> [--service <service-name>]
disable-model-invocation: true
---

## Input

- `module-name`: The module name in kebab-case (e.g., `credential`, `tenant`, `user`)
- `--service`: Target service (default: infer from current directory). E.g., `auth-service`, `tenant-service`

## Workflow

### Step 1: Determine Target Service

If `--service` is provided, use it. Otherwise, detect from current directory or ask.

Service path: `apps/platform/{service}/src/modules/{module}/`

Read master architecture at `.claude/milestones/platform/master-architecture.md` for confirmed conventions.

### Step 2: Scaffold Module Structure

Create the following files:

```
apps/platform/{service}/src/modules/{module}/
├── {module}.module.ts
├── {module}.controller.ts
├── {module}.service.ts
├── domain/
│   ├── entities/
│   │   └── {entity}.entity.ts          # Aggregate root extending TenantBaseEntity
│   ├── value-objects/
│   │   └── .gitkeep
│   ├── events/
│   │   └── {module}.events.ts          # Domain + integration event classes
│   ├── errors/
│   │   └── {module}.errors.ts          # AppException subclasses
│   └── ports/
│       └── {entity}.repository.port.ts # Repository interface
├── infrastructure/
│   └── repositories/
│       └── mikro-orm-{entity}.repository.ts  # MikroORM implementation
├── dto/
│   ├── create-{entity}.request.ts      # class-validator + @nestjs/swagger
│   ├── update-{entity}.request.ts
│   └── {entity}.response.ts
├── guards/
│   └── .gitkeep
└── __tests__/
    ├── {module}.service.spec.ts         # Unit test stub (Vitest)
    └── {module}.integration.spec.ts     # Integration test stub (Testcontainers)
```

### Step 3: Generate Entity (Aggregate Root)

```typescript
// domain/entities/{entity}.entity.ts
import { Entity, Filter, PrimaryKey, Property } from '@mikro-orm/core';
import { TenantBaseEntity } from '@acme/mikro-orm';

@Entity({ schema: '{bc}' })
@Filter({ name: 'tenant', cond: { tenantId: '$tenantId' }, default: true })
export class {Entity} extends TenantBaseEntity {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  // TODO: Add properties

  // TODO: Add business methods (rich domain model)
}
```

### Step 4: Generate Repository Port + Implementation

Port in `domain/ports/`, MikroORM impl in `infrastructure/repositories/`.

Port returns aggregate roots only. Domain-named query methods. Persistence-ignorant.

### Step 5: Generate DTOs

Use `class-validator` decorators for validation. Use `@nestjs/swagger` `@ApiProperty()` on every field.

### Step 6: Generate Controller

Thin controller with `@UseGuards(JwtAuthGuard, TenantGuard)`, `@RequirePermissions()`, `@ApiTags()`.

### Step 7: Generate Application Service

Constructor-injected repository port. Orchestration only — no business logic.

### Step 8: Generate Module Definition

Register controller, service, repository provider (port → implementation binding).

### Step 9: Generate Test Stubs

- Unit test: Vitest + `@nestjs/testing` `Test.createTestingModule()` with mocked repository
- Integration test: Vitest + Testcontainers PostgreSQL, real MikroORM

### Step 10: Verify

```bash
nx run {service}:build
nx run {service}:lint
```

## Conventions

- Entity extends `TenantBaseEntity` with `@Filter` (unless TENANT_EXEMPT)
- Schema matches BC name: `@Entity({ schema: '{bc}' })`
- Decimals: `numeric(19,4)` in DB, `string` in TypeScript, `Money` VO for operations
- Dates: `timestamptz` in DB, `Date` in TypeScript, ISO 8601 on API
- Error codes: `{DOMAIN}_{ERROR}` format
- Repository port in domain layer, MikroORM implementation in infrastructure
- Tests run via `nx run`, never bare `vitest`
