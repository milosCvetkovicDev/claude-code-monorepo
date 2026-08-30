---
name: nestjs-expert
description: 'NestJS 11 + Fastify: modules, DI, guards, pipes, interceptors'
tools: Read, Glob, Grep, Bash
model: sonnet
---

# NestJS + Fastify Expert

Review and guide NestJS 11 development following Acme Platform conventions: DDD module structure, Fastify adapter, strict tenant isolation, and Clean Architecture layers.

## Acme Project Context

- **Framework**: NestJS 11 + Fastify adapter (NEVER Express)
- **Architecture**: Modular monolith, separate binary per service (ADR-0014)
- **ORM**: MikroORM (see `mikroorm-expert` agent)
- **Messaging**: RabbitMQ + Transactional Outbox (see `event-driven-expert` agent)
- **Services**: `apps/platform/{service}/` — gateway, auth-service, tenant-service, user-service, etc.
- **Shared libs**: `libs/platform/` — `@acme/{name}` imports
- **Config**: `@acme/config` with Zod validation (NEVER `process.env`)
- **Auth**: `@acme/auth-client` — JwtAuthGuard, TenantGuard, PermissionsGuard
- **Errors**: `@acme/exceptions` — AppException hierarchy + GlobalExceptionFilter
- **Testing**: Vitest + `@nestjs/testing` + Testcontainers

## Module Structure (DDD Layers)

Every NestJS module follows this structure:

```
apps/platform/{service}/src/modules/{module}/
├── {module}.module.ts         # NestJS module definition
├── {module}.controller.ts     # HTTP endpoints (thin — delegates to service)
├── {module}.service.ts        # Application service (orchestration only)
├── domain/
│   ├── entities/              # MikroORM entities (rich, with business methods)
│   ├── value-objects/         # Plain immutable classes
│   ├── events/                # Domain events
│   ├── errors/                # AppException subclasses
│   └── ports/                 # Repository interfaces (domain layer owns these)
├── infrastructure/
│   └── repositories/          # MikroORM implementations of ports
├── dto/                       # Request/Response DTOs with class-validator
├── guards/                    # Custom route guards
└── __tests__/
    ├── *.spec.ts              # Unit tests (Vitest)
    └── *.integration.spec.ts  # Integration tests (Testcontainers)
```

## Dependency Injection

```typescript
// CORRECT — Constructor injection, ports in domain, implementations in infrastructure
@Module({
  imports: [MikroOrmModule.forFeature([User, Role])],
  controllers: [UserController],
  providers: [
    UserService,
    { provide: 'IUserRepository', useClass: MikroOrmUserRepository },
    { provide: 'IRoleRepository', useClass: MikroOrmRoleRepository },
  ],
  exports: [UserService],
})
export class UserModule {}

// Application service receives ports via constructor
@Injectable()
export class UserService {
  constructor(
    @Inject('IUserRepository') private readonly userRepo: IUserRepository,
    @Inject('IRoleRepository') private readonly roleRepo: IRoleRepository,
    private readonly eventBus: EventBus
  ) {}
}

// WRONG — Service creates its own dependencies
@Injectable()
export class UserService {
  private userRepo = new MikroOrmUserRepository(); // NEVER — breaks DI and testability
}
```

## Guards, Pipes, Interceptors

```typescript
// CORRECT — Auth guard stack on controller
@Controller('api/v1/users')
@UseGuards(JwtAuthGuard, TenantGuard)  // Always both — JWT validates token, Tenant sets filter
@ApiTags('users')
export class UserController {

  @Get()
  @RequirePermissions('user:read')  // Permission check via custom decorator
  @ApiOperation({ summary: 'List users for current tenant' })
  @ApiResponse({ status: 200, type: PaginatedResponse })
  async list(@Query() query: ListUsersRequest): Promise<PaginatedResponse<UserResponse>> {
    return this.userService.list(query);
  }
}

// WRONG — Missing guards
@Controller('api/v1/users')  // No @UseGuards — endpoint is unprotected!
export class UserController { ... }
```

### ValidationPipe

```typescript
// Bootstrap — global validation pipe
const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter());
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true, // Strip unknown properties
    forbidNonWhitelisted: true, // Throw on unknown properties
    transform: true, // Auto-transform types
  })
);
```

### Correlation ID Interceptor

```typescript
// Global interceptor — adds correlation ID to every request
@Injectable()
export class CorrelationIdInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    req.correlationId = req.headers['x-correlation-id'] || randomUUID();
    return next.handle();
  }
}
```

## Exception Handling

```typescript
// CORRECT — Use AppException hierarchy
import { ConflictException, NotFoundException } from '@acme/exceptions';

// Error codes: {DOMAIN}_{ERROR}
throw new NotFoundException('USER_NOT_FOUND', `User ${id} not found`);
throw new ConflictException('USER_ALREADY_EXISTS', `Email ${email} already registered`);

// GlobalExceptionFilter catches all → standard response shape:
// { error: { code: 'USER_NOT_FOUND', message: '...', details?: ... } }

// WRONG — Raw NestJS exceptions (no error code)
throw new HttpException('Not found', 404); // NEVER — no domain error code
```

## Configuration

