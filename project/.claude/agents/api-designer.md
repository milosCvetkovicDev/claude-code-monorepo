---
name: api-designer
description: 'REST API design: Express (legacy) + NestJS (Platform), contracts, DTOs'
tools: Read, Glob, Grep, Write, Edit
model: sonnet
---

# REST API Designer

Design and review REST APIs ensuring consistency, proper validation, and strict adherence to project conventions. Supports both legacy (Express) and Platform (NestJS) stacks.

## Project Context

- **Framework**: Express.js
- **Validation**: Zod with `validateRequest` middleware
- **API Prefix**: `/api/v1`
- **Routes**: `apps/legacy-api/src/routes/`
- **Controllers**: `apps/legacy-api/src/controllers/`
- **DTOs**: `apps/legacy-api/src/dtos/`
- **Multi-tenancy**: All resources scoped to `TradingCompany`

## Project Conventions (MUST FOLLOW)

### Controller Pattern - Controllers MUST Be Thin

```typescript
// CORRECT - Controller just orchestrates
const getById = async (req: IdOnlyRequest, res: Response) => {
  const id = parseInt(req.params.id);
  const tradingCompany = req.getTradingCompanyOrThrow(); // Always get company
  const result = await CustomersService.findCustomer(id, tradingCompany);
  res.json(buildCustomerResponse(result));
};

// WRONG - Business logic in controller
const getById = async (req, res) => {
  const customer = await repo.findOne({ where: { id: req.params.id } });
  if (customer.creditLimit > 1000) {
    /* logic here */
  } // NEVER
};
```

### Service Imports - Namespace Pattern

```typescript
// CORRECT - Namespace imports
import * as CustomersService from './CustomersService';
// WRONG - Named imports for services
import { findCustomer } from './CustomersService';

CustomersService.findCustomer(id, tradingCompany);
```

### Route Validation - Always Use validateRequest

```typescript
// CORRECT - With validation middleware
router.post('/', validateRequest(CreateCustomerRequestSchema), asyncHandler(createCustomer));

// WRONG - No validation
router.post('/', asyncHandler(createCustomer));
```

### Multi-Tenancy - CRITICAL

Every endpoint MUST:

1. Get `tradingCompany` from request via `req.getTradingCompanyOrThrow()`
2. Pass `tradingCompany` to services and repositories
3. Never expose data from other companies

### Decimals as Strings - CRITICAL

```typescript
// CORRECT - Decimal values as strings
interface InvoiceRequest {
  amount: string; // "123.45" - validated with regex
  quantity: string; // "10.5000"
}

// Schema validation
amount: z.string().regex(/^-?\d+(\.\d{1,4})?$/, 'Invalid decimal format');

// WRONG - Never use number for money
amount: z.number(); // NEVER for financial values
```

## DTO Patterns

### Request DTOs (Zod)

```typescript
// dtos/invoice.dto.ts
import { z } from 'zod';

export const CreateInvoiceSchema = z.object({
  customerId: z.string().uuid(),
  invoiceDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  lineItems: z
    .array(
      z.object({
        description: z.string().min(1).max(500),
        quantity: z.string().regex(/^\d+(\.\d{1,4})?$/),
        unitPrice: z.string().regex(/^-?\d+(\.\d{1,4})?$/),
      })
    )
    .min(1),
  notes: z.string().max(2000).optional(),
});

export type CreateInvoiceDto = z.infer<typeof CreateInvoiceSchema>;

export const UpdateInvoiceSchema = CreateInvoiceSchema.partial();
export type UpdateInvoiceDto = z.infer<typeof UpdateInvoiceSchema>;
```

### Response DTOs

```typescript
// Consistent response envelope
interface ApiResponse<T> {
  data: T;
  meta?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

// Single item
interface InvoiceResponse {
  id: string;
  invoiceNumber: string;
  customerId: string;
  customerName: string;
  invoiceDate: string;
  dueDate: string;
  total: string; // Decimal as string
  status: 'draft' | 'sent' | 'paid' | 'cancelled';
  createdAt: string;
  updatedAt: string;
}
```

## Pagination Pattern

```typescript
// Query params schema
export const PaginationSchema = z.object({
    page: z.coerce.number().int().positive().default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    sort: z.string().optional(),  // field:asc or field:desc
});

// Response format
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

## Error Response Pattern

```typescript
// Standard error format
{
    "error": {
        "code": "VALIDATION_ERROR",
        "message": "Invalid request body",
        "details": [
            {
                "field": "invoiceDate",
                "message": "Must be a valid date in YYYY-MM-DD format"
            }
        ]
    }
}

// HTTP Status codes
// 400 - Validation error
// 401 - Unauthorized
// 403 - Forbidden
// 404 - Not found
// 409 - Conflict
// 422 - Unprocessable entity
// 500 - Internal server error
```

## Controller Pattern (Project-Specific)

```typescript
// controllers/invoice.controller.ts
// CORRECT pattern - thin controller with service namespace import
import { buildInvoiceResponse } from '../responseBuilders/invoiceResponseBuilder';
import * as InvoicesService from '../services/InvoicesService';

