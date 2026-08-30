# CLAUDE.md - LegacyWeb Frontend

Extends root `CLAUDE.md`. React + MUI + Vite.

## Commands

```bash
npm run frontend:{dev,build,test,lint}
# or: nx run legacy-web:{serve,build,test,lint}
```

## Structure

`src/`: `components/<domain>/` (pages/components), `components/shared/` (forms, tables, modals), `hooks/apis/` (API hooks), `hooks/` (utility), `models/{apiRequests,apiResponses,forms,enums}/`, `helpers/`, `providers/`, `theme/`, `App.tsx`, `AppRoutes.tsx`

`test/`: `components/`, `helpers/`, `hooks/`, `mocks/`, `testBuilders/`, `testHelpers/`, `testUtils.tsx`

## Patterns

- **API hooks**: Domain-specific, use `useLegacyBaseApi`. Wrap in `useCallback`. Parse responses via `parse*` functions to domain models
- **Components**: Domain in `components/<domain>/`, shared in `components/shared/` (FormTextField, FormNumberField, FormDatePicker, DataTable, PaginationFooter, LoadingOverlay, AdminGuard)
- **Pagination**: `usePaginationSearchParams<T>` + `usePaginatedResource` + `usePaginationReset` + `PaginationFooter` + `LoadingOverlay`. Separate filter/pagination params. `disableClientSort` for server-side
- **Context**: `AuthContext`, `TradingCompanyContext`, `ThemeProvider`, `ToastProvider`
- **Toasts**: `useToasts()` → `showSuccessToast()`, `showErrorToast()`
- **Env vars**: Via `getRequiredEnvironmentVariableValue()`, not `import.meta.env`
- **Numbers**: `Big` from `big.js`. Parse strings→Big in response parsers, Big→string for API
- **Imports**: Named only (except lodash default)

## Auth (CRITICAL)

**NEVER modify MSAL scopes.** `scopes: []` in `authConfig.ts` = Microsoft Graph token. Backend validates `appid`+`tid`, calls `/me`. Changing scopes breaks auth entirely. User must exist in `user` table with Entra ID.

## Testing

Custom `render` from `testUtils.tsx` wraps providers. `testBuilders/` for data. Mock API hooks via `jest.mock`. Uses `@swc/jest` (not ts-jest). 4-way CI sharding.
