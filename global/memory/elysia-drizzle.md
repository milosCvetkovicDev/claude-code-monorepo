# Elysia, Drizzle & Bun Patterns

## Elysia HTTP Redirects
No built-in `redirect()`. Use explicit headers + MUST return:
```typescript
set.status = 302;
set.headers["location"] = url;
return; // CRITICAL: prevents handler continuation
```

## Authorization Error Handling
Always `set.status` BEFORE throwing — otherwise error handler returns 500:
```typescript
set.status = 403;
throw new ForbiddenError("message");
```

## OAuth Authentication
- Redirect URIs MUST point to API, NOT frontend
- `apiUrl: env.API_URL || \`http://localhost:\${env.PORT}\`` — production MUST set `API_URL`
- All redirect URIs must be registered in Azure app registration
- Debug with Playwright network trace for redirects and cookie state

## Cross-Origin Cookies
- `SameSite=Lax` cookies NEVER sent with cross-origin fetch/XHR
- Use origin comparison (not env name) to set `SameSite=None` + `Secure=true` for cross-origin
- Never auto-redirect on 401 in axios interceptors — let React components handle via `useAuth()`

## Drizzle ORM

### `returning()` Shape Mismatch
`db.insert().returning()` returns flat rows, NOT JOIN shape from SELECT:
```typescript
// Wrap in expected shape:
this.rowToEntity({ commission: row, trader: null, company: null, deal: null });
```

### Config Paths
`out` and `schema` in `drizzle.config.ts` resolve from CWD (workspace root via Nx), NOT from config file:
```typescript
out: './apps/domain-api/drizzle/migrations',  // Correct (from root)
```

### Error Wrapping
Drizzle wraps PG errors. `error.message` = "Failed query: <SQL>" (opaque). Actual error in `error.cause.message`:
```typescript
const cause = error instanceof Error && error.cause instanceof Error ? error.cause : null;
```

### Migrations
- Run from monorepo root: `npx drizzle-kit migrate --config apps/domain-api/drizzle.config.ts`
- NEVER `cd` into app dir (paths resolve incorrectly)
- `db:migrate` Nx target needs `envFile` for `DATABASE_URL`
- Docker: copy `drizzle/migrations/` into image, verify with `ls -la`

### drizzle-kit False Success
Can report success without creating tables when connection fails silently. Always verify tables after migration.

## Commission Tables
In `public` schema with `commission_` prefix. Do NOT add `?schema=commission` to DATABASE_URL.
