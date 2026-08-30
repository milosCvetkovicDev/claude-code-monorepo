---
name: implement-endpoint
description: 'Implement a full REST API endpoint: controller, service layer, route registration, validation, and tests. Use when the user needs a new or modified API endpoint per a spec. Do not use for frontend changes (use implement-component) or database-only changes (use db-migration).'
model: sonnet
disable-model-invocation: true
args: <method> <path>
---

# Implement API Endpoint

You are implementing a single API endpoint following legacy-api patterns.

## Input

- **method**: HTTP method (GET, POST, PUT, PATCH, DELETE)
- **path**: API path (e.g., `/api/v1/invoices/:id/finalize`)

## Workflow

### Step 1: Analyze Endpoint

1. Parse the path to identify:
   - Resource (e.g., `invoices`)
   - Action (e.g., `finalize`)
   - Parameters (e.g., `:id`)
2. Determine which controller handles this resource
3. Check if similar endpoints exist for patterns

### Step 2: Create/Update Controller

```typescript
// apps/legacy-api/src/controllers/<Resource>Controller.ts

import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import * as <Resource>Service from '../services/<Resource>Service';

// Request validation schema
const <action>RequestSchema = z.object({
  // Define body schema if POST/PUT/PATCH
});

// Controller function
export const <action><Resource> = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const tradingCompany = req.tradingCompany; // From middleware

    // Validate body if needed
    const body = <action>RequestSchema.parse(req.body);

    // Call service
    const result = await <Resource>Service.<action>(
      tradingCompany,
      parseInt(id),
      body
    );

    res.json(result);
  } catch (error) {
    next(error);
  }
};
```

### Step 3: Create/Update Service

```typescript
// apps/legacy-api/src/services/<Resource>Service.ts

import { TradingCompany } from '../models/db/TradingCompany';
import { <Resource>Repository } from '../repositories/<Resource>Repository';

// Use functional exports (legacy-api pattern)
export const <action> = async (
  tradingCompany: TradingCompany,
  id: number,
  data?: <DataType>
): Promise<<ReturnType>> => {
  const repo = <Resource>Repository(tradingCompany);

  // Implementation
  const entity = await repo.findOne({ where: { id } });

  if (!entity) {
    throw new NotFoundError('<Resource> not found');
  }

  // Business logic here

  return entity;
};
```

### Step 4: Add Route

```typescript
// apps/legacy-api/src/routes.ts

import { <action><Resource> } from './controllers/<Resource>Controller';

// Add to appropriate router section
router.<method>(
  '/api/v1/<resources>/:id/<action>',
  authenticateUserToken,
  handleTradingCompanyHeader,
  <action><Resource>
);
```

### Step 5: Create DTO (if needed)

```typescript
// apps/legacy-api/src/dtos/<Action><Resource>Dto.ts

import { z } from 'zod';

export const <Action><Resource>RequestDto = z.object({
  // Request body schema
});

export const <Action><Resource>ResponseDto = z.object({
  // Response schema
});

export type <Action><Resource>Request = z.infer<typeof <Action><Resource>RequestDto>;
export type <Action><Resource>Response = z.infer<typeof <Action><Resource>ResponseDto>;
```

### Step 6: Write Tests

```typescript
// apps/legacy-api/test/unit/services/<Resource>Service.spec.ts

describe('<Resource>Service', () => {
  describe('<action>', () => {
    it('should <expected behavior>', async () => {
      // Arrange
      const mockTradingCompany = createMockTradingCompany();
      const mockRepo = {
        findOne: jest.fn().mockResolvedValue({ id: 1 }),
      };
      ((<Resource>Repository) as jest.Mock).mockReturnValue(mockRepo);

      // Act
      const result = await (<action>(mockTradingCompany, 1));

      // Assert
      expect(result).toBeDefined();
    });

    it('should throw NotFoundError when <resource> does not exist', async () => {
      // Arrange
      const mockTradingCompany = createMockTradingCompany();
      ((<Resource>Repository) as jest.Mock).mockReturnValue({
        findOne: jest.fn().mockResolvedValue(null),
      });

      // Act & Assert
      await expect(<action>(mockTradingCompany, 999)).rejects.toThrow('not found');
    });
  });
});
```

### Step 7: Verify

1. Run tests: `nx run legacy-api:test -- --testPathPattern=<Resource>Service`
2. Run lint: `nx run legacy-api:lint`
3. Build: `nx run legacy-api:build`
4. Manual test: `curl -X <METHOD> http://localhost:3000/api/v1/...`

## Output

````markdown
## Endpoint Implemented: <METHOD> <path>

### Files Created/Modified

- `src/controllers/<Resource>Controller.ts` (modified)
- `src/services/<Resource>Service.ts` (modified)
- `src/routes.ts` (modified)
- `src/dtos/<Action><Resource>Dto.ts` (created)
- `test/unit/services/<Resource>Service.spec.ts` (modified)

### Middleware Chain

1. `authenticateUserToken` - JWT validation
2. `handleTradingCompanyHeader` - Multi-tenancy
3. `<action><Resource>` - Controller

### Verification

| Check | Status |
| ----- | ------ |
| Tests | ✅     |
| Lint | ✅     |
| Build | ✅     |

### Usage

```bash
curl -X <METHOD> http://localhost:3000<path> \
  -H "Authorization: Bearer <token>" \
  -H "X-Trading-Company-Id: 1" \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```
````

```

## Conventions

- Controllers call services (never repositories directly)
- Services call repositories
- Services receive `TradingCompany` as first parameter (multi-tenancy)
- Use Zod for request/response validation
- Use functional exports for services (not classes)
- Error handling via `next(error)` in controllers
```

---

## Platform Variant (NestJS + Fastify)

**Detection:** If the endpoint path is under `/api/platform/` or the target is in `apps/platform/`, use this variant instead.

For Platform endpoints, use `/implement-nestjs-module` for full module scaffold, or follow these patterns:

### Controller

```typescript
@Controller('api/v1/{resource}')
@UseGuards(JwtAuthGuard, TenantGuard)
@ApiTags('{resource}')
export class {Resource}Controller {
  constructor(private readonly service: {Resource}Service) {}

  @Post()
  @RequirePermissions('{resource}:create')
  @ApiOperation({ summary: 'Create {resource}' })
  @ApiResponse({ status: 201, type: {Resource}Response })
  async create(@Body() dto: Create{Resource}Request): Promise<{Resource}Response> {
    return this.service.create(dto);
  }
}
```

### DTOs

- Use `class-validator` decorators (`@IsString()`, `@IsEmail()`, etc.)
- Use `@ApiProperty()` on every field for Swagger
- Decimals as strings on API, `Money` VO internally

### Service

- Constructor-injected repository port (domain interface, not MikroORM class)
- Use `em.flush()` at end (Unit of Work), not individual `.save()` calls
- Throw `AppException` subclasses with `{DOMAIN}_{ERROR}` codes

### Tests

- Unit: Vitest + `@nestjs/testing` with mocked repository
- Integration: Vitest + Fastify `inject()` + Testcontainers
