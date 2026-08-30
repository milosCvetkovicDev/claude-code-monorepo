# Frontend Testing

## Async Data in Tests
- Components with `usePaginatedResource` need: `await waitForElementToBeRemoved(() => screen.getByText('Loading...'))`
- When `waitForElementToBeRemoved` fails: verify API mocks first with `waitFor(() => expect(mockFn).toHaveBeenCalled())`

## False Positives
- Column headers match data values -> `getByText('Entry Description')` finds header not data
- Use unique test values or `findByText` with more specific selectors

## ErpPaymentsPage
- Requires BOTH `filterParams.date` AND `filterParams.erpBankId`, multiple loading states

## Test Sharding
- 4-way in CI (`--shard=N/4`), `--maxWorkers=2`, `NODE_OPTIONS='--max-old-space-size=4096'`

## Jest Configuration
- **legacy-api**: ts-jest only (NO @swc/jest — circular TypeORM entity deps break it)
- **legacy-web**: @swc/jest (no TypeORM, faster)