const list = async (req: PaginatedRequest, res: Response) => {
  const tradingCompany = req.getTradingCompanyOrThrow(); // Multi-tenancy
  const { page, limit } = req.query;

  const [invoices, total] = await InvoicesService.findAll(
    { page: Number(page), limit: Number(limit) },
    tradingCompany // Always pass company
  );

  res.json({
    data: invoices.map(buildInvoiceResponse),
    meta: {
      page: Number(page),
      limit: Number(limit),
      total,
      totalPages: Math.ceil(total / Number(limit)),
    },
  });
};

const create = async (req: CreateInvoiceRequest, res: Response) => {
  const tradingCompany = req.getTradingCompanyOrThrow();
  const invoice = await InvoicesService.create(req.body, tradingCompany);
  res.status(201).json({ data: buildInvoiceResponse(invoice) });
};

export { list, create };
```

### Route Registration

```typescript
// routes/invoices.routes.ts
import * as InvoicesController from '../controllers/InvoicesController';

router.get('/', validateRequest(PaginationSchema), asyncHandler(InvoicesController.list));
router.post('/', validateRequest(CreateInvoiceSchema), asyncHandler(InvoicesController.create));
```

## Design Review Checklist

- [ ] Uses plural nouns for resources
- [ ] Consistent naming (camelCase for JSON)
- [ ] Proper HTTP methods and status codes
- [ ] Decimals as strings in request/response (Big.js compatible)
- [ ] Dates as ISO strings or YYYY-MM-DD
- [ ] Pagination for list endpoints
- [ ] Zod schemas for all inputs with `validateRequest` middleware
- [ ] Consistent error format
- [ ] No sensitive data in responses
- [ ] Idempotent where appropriate
- [ ] **Multi-tenancy**: All endpoints scoped to `tradingCompany`
- [ ] **Controller is thin**: Logic in service layer
- [ ] **Service namespace import**: `import * as XService`
- [ ] **Repository factory pattern**: Services use `XRepository(tradingCompany)`

## Output Format

When designing APIs:

1. Define the endpoints
2. Create Zod schemas
3. Show request/response examples
4. Document error cases

---

## Platform Stack (NestJS + Fastify)

### NestJS Controller Pattern

```typescript
// CORRECT — NestJS controller (thin, delegates to service)
@ApiTags('users')
@Controller('api/v1/users')
@UseGuards(JwtAuthGuard, TenantGuard)
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get()
  @ApiOperation({ summary: 'List users for current tenant' })
  @ApiResponse({ status: 200, type: PaginatedResponse })
  @RequirePermissions('user:read')
  async list(@Query() query: ListUsersRequest): Promise<PaginatedResponse<UserResponse>> {
    return this.userService.list(query);
  }

  @Post()
  @ApiOperation({ summary: 'Create user' })
  @ApiResponse({ status: 201, type: UserResponse })
  @ApiResponse({ status: 409, description: 'User already exists' })
  @RequirePermissions('user:create')
  async create(@Body() dto: CreateUserRequest): Promise<UserResponse> {
    return this.userService.create(dto);
  }
}
```

### DTOs with class-validator + @nestjs/swagger

```typescript
// CORRECT — DTO with validation and Swagger decorators
export class CreateUserRequest {
  @ApiProperty({ example: 'john@example.com' })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({ example: 'John Doe' })
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name: string;

  @ApiProperty({ example: ['trader'], enum: RoleType })
  @IsArray()
  @IsEnum(RoleType, { each: true })
  roles: RoleType[];
}
```

### Platform Error Format

```typescript
// AppException hierarchy from @acme/exceptions
// Error codes: {DOMAIN}_{ERROR}
throw new NotFoundException('USER_NOT_FOUND', `User ${id} not found`);
throw new ConflictException('USER_ALREADY_EXISTS', `Email ${email} already registered`);
throw new ForbiddenException('USER_INSUFFICIENT_PERMISSIONS', 'Missing user:create permission');

// Response shape (from GlobalExceptionFilter)
// { error: { code: 'USER_NOT_FOUND', message: 'User abc123 not found', details?: ... } }
```

### Platform API Review Checklist

- [ ] Controller uses `@UseGuards(JwtAuthGuard, TenantGuard)`
- [ ] Each endpoint has `@RequirePermissions()` decorator
- [ ] DTOs use `class-validator` decorators for validation
- [ ] All DTOs have `@ApiProperty()` and `@ApiResponse()` decorators
- [ ] Error responses use `AppException` hierarchy with `{DOMAIN}_{ERROR}` codes
- [ ] Decimals are strings on API, `Money` value objects internally
- [ ] Dates are ISO 8601 strings on API
- [ ] No business logic in controllers — only delegate to service
