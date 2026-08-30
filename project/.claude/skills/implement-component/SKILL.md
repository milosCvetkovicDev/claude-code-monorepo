---
name: implement-component
description: "Implement a React component with MUI styling, TypeScript types, and tests. Use when the user has a spec or clear requirements for a specific UI component. Do not use for backend components (use implement-endpoint) or full-page features without a spec (use design-ui)."
model: sonnet
disable-model-invocation: true
args: <component-name> [--page <parent-page>]
---

# Implement React Component

## Input

- **component-name**: Name of the component (PascalCase, e.g., `InvoiceTable`)
- **page** (optional): Parent page to add the component to

## Workflow

### Step 1: Analyze Requirements

1. Determine component type:
   - **Page component**: Full page in `src/pages/`
   - **Feature component**: Feature-specific in `src/components/<feature>/`
   - **Shared component**: Reusable in `src/components/shared/`
2. Check for similar components to follow patterns
3. Identify data requirements (API calls, props)

### Step 2: Create Component File

Create `apps/legacy-web/src/components/<feature>/<ComponentName>.tsx` using the component template from `references/component-templates.md`. Define the props interface with data, callbacks, and loading state.

### Step 3: Create Hooks (if needed)

Create `apps/legacy-web/src/hooks/use<Feature>.ts` with:
- `use<Feature>Query` — wraps `useQuery` with appropriate query key and fetch function
- `use<Action><Feature>Mutation` — wraps `useMutation` with cache invalidation on success

### Step 4: Add to Parent (if --page specified)

Import and render the component in the parent page. Pass data from the query hook, loading state, and callback handlers.

### Step 5: Add data-testid Attributes

Add `data-testid` to key elements using the convention `<component-name>-<element>`:
- `<component-name>-container`, `<component-name>-table`, `<component-name>-submit-button`

### Step 6: Write Tests

Create `<ComponentName>.spec.tsx` using the test template from `references/component-templates.md`. Test rendering, callbacks, loading state, and empty state.

### Step 7: Export from Index

```typescript
// apps/legacy-web/src/components/<feature>/index.ts
export { <ComponentName> } from './<ComponentName>';
```

### Step 8: Verify

1. Run tests: `nx run legacy-web:test -- --testPathPattern=<ComponentName>`
2. Run lint: `nx run legacy-web:lint`
3. Visual check: `nx run legacy-web:serve`

## Output

````markdown
## Component Implemented: <ComponentName>

### Files Created/Modified

- `src/components/<feature>/<ComponentName>.tsx` (created)
- `src/components/<feature>/<ComponentName>.spec.tsx` (created)
- `src/components/<feature>/index.ts` (modified)
- `src/hooks/use<Feature>.ts` (created, if needed)
- `src/pages/<ParentPage>.tsx` (modified, if --page specified)

### Props Interface

```typescript
interface <ComponentName>Props {
  data: <DataType>[];
  onSelect?: (item: <DataType>) => void;
  loading?: boolean;
}
```
````

### Test IDs Added

- `<component-name>-container`
- `<component-name>-table`
- `<component-name>-submit-button`

### Verification

| Check | Status |
| ------ | ------ |
| Tests | ✅     |
| Lint | ✅     |
| Visual | ✅     |

## Conventions

- Use MUI components for UI
- Use React Query for data fetching
- Add `data-testid` attributes for E2E testing
- Write tests for all interactive behavior
- Use TypeScript interfaces for props
- Export from index.ts for clean imports
- Loading and empty states required
