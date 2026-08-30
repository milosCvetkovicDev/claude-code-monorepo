---
name: design-ui
description: "Design and implement UI features using React and MUI in the Acme frontend. Use when the user needs new pages or visual features from requirements without a pre-existing design. Do not use when a spec exists (use implement-component) or for backend changes (use api-change)."
model: sonnet
disable-model-invocation: true
---

# Design UI Workflow

Orchestrate the design and implementation of new user interfaces, combining UX research, UI design, and implementation best practices.

## When to Use

- Creating new pages or views
- Designing new components
- Building complex forms
- Creating data tables or dashboards
- Implementing new user workflows

---

## Phase 0: Business Context Research (MANDATORY)

### Step 0.1: Consult Business Requirements

1. Search for existing requirements:
   ```bash
   ls -la docs/requirements/
   grep -r "{feature-name}" docs/requirements/ docs/business/
   ```
2. If no requirements exist, use the **interview-user agent** to gather business goals, target personas, compliance constraints, and integration points.

### Step 0.2: Research Industry Best Practices

Run **WebSearch** queries:
- `"{app-type} UX best practices 2026"`
- `"{feature-type} design patterns enterprise"`
- `"{industry} application UI guidelines"`

Document findings: application type, key practices with sources, competitor examples, regulatory considerations.

### Step 0.3: Acme-Specific Guidelines

Acme is a **B2B Trading/Financial Platform**. Apply these domain rules:

| Aspect | Guideline | Rationale |
| ------------------- | ---------------------------------- | -------------------------- |
| **Data Density**    | High — show more data, fewer clicks | Finance users need overview |
| **Precision**       | Always show full decimal precision | Financial accuracy critical |
| **Audit Trail**     | Show who/when for all changes | Compliance requirement |
| **Bulk Operations** | Essential for efficiency | Users manage many records |
| **Export**          | Multiple formats (CSV, Excel, PDF) | Reporting needs |
| **Date Handling**   | Clear timezone indication | Multi-region trading |
| **Currency**        | Always show currency symbol | Avoid confusion |
| **Status**          | Prominent, color-coded | Quick scanning |
| **Confirmation**    | Double-confirm financial actions | Prevent errors |
| **Search**          | Powerful, saved filters | Repeat queries common |

---

## Phase 1: Requirements & Context

### Step 1: Understand the Feature

Gather and document:
- **Feature Name**, **User Persona**, **Primary Goal**
- **Entry Point** (how users arrive) and **Exit Point** (where they go after)
- **Functional Requirements** checklist
- **Data Requirements**: input, output, display

### Step 2: Review Existing Patterns

Examine similar features in the codebase:
```bash
ls -la apps/legacy-web/src/pages/
grep -r "useQuery" apps/legacy-web/src/pages/ --include="*.tsx" | head -10
grep -r "DataGrid\|Table" apps/legacy-web/src/pages/ --include="*.tsx" | head -10
```

---

## Phase 2: UX Design

### Step 3: UX Expert Consultation

Use the **ux-expert agent** to define:
- User flow (entry → steps → completion)
- Information hierarchy (primary, secondary, tertiary)
- Cognitive load concerns
- Error handling approach (validation display, server errors, not-found)
- Accessibility requirements (keyboard nav, screen reader, focus management, contrast)
- Form design (required fields, groupings, validation approach, defaults)

### Step 4: Wireframe/Layout Planning

Create ASCII wireframes for key states:

```
┌─────────────────────────────────────────────────┐
│ Page Title                           [Action Btn]│
├─────────────────────────────────────────────────┤
│ [Search...] [Filter ▼] [Date Range]              │
├─────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────┐ │
│  │ Data Table / Content Area                   │ │
│  └─────────────────────────────────────────────┘ │
│  ◀ 1 2 3 ... 10 ▶  Showing 1-20 of 200          │
└─────────────────────────────────────────────────┘
```

Design states: Loading, Empty, Error, Success, Partial data.

---

## Phase 3: UI Design

### Step 5: UI Expert Consultation

Use the **ui-expert agent** to define:
- MUI component selection per feature element
- Spacing and layout structure
- Responsive breakpoints

| Breakpoint | Layout Change |
| ---------- | ---------------------------- |
| xs (0+)    | Stack vertically, full width |
| sm (600+)  | 2-column filters |
| md (900+)  | Side-by-side layout |
| lg (1200+) | Full desktop experience |

- Loading states (skeleton), empty states (icon + message + CTA), error states (alert + retry)

---

## Phase 4: Implementation

### Step 6: Plan Component Hierarchy

```
FeaturePage/
├── index.tsx                # Main page component
├── FeaturePage.tsx           # Page layout and state
├── components/
│   ├── FeatureFilters.tsx    # Filter controls
│   ├── FeatureTable.tsx      # Data table
│   ├── FeatureForm.tsx       # Form (if needed)
│   └── FeatureEmpty.tsx      # Empty state
├── hooks/
│   └── useFeatureData.ts     # Data fetching hook
└── types.ts                  # TypeScript interfaces
```

### Step 7: Implement Components

See `references/implementation-templates.md` for complete templates:
- **Page component** with header, filters, and content area
- **Data hook** with useQuery, filters, and pagination
- **Table component** with sorting, pagination, and action buttons

See `references/mui-patterns.md` for reusable MUI snippets:
- Page layout, filter bar, empty state, loading skeleton

---

## Phase 5: Review & Polish

### Step 8: Design Review

Run the **design-review** skill to capture screenshots, verify accessibility, check theme compliance, and test all states.

### Step 9: Code Review

Use the **review-tech-lead agent** to verify React best practices, TypeScript quality, performance (memoization, re-renders), and error handling.

### Step 10: Accessibility Testing

```bash
npx playwright test accessibility.spec.ts --grep="FeaturePage"
```

Manually verify: tab through all interactive elements, confirm visible focus, verify screen reader announcements.

---

## Output Checklist

- [ ] UX specification documented
- [ ] UI specification documented
- [ ] Page component implemented
- [ ] Data hook implemented with useCallback
- [ ] Loading state (skeleton)
- [ ] Empty state
- [ ] Error state
- [ ] Responsive breakpoints tested
- [ ] Keyboard navigation works
- [ ] Screen reader compatible
- [ ] Design review passed
- [ ] Code review passed
