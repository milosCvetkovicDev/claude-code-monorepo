---
name: api-change
description: "Add, modify, or deprecate REST API endpoints with proper documentation, validation, and tests. Use when the user wants to create new routes, change request/response schemas, or deprecate endpoints. Do not use for frontend-only changes (use frontend-change) or database schema changes (use db-migration)."
model: sonnet
---

# API Change Workflow

You are orchestrating an API change with proper design, implementation, and documentation.

## Workflow Steps

### Step 1: Domain Alignment

Use the **ddd-expert agent** to:

- Verify API aligns with domain model
- Ensure ubiquitous language in API naming
- Check if new aggregates/entities needed
- Identify value objects for request/response

### Step 2: API Design

Use the **api-designer agent** to:

- Design the endpoint(s)
- Define request/response schemas
- Plan error responses
- Consider backward compatibility
- Document query parameters

**Project Requirements:**

- Decimals as strings in request/response
- Dates as ISO strings or YYYY-MM-DD
- All endpoints scoped to TradingCompany
- Zod validation with `validateRequest` middleware

### Step 3: Create Zod Schemas

Create validation schemas in `apps/legacy-api/src/dtos/`:

```typescript
import { z } from 'zod';

export const CreateEntitySchema = z.object({
  name: z.string().min(1).max(255),
  amount: z.string().regex(/^-?\d+(\.\d{1,4})?$/, 'Invalid decimal'),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD format'),
});

export type CreateEntityDto = z.infer<typeof CreateEntitySchema>;
```

### Step 4: Implement Controller (Thin!)

```typescript
// controllers/EntityController.ts
import { buildEntityResponse } from '../responseBuilders/entityResponseBuilder';
import * as EntityService from '../services/EntityService';

const create = async (req: CreateEntityRequest, res: Response) => {
  const tradingCompany = req.getTradingCompanyOrThrow();
  const entity = await EntityService.create(req.body, tradingCompany);
  res.status(201).json(buildEntityResponse(entity));
};

export { create };
```

### Step 5: Implement Service

```typescript
// services/EntityService.ts
import { EntityRepository } from '../repositories/EntityRepository';

export const create = async (
  dto: CreateEntityDto,
  tradingCompany: TradingCompany
): Promise<Entity> => {
  const repo = EntityRepository(tradingCompany);
  // Business logic here
  return repo.save(entity);
};
```

### Step 6: Register Route

```typescript
// routes/entity.routes.ts
import * as EntityController from '../controllers/EntityController';

router.post('/', validateRequest(CreateEntitySchema), asyncHandler(EntityController.create));
```

### Step 7: Code Quality Review

Use the **review-tech-lead agent** to verify:

- Controller is thin (no business logic)
- Service uses namespace import pattern
- Repository uses factory with TradingCompany
- Proper error handling
- No `any` types

### Step 8: Write Tests

- Unit tests for service logic
- Integration tests for endpoint
- Test error cases and validation

### Step 9: Documentation

Use the **documentation-writer agent** to:

- Document new endpoint in API docs
- Update OpenAPI spec if applicable
- Add examples for request/response

## API Response Patterns

**Success (single item):**

```json
{
  "data": {
    "id": "uuid",
    "name": "Entity Name",
    "amount": "123.4500",
    "createdAt": "2024-01-15T10:30:00Z"
  }
}
```

**Success (list with pagination):**

```json
{
    "data": [...],
    "meta": {
        "page": 1,
        "limit": 20,
        "total": 150,
        "totalPages": 8
    }
}
```

**Error:**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request",
    "details": [{ "field": "amount", "message": "Invalid decimal format" }]
  }
}
```

## Output

Provide:

- Endpoint(s) created/modified
- Request/response examples
- Zod schemas created
- Test coverage
- Documentation updates


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
