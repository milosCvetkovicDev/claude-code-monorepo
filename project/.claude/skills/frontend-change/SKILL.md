---
name: frontend-change
description: "Implement frontend changes using React, MUI, and TypeScript in the Acme legacy-web or domain-web apps. Use when the user wants to modify UI components, add client-side features, or fix frontend bugs. Do not use for backend/API changes (use api-change) or new component design from scratch (use design-ui)."
model: sonnet
---

# Frontend Change Workflow

You are orchestrating a frontend change following React and MUI best practices.

## Workflow Steps

### Step 0: Business Context (MANDATORY for new features)

**For significant UI changes**, review business requirements first:

```bash
# Check for related requirements
ls -la docs/requirements/
grep -r "{feature-name}" docs/requirements/ docs/business/
```

If designing new UI, use the **ux-expert agent** and **ui-expert agent** to:

- Validate the user flow makes sense for the persona
- Ensure UI patterns match B2B financial app standards
- Check accessibility requirements
- Plan responsive behavior

### Step 1: Understand the Change

Clarify the frontend requirements:

- What component(s) need modification?
- Is this a new component or modification?
- Does it need API integration?
- What's the expected UI/UX behavior?
- Which user persona is this for?

### Step 2: Component Design

Use the **frontend-specialist agent** to design:

- Component structure and props interface
- State management approach (local, context, TanStack Query)
- Data flow and API integration points

**Component Location:**

```
apps/legacy-web/src/
├── components/          # Reusable components
├── pages/               # Route-level components
├── hooks/               # Custom hooks
├── api/                 # API integration
└── utils/               # Utilities
```

### Step 3: Implementation

#### TypeScript Interfaces

```typescript
// Props interface
interface InvoiceListProps {
  companyId: string;
  onSelect: (invoice: Invoice) => void;
}

// Response type (from API - strings)
interface InvoiceResponse {
  id: string;
  total: string; // Decimal as string
}

// Domain type (Big.js for calculations)
interface Invoice {
  id: string;
  total: Big;
}
```

#### API Hook Pattern (CRITICAL)

```typescript
// MUST use useCallback
const getInvoices = useCallback(
  async (params?: QueryParams): Promise<Invoice[]> =>
    (await get<InvoiceResponse[]>(url, params)).map(parseInvoice),
  [get]
);

// Parser converts strings to Big
const parseInvoice = (r: InvoiceResponse): Invoice => ({
  ...r,
  total: Big(r.total),
});
```

#### Component Pattern

```typescript
export const InvoiceList: React.FC<InvoiceListProps> = ({ companyId, onSelect }) => {
  const { data, isLoading, error } = useInvoices(companyId);

  if (isLoading) return <CircularProgress />;
  if (error) return <Alert severity="error">{error.message}</Alert>;

  return (
    <List>
      {data?.map((invoice) => (
        <ListItem key={invoice.id} onClick={() => onSelect(invoice)}>
          {invoice.id}
        </ListItem>
      ))}
    </List>
  );
};
```

### Step 4: MUI Styling

Follow MUI theme patterns:

```typescript
// Use theme spacing (not hardcoded px)
<Box sx={{ p: 2, mb: 3 }}>

// Use theme colors
<Typography color="text.primary">

// Use responsive breakpoints
<Grid xs={12} md={6}>
```

### Step 5: Testing

Write component tests:

```typescript
// Test loading state
it('shows loading spinner while fetching', () => {
  render(<InvoiceList companyId="123" onSelect={jest.fn()} />);
  expect(screen.getByRole('progressbar')).toBeInTheDocument();
});

// Test data display
it('renders invoice list', async () => {
  render(<InvoiceList companyId="123" onSelect={jest.fn()} />);
  await waitFor(() => {
    expect(screen.getByText('INV-001')).toBeInTheDocument();
  });
});
```

### Step 6: E2E Considerations

Add `data-testid` for E2E tests:

```typescript
<Button data-testid="approve-invoice-btn">Approve</Button>
<Table data-testid="invoices-table">
```

### Step 7: Code Review

Use the **review-tech-lead agent** to verify:

- useCallback for all API functions
- Big.js for decimal handling
- Proper TypeScript types (no `any`)
- MUI theme usage

## Checklist

- [ ] TypeScript interfaces defined
- [ ] API hooks use useCallback
- [ ] Response parsing converts strings to Big
- [ ] Loading and error states handled
- [ ] MUI theme values used (not hardcoded)
- [ ] data-testid attributes added
- [ ] Component tests written

## Output

Provide:

- Components created/modified
- API hooks added
- Test coverage
- Screenshots (if visual changes)


## Assumptions Gate

Before starting implementation, explicitly state your assumptions:

```
ASSUMPTIONS:
- [ ] {assumption about requirements}
- [ ] {assumption about architecture}
- [ ] {assumption about scope}
→ Correct me now or I will proceed with these.
```

Present assumptions as a checkbox list. Wait for user confirmation before proceeding. Do not silently fill in ambiguous requirements.
