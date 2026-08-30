# Severity Labels

Standardized 4-level severity system for all code review findings. Every review agent must use these labels consistently.

## Levels

### Critical

**Definition:** Security vulnerabilities, data loss risk, production outage risk, or correctness bugs that will affect users.

**Action required:** Must fix before merge. Reviewer provides fix recommendation.

**Examples:**

- SQL injection via string concatenation in query
- Missing auth guard on endpoint exposing user data
- Financial calculation using `parseFloat` instead of `Big`
- Race condition that could double-post ERP invoices
- Unhandled promise rejection that crashes the server

**Format in review:**

```
**Critical**: [description]
Fix: [specific recommendation]
```

### Important

**Definition:** Bugs, logic errors, missing error handling, or violations of project conventions that should be addressed.

**Action required:** Should fix before merge. If deferring, create follow-up issue.

**Examples:**

- Missing error handling on database query that could throw
- TypeORM relation not eager-loaded, causing N+1 in loop
- Missing null check on optional field before `.toISOString()`
- Test assertion checking wrong field (test passes but doesn't verify)
- Breaking change to API response without version bump

**Format in review:**

```
**Important**: [description]
```

### Suggestion

**Definition:** Improvements, better patterns, cleaner abstractions, or maintainability enhancements.

**Action required:** Consider for this PR. Author decides.

**Examples:**

- Extract repeated 5-line block into shared utility
- Use `Array.find` instead of `filter()[0]`
- Replace magic number with named constant
- Add TypeScript discriminated union for better type narrowing
- Move business logic from controller to domain service

**Format in review:**

```
*Suggestion*: [description]
```

### Nit

**Definition:** Style preferences, naming, minor readability improvements. No functional impact.

**Action required:** Optional. Author's discretion.

**Examples:**

- Variable name `d` could be `deal` for clarity
- Unnecessary blank line between imports
- Prefer `const` over `let` when not reassigned
- Comment restates what the code already says
- Import ordering inconsistency

**Format in review:**

```
_Nit_: [description]
```

## Usage Rules

1. **Every finding gets a severity label** — No unlabeled comments in reviews
2. **Critical findings include fix recommendations** — Don't just flag; help resolve
3. **Don't inflate severity** — A style issue is a Nit, not Important
4. **Don't minimize real risks** — A security gap is Critical, not Suggestion
5. **Aggregate Nits** — If 5+ Nits of the same kind, mention once with "throughout"
6. **Review summary starts with counts** — "2 Critical, 1 Important, 3 Suggestions, 2 Nits"

## Blocking Rules

| Severity | Blocks Merge?                       |
| ---------- | ----------------------------------- |
| Critical | Yes — must fix |
| Important | Yes — fix or create follow-up issue |
| Suggestion | No |
| Nit | No |
