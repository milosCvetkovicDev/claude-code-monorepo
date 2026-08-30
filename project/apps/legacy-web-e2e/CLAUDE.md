# CLAUDE.md - E2E Tests (Playwright)

Extends root `CLAUDE.md`.

## Commands

```bash
npx nx run legacy-web-e2e:e2e                          # All tests
npx nx run legacy-web-e2e:e2e -- --headed               # See browser
npx nx run legacy-web-e2e:e2e -- --grep="@smoke"        # By tag
npx nx run legacy-web-e2e:e2e -- src/auth/login.spec.ts # Specific file
npx nx run legacy-web-e2e:e2e -- --debug                # Debug mode
```

## Structure

`src/`: `auth/`, `invoices/`, `erp/`, `erp-mock/` (invoice/sync/error/payment/edge-case tests), `customers/`, `deals/`, `fixtures/` (auth, mock-api, erp-mock-api, test-data), `pages/` (POM classes), `global-setup.ts`

## Patterns

- **Page Object Model**: All interactions via `src/pages/` classes extending `BasePage`/`BaseInvoicesPage`. Never use raw selectors in tests
- **Route interception** (`mockApi`): Test UI error handling. Always `clearMocks` in `afterEach`
- **Backend mock mode** (`erpMockApi`): Full integration with `USE_ERP_MOCK=true`. `setupErpMock`/`teardownErpMock` in before/afterEach
- **Waits**: Use `expect(element).toBeVisible()` or `toPass()` polling — never `waitForTimeout`
- **Missing data**: `test.skip` when prerequisites unavailable

## Tags

| Tag | When |
| ------------ | ---------------------------- |
| `@smoke`     | Every PR                     |
| `@erp`      | ERP changes (real API)      |
| `@erp-mock` | ERP workflow changes (mock) |
| `@crud`      | Frontend changes |
| `@auth`      | Auth changes |

## Auth

`global-setup.ts` handles Entra ID login with TOTP/MFA → saves to `.auth/user.json`. Test user: `someone@initech.example`. Env vars: `E2E_BASE_URL`, `E2E_TEST_USER_EMAIL`, `E2E_TEST_USER_PASSWORD`, `E2E_TEST_USER_TOTP_SECRET`.

## CI

Smoke on PRs, full suite with 4-way sharding on main. ERP mock: dedicated `e2e-erp-mock.yml` workflow.
