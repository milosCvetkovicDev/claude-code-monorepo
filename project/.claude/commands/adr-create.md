# ADR Create

Scaffold a new Architecture Decision Record.

## Usage

```
/adr-create <title>
```

## Instructions

### 1. Determine Next ADR Number

```bash
# Find the highest existing ADR number
LAST=$(ls docs/architecture/decisions/ADR-*.md 2>/dev/null | sort -t- -k2 -n | tail -1 | grep -oE 'ADR-[0-9]+' | sed 's/ADR-//' || echo "000")
NEXT=$(printf "%03d" $((10#$LAST + 1)))
```

If `docs/architecture/decisions/` doesn't exist, create it and start with ADR-001.

### 2. Create ADR File

Load template from `.claude/references/adr-template.md`.

Create file at: `docs/architecture/decisions/ADR-${NEXT}-{kebab-case-title}.md`

Fill in:

- **Title**: ADR-${NEXT}: {Title from argument}
- **Status**: Proposed
- **Date**: Current date (YYYY-MM-DD)
- **Context**: Ask user to describe the context, or leave placeholder
- **Decision**: Leave placeholder for user to fill
- **Alternatives Considered**: Add 2 empty alternative sections
- **Consequences**: Add empty positive/negative/risks sections

### 3. Output

```
Created: docs/architecture/decisions/ADR-{NEXT}-{title}.md

Sections to fill:
  - Context: What is the issue motivating this decision?
  - Decision: What did you decide?
  - Alternatives: What else was considered?
  - Consequences: What are the trade-offs?

When complete, update Status from "Proposed" to "Accepted".
```
