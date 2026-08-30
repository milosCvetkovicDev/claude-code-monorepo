# Review Checklists

## Code Quality

- [ ] No `any` types
- [ ] Clear, descriptive function names
- [ ] Functions do one thing (SRP)
- [ ] Error handling present
- [ ] No commented-out code
- [ ] Imports organized

## Architecture

- [ ] Clean Architecture layers respected
- [ ] Dependencies flow inward
- [ ] Domain layer has no external dependencies
- [ ] Proper separation of concerns
- [ ] Dependency injection used

## Testing

- [ ] Unit tests for business logic
- [ ] Integration tests for API endpoints
- [ ] E2E tests for critical user flows
- [ ] Tests are clear and maintainable
- [ ] Edge cases covered

## Security

- [ ] No SQL injection risks
- [ ] Input validation present
- [ ] Authentication/authorization checked
- [ ] Secrets not hardcoded
- [ ] No XSS vulnerabilities

## Performance

- [ ] No N+1 query issues
- [ ] Efficient algorithms
- [ ] No unnecessary database calls
- [ ] Indexes used appropriately
- [ ] Async operations don't block

## Conventions

- [ ] Follows CLAUDE.md guidelines
- [ ] Consistent with existing patterns
- [ ] Proper naming conventions
- [ ] Correct import conventions
- [ ] Big.js for decimals

## Common Anti-Patterns to Flag

```typescript
// SQL injection risk
const query = `SELECT * FROM users WHERE email = '${email}'`;

// No error handling
const data = await fetchData();

// Using any type
const process = (data: any) => { ... };

// Hardcoded secret
const API_KEY = 'sk-1234567890';

// N+1 query
for (const user of users) {
  const orders = await getOrdersForUser(user.id);
}
```
