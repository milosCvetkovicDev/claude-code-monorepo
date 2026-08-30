# Accessibility Review Checklist

WCAG 2.1 AA aligned, MUI-specific. Use during code review for any changes touching UI components, forms, or navigation.

## Semantic HTML

- [ ] **Correct heading hierarchy** — `h1` > `h2` > `h3`, no skipped levels; MUI: use `Typography variant="h1"` etc.
- [ ] **Landmark elements used** — `<main>`, `<nav>`, `<aside>`, `<header>`, `<footer>` for page structure
- [ ] **Lists use list elements** — `<ul>`/`<ol>` for lists, not styled `<div>` sequences
- [ ] **Tables for tabular data** — Use `<table>` with `<thead>`/`<tbody>`, not grid divs; MUI: `<Table>` component
- [ ] **Buttons for actions, links for navigation** — MUI `<Button>` for actions, `<Link>` for navigation

## Keyboard Navigation

- [ ] **All interactive elements focusable** — Tab order follows logical reading order
- [ ] **Focus visible** — Focus indicators visible on all interactive elements; don't remove MUI's default focus ring
- [ ] **Escape closes dialogs** — MUI `<Dialog>` handles this by default; verify custom modals do too
- [ ] **Enter/Space activates controls** — Custom interactive elements respond to keyboard, not just mouse
- [ ] **Skip navigation link** — Long pages have skip-to-content link for keyboard users
- [ ] **No keyboard traps** — Tab can exit every component; modals trap focus but Escape releases

## ARIA Labels

- [ ] **Icon buttons have labels** — MUI `<IconButton aria-label="description">` always set
- [ ] **Form inputs have labels** — MUI `<TextField label="">` or explicit `<InputLabel>` + `htmlFor`
- [ ] **Images have alt text** — Decorative images: `alt=""`; informative images: descriptive `alt`
- [ ] **Loading states announced** — Use `aria-busy="true"` and `aria-live="polite"` for async content
- [ ] **Custom components have roles** — Non-standard interactive elements have appropriate `role` attribute

## Color & Contrast

- [ ] **Text contrast >= 4.5:1** — Normal text against background meets WCAG AA
- [ ] **Large text contrast >= 3:1** — Text >= 18pt (or 14pt bold) meets minimum ratio
- [ ] **Information not conveyed by color alone** — Error states use icons/text in addition to red color
- [ ] **MUI theme colors checked** — Custom theme overrides maintain contrast ratios

### Measurement

```bash
# Run axe-core accessibility scan
npx axe-core-cli http://localhost:4200
# Or use browser DevTools > Lighthouse > Accessibility
```

## Forms

- [ ] **Error messages linked to fields** — MUI `<TextField error helperText="...">` connects error to input
- [ ] **Required fields indicated** — Visually and with `aria-required="true"` or `required` attribute
- [ ] **Error summary on submit** — Form-level validation shows summary of all errors
- [ ] **Autocomplete attributes set** — `autoComplete="email"`, `autoComplete="current-password"` etc.
- [ ] **Inline validation announced** — Dynamic validation uses `aria-live` region

## Dynamic Content

- [ ] **Route changes announced** — Page title updates on navigation; screen reader notified
- [ ] **Toast/Snackbar accessible** — MUI `<Snackbar>` uses `role="alert"` or `aria-live`
- [ ] **Loading skeletons have labels** — MUI `<Skeleton>` wrapped with `aria-label="Loading..."`
- [ ] **Infinite scroll has alternative** — Provide "Load more" button alongside infinite scroll

## Data Tables (MUI DataGrid)

- [ ] **Column headers descriptive** — `headerName` clearly describes column content
- [ ] **Sort state announced** — `aria-sort` attribute on sortable columns
- [ ] **Row selection announced** — Selected rows have `aria-selected="true"`
- [ ] **Pagination controls labeled** — Next/previous buttons have descriptive labels