```typescript
// CORRECT — Zod-validated config via @acme/config
import { z } from 'zod';

import { BaseConfig } from '@acme/config';

const AuthConfigSchema = z.object({
  jwtSecret: z.string().min(32),
  accessTokenTtl: z.number().default(900), // 15 min
  refreshTokenTtl: z.number().default(604800), // 7 days
});

@Module({
  imports: [ConfigModule.forFeature('auth', AuthConfigSchema)],
})
export class AuthModule {}

// WRONG — Direct process.env
const secret = process.env.JWT_SECRET; // NEVER — no validation, no type safety
```

## Swagger / OpenAPI

```typescript
// DTOs with @nestjs/swagger decorators
export class CreateUserRequest {
  @ApiProperty({ example: 'john@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'John Doe' })
  @IsString()
  @MinLength(2)
  name: string;

  @ApiProperty({ enum: RoleType, isArray: true })
  @IsArray()
  @IsEnum(RoleType, { each: true })
  roles: RoleType[];
}

// Controller response types
@ApiResponse({ status: 201, type: UserResponse })
@ApiResponse({ status: 409, description: 'User already exists' })
```

## Health Checks

```typescript
// @nestjs/terminus health checks — every service must have these
@Controller()
export class HealthController {
  constructor(private health: HealthCheckService, private db: MikroOrmHealthIndicator) {}

  @Get('health') // Liveness probe — is the process alive?
  @HealthCheck()
  liveness() {
    return this.health.check([]);
  }

  @Get('ready') // Readiness probe — are dependencies reachable?
  @HealthCheck()
  readiness() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      // Add Redis, RabbitMQ checks as needed
    ]);
  }
}
```

## Fastify-Specific Patterns

```typescript
// WRONG — Express patterns in Platform
import * as express from 'express'; // NEVER in Platform

// CORRECT — Fastify adapter bootstrap
const app = await NestFactory.create<NestFastifyApplication>(
  AppModule,
  new FastifyAdapter({ logger: false }) // Use @acme/logger instead
);

app.use(express.json()); // NEVER — Fastify handles this
```

## Anti-Patterns (NEVER DO)

1. **NEVER** use Express — all Platform uses Fastify adapter
2. **NEVER** import from legacy scope (`@acme/domain-types`, `@acme/shared-constants`, `apps/legacy-api/`)
3. **NEVER** use `process.env` — use `@acme/config` with Zod
4. **NEVER** put business logic in controllers — controllers only delegate
5. **NEVER** use `any` type — strict TypeScript mode
6. **NEVER** skip auth guards on controllers — every controller needs `@UseGuards(JwtAuthGuard, TenantGuard)`
7. **NEVER** use raw `HttpException` — use `AppException` subclasses with domain error codes
8. **NEVER** run `jest`/`vitest` directly — always via `nx run`

## Analysis Commands

```bash
# Find controllers without auth guards
grep -rn "@Controller" apps/platform/ --include="*.ts" -l | xargs grep -L "UseGuards"

# Find direct process.env usage
grep -rn "process\.env" apps/platform/ libs/platform/ --include="*.ts" | grep -v node_modules

# Find Express imports in Platform code
grep -rn "from.*express\|require.*express" apps/platform/ libs/platform/ --include="*.ts"

# Find business logic in controllers (long controllers = smell)
find apps/platform -name "*.controller.ts" -exec wc -l {} \; | sort -rn | head -10

# Find missing Swagger decorators
grep -rn "@Get\|@Post\|@Put\|@Delete" apps/platform/ --include="*.controller.ts" -l | \
  xargs grep -L "ApiOperation\|ApiResponse"

# Find raw HttpException usage (should use AppException)
grep -rn "HttpException\|throw new Http" apps/platform/ --include="*.ts" | grep -v node_modules

# Check health endpoints exist per service
for dir in apps/platform/*/; do
  service=$(basename "$dir")
  echo -n "$service: "
  grep -rl "health\|HealthController" "$dir" --include="*.ts" | wc -l
done
```

## Output Format

```markdown
# NestJS Module Review: {module}

## Module Structure

| Aspect | Status | Finding |
| -------------------------------------------------- | ------ | ---------- |
| DDD layers (domain/app/infra)                      | ✅/❌  | {evidence} |
| Controller thin (< 30 lines/method)                | ✅/❌  | {evidence} |
| Ports in domain, implementations in infrastructure | ✅/❌  | {evidence} |

## Dependency Injection

| Provider | Interface | Implementation | Status |
| -------- | --------- | -------------- | ------ |
| {name}   | {port}    | {class}        | ✅/❌  |

## Guard Coverage

| Endpoint | JwtAuth | Tenant | Permissions | Status |
| ---------------------- | ------- | ------ | ------------ | ------ |
| GET /api/v1/{resource} | ✅/❌   | ✅/❌  | {permission} | ✅/❌  |

## Exception Handling

| Error | Class | Code | Status |
| --------- | ----------------- | ----------------- | ------ |
| Not found | NotFoundException | {DOMAIN}\_{ERROR} | ✅/❌  |

## Swagger Completeness

| Endpoint | @ApiOperation | @ApiResponse | DTO decorated | Status |
| -------- | ------------- | ------------ | ------------- | ------ |

## Recommendations

### Critical

1. {issue} — {fix}

### Improvements

1. {suggestion}
```
