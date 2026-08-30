---
name: performance
description: 'Analyze and optimize performance: profile slow queries, identify bottlenecks, measure response times, and recommend improvements. Use when the user reports slow pages, API latency, or database performance issues. Do not use for functional bugs (use bug-fix) or infrastructure scaling (use infra-change).'
model: sonnet
disable-model-invocation: true
---

# Performance Analysis Workflow

You are orchestrating performance analysis and optimization.

## Workflow Steps

### Step 1: Problem Identification

Gather information about the performance issue:

- Which endpoint/feature is slow?
- What are the response times?
- When did it start?
- What changed recently?

### Step 2: Performance Analysis

Use the **performance-analyst agent** to:

#### Database Analysis

```bash
# Find potential N+1 queries
grep -rn "for.*await.*find\|forEach.*await" apps/legacy-api/src/

# Find queries without pagination
grep -rn "\.find()" apps/legacy-api/src/ | grep -v "findOne\|findBy"

# Check for missing indexes
# Look for queries filtering by non-indexed columns
```

**Check query patterns:**

- N+1 queries (loop with individual fetches)
- Missing eager loading
- Large result sets without pagination
- Missing indexes on filtered columns
- Missing composite index on `(tradingCompanyId, ...)`

#### API Analysis

- Response payload size
- Unnecessary data fetched
- Missing compression
- Synchronous heavy operations

#### Frontend Analysis

- Bundle size
- Unnecessary re-renders
- Missing memoization
- Large lists without virtualization

### Step 3: Optimization Implementation

Apply optimizations following project patterns:

**Database Optimizations:**

```typescript
// Add eager loading
const invoices = await repo.find({
    relations: ['customer', 'lineItems'],
    where: { tradingCompanyId: tradingCompany.id },
});

// Use query builder for complex queries
const invoices = await repo
    .createQueryBuilder('invoice')
    .leftJoinAndSelect('invoice.customer', 'customer')
    .where('invoice.tradingCompanyId = :companyId', { companyId })
    .take(limit)
    .skip(offset)
    .getMany();

// Add indexes via migration
CREATE INDEX CONCURRENTLY idx_invoice_company_status
ON invoice(trading_company_id, status);
```

**API Optimizations:**

```typescript
// Select only needed columns
const invoices = await repo
    .createQueryBuilder('invoice')
    .select(['invoice.id', 'invoice.invoiceNumber', 'invoice.total'])
    .getMany();

// Implement cursor pagination for large datasets
.andWhere('invoice.id > :cursor', { cursor })
.orderBy('invoice.id', 'ASC')
.take(limit)
```

**Frontend Optimizations:**

```typescript
// Memoize expensive computations
const total = useMemo(() => items.reduce((sum, i) => sum.plus(Big(i.amount)), Big(0)), [items]);

// useCallback for API functions (REQUIRED)
const getInvoices = useCallback(
  async (params) => (await get(url, params)).map(parseInvoice),
  [get]
);
```

### Step 4: Code Review

Use the **review-tech-lead agent** to verify:

- Optimizations follow project patterns
- No regressions introduced
- Big.js used for decimals (not JavaScript numbers)
- Multi-tenancy filtering preserved

### Step 5: Verification

Measure improvement:

- Compare before/after response times
- Check database query plans
- Monitor memory usage
- Verify no functional regressions

## Performance Targets

| Metric | Target |
| ----------------------- | --------------- |
| API response time (p95) | < 200ms |
| Database query time | < 50ms |
| Frontend initial load | < 3s |
| Bundle size | < 500KB gzipped |

## Output

Provide:

- Root cause of performance issue
- Optimizations implemented
- Before/after measurements
- Remaining recommendations
