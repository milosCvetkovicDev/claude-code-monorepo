# Database Verification Queries

Connect to the development database:

```bash
PGPASSWORD=postgres psql -h localhost -U legacy -d legacy_development
```

## Why this file exists

Local end-to-end flows fail far more often because the **seeded data does not meet the flow's
preconditions** than because the code is wrong. Debugging the code first, on a database that
could never have produced the expected result, is the single most expensive mistake in local
troubleshooting.

So: for each flow you test regularly, keep a short list of queries that answer, before you start,

1. **Does a record in the required starting state exist?** (the flow's entry condition)
2. **Are the relations the flow reads actually populated?** (a null FK usually yields an empty
   result rather than an error — see `webhook-test-flow.md`)
3. **How do I put a record back into that starting state?** (so the flow is repeatable without
   a full re-seed)

The queries below answer those three questions for the deal-lock → commission flow. They are the
worked example; the shape transfers to any other flow.

## 1. Who can be assigned — users in the role the flow needs

```sql
SELECT id, "displayName", role, "tradingCompanyId"
FROM "user"
WHERE role = 'Trader'
ORDER BY id;
```

Two quoting rules that bite in every one of these queries: `user` is a reserved word, so
`FROM user` is a syntax error and the table must be written `"user"`; and PostgreSQL folds
unquoted identifiers to lower case, so the camelCase columns TypeORM created (`traderId`,
`dealId`, `isLocked`, `tradingCompanyId`) must be double-quoted or they fail as `traderid does
not exist`.

## 2. Candidate records in the starting state, with their relation counts

```sql
SELECT
  d.id AS deal_id,
  d.number,
  d."isLocked",
  COUNT(DISTINCT p."traderId") AS trader_count
FROM deal d
JOIN purchase p ON p."dealId" = d.id
WHERE p."traderId" IS NOT NULL
GROUP BY d.id, d.number, d."isLocked"
ORDER BY d.id DESC;
```

This is the one query worth running before anything else. It lists deals newest first with their
lock state and their trader count together, so a usable fixture is one row: `isLocked = false`
with a non-zero `trader_count`. The inner join to `purchase` is what makes the omissions visible
by absence — a deal with no trader-bearing purchase never appears at all, and that is exactly the
deal the flow would process into zero records, successfully, with nothing in any log to say why.

## 3. Which specific rows are missing the link

```sql
SELECT p.id, p."traderId", u."displayName"
FROM purchase p
LEFT JOIN "user" u ON u.id = p."traderId"
WHERE p."dealId" = <deal-id>;
```

The `LEFT JOIN` is deliberate: an inner join hides exactly the rows you are looking for.

## 4. Populate the missing link

```sql
UPDATE purchase SET "traderId" = <trader-id> WHERE id = <purchase-id>;
```

## 5. Reset the record so the flow can be re-run

```sql
UPDATE deal SET "isLocked" = false WHERE id = <deal-id>;
```

Keep this one to hand. A one-shot flow you can only test once per seed gets tested once, and
then guessed at.

**Write straight to the database only in local development.** These are debugging aids, not a
substitute for the application's own transitions — a row updated by hand skips everything the
service would have written alongside it, which is its own class of confusing local bug. Query 4
in particular sets the FK without any of the bookkeeping the assignment endpoint performs; use it
to unblock a test, not to build a fixture you intend to keep.
