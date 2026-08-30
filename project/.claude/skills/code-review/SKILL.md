---
name: code-review
description: "Review code changes in commits or pull requests for quality, security, performance, and architecture compliance. Use when the user asks to review a commit, PR, diff, or recent changes. Do not use for design reviews, spec reviews, or non-code artifacts."
---

# Code Review

Review code changes (commit, PR, or diff) and provide actionable, categorized feedback.

## Step 1: Identify the Changes

Determine the review target:

- If given a commit hash: `git show <hash>`
- If given a PR number: `gh pr diff <number>`
- If no argument: review the most recent commit via `git log -1 --oneline`

## Step 2: Analyze the Changes

1. Run `git diff` or `gh pr diff` to get the full changeset.
2. Read each modified file using the Read tool.
3. Identify the scope: which layers, domains, and services are affected.

## Step 3: Review Against Standards

Evaluate changes against these categories:

| Category | Focus |
|----------|-------|
| Code Quality | Readability, TypeScript best practices, error handling, no `any` types |
| Architecture | Clean Architecture layers, SOLID, DDD patterns, dependency injection |
| Testing | Coverage for new code, test quality, missing edge cases |
| Security | SQL injection, XSS, auth issues, secret handling, input validation |
| Performance | Query efficiency, N+1 risks, nested iterations, memory leaks |
| Conventions | CLAUDE.md guidelines, naming, import conventions, Big.js for decimals |

See `.claude/references/review/` for detailed checklists (loaded on-demand by file type).

## Step 4: Launch Specialized Agents (if needed)

For large changesets, dispatch specialized review agents:

- `review-tech-lead` — General code quality and team practices
- `review-enterprise-architect` — Architecture and system design
- `review-test-architect` — Test strategy and quality
- `security-auditor` — Security vulnerabilities
- `performance-analyst` — Performance issues

## Step 5: Produce Structured Output

Categorize findings by severity:

Use the standardized 4-level severity from `.claude/references/review/severity-labels.md`:
- **Critical**: Security vulnerabilities, data loss, production outage. Must fix.
- **Important**: Bugs, logic errors, missing error handling. Should fix.
- **Suggestion**: Improvements, better patterns. Consider.
- **Nit**: Style, naming. Optional.

Output the review in this format:

```markdown
# Code Review

## Verdict
[APPROVE | CONDITIONAL APPROVAL | REQUEST CHANGES | REJECT]

## Summary
- Files changed: N
- Lines added/removed: +X -Y
- Critical issues: N
- High priority: N
- Medium priority: N

## Critical Issues (MUST FIX)
### 1. [Issue Title]
- **Location**: file.ts:line
- **Problem**: [Description]
- **Impact**: [Business/technical impact]
- **Fix**: [Specific recommendation with code]

## High Priority (SHOULD FIX)
[Same format]

## Medium Priority (NICE TO HAVE)
[Same format]

## Positive Callouts
- [Good pattern 1]

## Testing Assessment
- Unit tests: [YES/NO]
- Integration tests: [YES/NO]
- Missing tests for: [List]

## Approval Conditions
- [ ] Condition 1
```

## Project Context

- **Stack**: Node.js, TypeScript, Express, TypeORM, PostgreSQL, React, MUI
- **Architecture**: Clean Architecture, DDD, SOLID principles
- **Testing**: Jest (unit/integration), Playwright (E2E)
- **Conventions**: See root CLAUDE.md and app-specific CLAUDE.md files

## Anti-Rationalization Table

| If you're thinking... | Remember... |
|----------------------|-------------|
| "The tests pass so it must be correct" | Tests can have gaps. Check edge cases, error paths, and boundary conditions manually. |
| "This is a simple change, no review needed" | Simple changes cause the most insidious bugs. Small diffs deserve the same scrutiny. |
| "I'll clean this up later" | Tech debt compounds. If you see it now, flag it now — at least as a Suggestion. |

## Checklist Routing by File Type

Load review checklists based on changed file patterns:

| Changed Files | Load Checklists |
|--------------|----------------|
| `apps/legacy-api/**`, `apps/platform/**`, `libs/**/*.ts` | security-checklist.md + performance-checklist.md |
| `apps/legacy-web/**`, `apps/domain-web/**` | security-checklist.md + performance-checklist.md + accessibility-checklist.md |
| `infra/**`, `.github/**`, `charts/**` | security-checklist.md |
| `docs/**` | (no checklist — documentation review only) |

Checklists are at `.claude/references/review/`. Load on-demand, not pre-loaded.

## Severity Labels

Use standardized severity labels for all findings. See `.claude/references/review/severity-labels.md`.

- **Critical**: Security vulnerabilities, data loss, production outage. Must fix. Include fix recommendation.
- **Important**: Bugs, logic errors, missing error handling. Should fix.
- **Suggestion**: Improvements, better patterns. Consider.
- **Nit**: Style, naming. Optional.

Format: Start review summary with counts — "2 Critical, 1 Important, 3 Suggestions, 2 Nits"
