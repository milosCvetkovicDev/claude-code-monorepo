# ADR Template

Use this template when creating Architecture Decision Records. Save ADRs to `docs/architecture/decisions/ADR-NNN-title.md`.

## Template

```markdown
# ADR-NNN: [Decision Title]

## Status

[Proposed | Accepted | Deprecated | Superseded by ADR-NNN]

## Date

[YYYY-MM-DD]

## Context

[What is the issue that we're seeing that motivates this decision or change?
Include technical context, business constraints, and any relevant history.
What forces are at play?]

## Decision

[What is the change that we're proposing and/or doing?
State the decision clearly and unambiguously.]

## Alternatives Considered

### Alternative 1: [Name]

- **Pros:** [advantages]
- **Cons:** [disadvantages]
- **Why rejected:** [specific reason]

### Alternative 2: [Name]

- **Pros:** [advantages]
- **Cons:** [disadvantages]
- **Why rejected:** [specific reason]

## Consequences

### Positive

- [What becomes easier or more reliable?]

### Negative

- [What becomes harder or more complex?]
- [What technical debt does this introduce?]

### Risks

- [What could go wrong?]
- [What are the mitigation strategies?]
```

## Numbering Convention

- Sequential: ADR-001, ADR-002, etc.
- Check existing ADRs: `ls docs/architecture/decisions/`
- Never reuse a number, even if the ADR is deprecated

## When to Write an ADR

- New technology or framework adoption
- Significant architectural change
- Database schema design decisions
- API contract changes
- Infrastructure changes (cloud provider, deployment strategy)
- New dependency > 100KB bundle impact
- Deviation from established patterns

## Tips

- **Keep it short** — 1-2 pages maximum
- **Focus on the why** — The code shows the what; the ADR explains why
- **Record the alternatives** — Future engineers need to know what else was considered
- **Update, don't delete** — If a decision changes, mark old ADR as "Superseded" and create new one
