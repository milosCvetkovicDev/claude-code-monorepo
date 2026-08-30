---
name: design-review
description: "Review UX/UI designs for usability, accessibility, and consistency with the Acme design system (MUI/Material Design). Use when the user shares mockups or wireframes for feedback. Do not use for code review (use code-review) or system architecture review (use review-design)."
model: sonnet
disable-model-invocation: true
---

# Design Review Workflow

Orchestrate a comprehensive design review combining automated inspection, visual analysis, and expert evaluation.

## When to Use

- Reviewing existing UI implementations
- Validating designs match specifications
- Finding usability issues
- Accessibility audits
- Pre-release design QA
- Comparing before/after redesigns

---

## Phase 0: Business Context (MANDATORY)

### Step 0.1: Review Business Requirements

1. Search for relevant requirements:
   ```bash
   ls -la docs/requirements/
   grep -r "{feature-name}" docs/requirements/ docs/business/
   ```
2. Document: feature purpose, target users, success metrics, business constraints (compliance, performance, integration).

### Step 0.2: Research Best Practices for App Type

Run **WebSearch** based on application type:

| Application Type | Research Focus |
| ----------------- | ------------------------------------------------------ |
| **B2B Financial** | Data density, precision, audit trails, bulk operations |
| **Dashboard**     | Information hierarchy, KPI visualization, drill-down |
| **Data Entry**    | Form optimization, validation, error prevention |
| **Workflow**      | Progress indication, status visibility, notifications |
| **Search/Filter** | Faceted search, saved filters, result presentation |

Search queries: `"{app-type} design best practices 2026"`, `"WCAG 2.2 compliance {feature-type}"`

### Step 0.3: Acme-Specific Review Criteria

Verify these domain requirements for the B2B Trading/Financial Platform:

| Criteria | Check | Why |
| --------------------- | ------------------------------ | --------------------- |
| **Multi-tenancy**     | Data scoped to trading company | Security |
| **Decimal precision** | 4 decimal places visible | Financial accuracy |
| **Audit info**        | Created/updated by/at shown | Compliance |
| **Currency display**  | Symbol + proper formatting | Clarity |
| **Date format**       | Consistent, timezone-aware | Global users |
| **Status colors**     | Follow established palette | Consistency |
| **Empty states**      | Helpful with CTA               | User guidance |
| **Error messages**    | Actionable, not technical | User experience |
| **Loading states**    | Skeleton, not spinner | Perceived performance |
| **Bulk actions**      | Available for list views | Efficiency |

---

## Phase 1: Visual Capture

### Step 1: Screenshot Capture

1. Start the frontend if not running:
   ```bash
   npm run frontend:dev &
   sleep 5
   ```
2. Capture screenshots at desktop (1920x1080), mobile (375x667), and tablet (768x1024) viewports.

See `references/playwright-scripts.md` for the full capture script.

### Step 2: DOM Inspection

Extract MUI component structure, color usage, and typography hierarchy from the page.

See `references/playwright-scripts.md` for the DOM inspection script.

### Step 3: Accessibility Scan

Check for missing alt text, missing form labels, focusable elements, and color contrast issues.

See `references/playwright-scripts.md` for the accessibility scan script.

---

## Phase 2: UX Analysis

### Step 4: UX Expert Review

Use the **ux-expert agent** with screenshots, page URL, user persona context, and flow documentation.

Analysis focus:
- Information architecture
- User flow optimization
- Cognitive load assessment
- Nielsen's heuristics evaluation
- Form design review
- Error handling patterns
- Accessibility compliance

### Step 5: User Flow Mapping

Document the current user flow:

```
User Flow: {Task Name}
┌─────────────┐
│ Entry Point │
└──────┬──────┘
       │
       ▼
┌─────────────┐    ┌─────────────┐
│   Step 1    │───▶│  Step 2     │
└──────┬──────┘    └──────┬──────┘
       │                  │
       ▼                  ▼
┌─────────────┐    ┌─────────────┐
│  Success    │    │   Error     │
└─────────────┘    └─────────────┘
```

Flag issues per step: `Step X: {Description of UX issue}`

---

## Phase 3: UI Analysis

### Step 6: UI Expert Review

Use the **ui-expert agent** with screenshots, component data, and MUI theme configuration.

Analysis focus: theme compliance, component usage correctness, spacing/alignment, typography hierarchy, color consistency, responsive behavior, loading/empty states, visual feedback patterns.

### Step 7: Component Audit

Create an inventory of components used:

| Component | Count | Variants Used | Issues |
| --------- | ----- | ------------- | ------ |
| Button | 12    | contained, outlined | 2 using wrong variant |
| TextField | 8     | outlined | 1 missing label |

Flag any custom components that should use MUI equivalents.

---

## Phase 4: Automated Testing

### Step 8: Visual Regression & Interaction Testing

See `references/test-templates.md` for:
- Visual regression setup (baseline comparison with pixel diff thresholds)
- Interaction state testing (hover, focus, disabled, validation error states)

---

## Phase 5: Synthesis & Recommendations

### Step 9: Consolidate Findings

Combine findings from all phases:

| Metric | Score | Target |
| --------------------- | ----- | ------ |
| Accessibility | —%    | 100%   |
| Theme Compliance | —%    | 95%    |
| Component Consistency | —%    | 95%    |
| Responsive Support | —%    | 100%   |

Categorize UX and UI findings by severity: **Critical**, **High Priority**, **Medium**, **Low**.

### Step 10: Action Items

Prioritize improvements into three tiers:
1. **Immediate** (before release): accessibility violations, contrast issues, missing loading states
2. **Short Term** (next sprint): component refactors, error state consistency, responsive breakpoints
3. **Long Term** (backlog): design system documentation, visual regression CI, user testing sessions

---

## Output

Produce a design review report containing:
- **Executive Summary** (2-3 sentences)
- **Screenshots** link
- **Findings by Category**: UX issues, UI issues, accessibility, visual regression
- **Recommendations**: Must Fix (with owner/deadline), Should Fix, Nice to Have
- **Next Steps**: create tickets, schedule design sync, set up visual regression CI

See `references/additional-tools.md` for DevTools, Figma comparison, Lighthouse, and Storybook integration options.
