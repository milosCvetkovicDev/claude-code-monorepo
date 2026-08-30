# Security Review Checklist

Acme-specific security checklist aligned with OWASP Top 10. Use during code review for any changes touching auth, data access, or user input.

## Input Validation

- [ ] **Request body validated** — Express: `express-validator` middleware; NestJS: `class-validator` DTOs with `@IsString()`, `@IsNumber()`, `@IsEmail()`, etc.
- [ ] **Query parameters validated** — No raw `req.query` usage without type coercion and bounds checking
- [ ] **File uploads validated** — File type whitelist, size limits, no path traversal in filenames
- [ ] **Numeric inputs use Big** — Financial values parsed with `Big()` from `big.js`, never `parseFloat`
- [ ] **Date inputs validated** — ISO format enforced, UTC timezone, no timezone-dependent logic

## Authentication & Authorization

- [ ] **JWT verified on every protected route** — Express: `authMiddleware`; NestJS: `@UseGuards(AuthGuard)`
- [ ] **Role-based access enforced** — Check user roles before data access, not just route-level
- [ ] **Entity-level permission flags enforced at the data layer** — a flag on the record that narrows what its owner may do is checked where the data is read, not only on the route; a route-only check is bypassed by every other caller of the same repository
- [ ] **No privilege escalation** — Users cannot access other users' data by manipulating IDs
- [ ] **API keys not in code** — All secrets in Azure Key Vault, accessed via helper functions

## SQL Injection Prevention

- [ ] **TypeORM parameterized queries** — Use `.where("column = :value", { value })`, never string concatenation
- [ ] **MikroORM QueryBuilder** — Use `.where({ field: value })` object syntax, not raw SQL
- [ ] **Raw SQL uses parameters** — If raw SQL is unavoidable: `query($1, $2)` with parameter array
- [ ] **Column names use snake_case** — DB columns are snake_case; never interpolate camelCase into SQL

## Cross-Site Scripting (XSS)

- [ ] **No `dangerouslySetInnerHTML`** — If absolutely needed, sanitize with DOMPurify first
- [ ] **React JSX auto-escaping** — Rely on JSX escaping; don't bypass it
- [ ] **User content in attributes** — URLs and attributes from user input validated/sanitized
- [ ] **CSP headers set** — Content-Security-Policy configured in production

## Secrets Management

- [ ] **No `process.env` direct access** — Use helper functions from config module
- [ ] **No hardcoded secrets** — No API keys, passwords, or tokens in source code
- [ ] **gitleaks clean** — Run `gitleaks detect` on staged changes before commit
- [ ] **Environment variables documented** — New env vars listed in deployment docs
- [ ] **Azure Key Vault for production** — Secrets stored in Key Vault, referenced via app settings

## CORS & Rate Limiting

- [ ] **CORS whitelist specific origins** — No wildcard `*` in production
- [ ] **Rate limiting on auth endpoints** — Login, registration, password reset rate-limited
- [ ] **Rate limiting on API endpoints** — Prevent abuse of data-heavy endpoints

## Data Protection

- [ ] **PII logging prohibited** — No email, name, or financial data in logs
- [ ] **Audit trail for sensitive operations** — Financial transactions, role changes logged
- [ ] **Soft delete for financial records** — Never hard-delete commission or deal data
- [ ] **Database connections use SSL** — PostgreSQL connections require SSL in production

## Dependency Security

- [ ] **npm audit clean** — No critical or high vulnerabilities
- [ ] **No deprecated packages** — Check for deprecated dependencies
- [ ] **Lock file committed** — `package-lock.json` in sync with `package.json`
