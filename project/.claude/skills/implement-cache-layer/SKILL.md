---
name: implement-cache-layer
description: 'Add Redis caching to a NestJS module: cache-aside pattern, TTL strategy, event-driven invalidation via RabbitMQ consumer. Redis is cache-only — no queues, no sessions.'
model: sonnet
args: <module-name> [--service <service-name>]
disable-model-invocation: true
---

## Input

- `module-name`: Module to add caching to (e.g., `tenant`, `user`, `reference-data`)
- `--service`: Target service (default: infer from current directory)

## Workflow

### Step 1: Identify Cacheable Queries

Read the module's repository port interface. Identify queries that:

- Are read-heavy (called frequently)
- Change infrequently (write-rarely-read-often pattern)
- Can tolerate stale data for a short TTL

### Step 2: Define TTL Strategy

Reference the TTL table in `redis-expert` agent. Choose TTL based on entity type:

| Entity Type | Suggested TTL | Invalidation |
| ------------------- | ------------- | ---------------------- |
| Config/settings | 5 min | On update event |
| Reference data | 24 hours | On entity update event |
| User permissions | 15 min | On role change event |
| Computed aggregates | 10 min | On source data change |

### Step 3: Define Key Naming

Format: `{env}:{bc}:{entity}:{identifier}`

Example: `prod:platform:tenant:tenant-001`

### Step 4: Implement Cache-Aside in Service

Add caching to the application service:

```typescript
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';

@Injectable()
export class {Module}Service {
  constructor(
    @Inject(CACHE_MANAGER) private cache: Cache,
    @Inject('I{Entity}Repository') private repo: I{Entity}Repository,
  ) {}

  async findById(id: string): Promise<{Entity} | null> {
    const cacheKey = `${env}:{bc}:{entity}:${id}`;
    const cached = await this.cache.get<{Entity}>(cacheKey);
    if (cached) return cached;

    const entity = await this.repo.findById(id);
    if (entity) {
      await this.cache.set(cacheKey, entity, TTL_MS);
    }
    return entity;
  }
}
```

### Step 5: Implement Event-Driven Invalidation

Create a RabbitMQ consumer that listens for relevant events and invalidates cache:

```typescript
@Injectable()
export class {Entity}CacheInvalidator {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache) {}

  async handle(event: IntegrationEvent): Promise<void> {
    await this.cache.del(`${env}:{bc}:{entity}:${event.payload.id}`);
  }
}
```

### Step 6: Register Cache Module

```typescript
@Module({
  imports: [
    CacheModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        store: redisStore,
        host: config.get('redis.host'),
        port: config.get('redis.port'),
        ttl: 300_000, // Default 5 min
      }),
    }),
  ],
})
```

### Step 7: Write Tests

- Unit: Mock cache, verify cache-aside flow (hit, miss, invalidation)
- Integration: Real Redis (Testcontainers), verify TTL expiry and invalidation

## Conventions

- NEVER use Redis for queues (RabbitMQ handles that)
- NEVER skip TTL — all keys must expire
- NEVER use KEYS command — use SCAN
- NEVER cache objects > 1MB
- ALWAYS invalidate via events, not synchronous write-through
- Key format: `{env}:{bc}:{entity}:{identifier}`
