---
name: add-docs
description: "Create or update project documentation: ADRs, runbooks, architecture docs, and API references. Use when the user needs to document decisions, create operational guides, or update architecture diagrams. Do not use for inline code comments or README updates in application code."
model: sonnet
---

# Documentation Workflow

You are creating or updating project documentation.

## Workflow Steps

### Step 1: Identify Documentation Type

| Type | Location | When to Use |
|------|----------|-------------|
| ADR | `docs/adr/` | Recording architectural decisions |
| Runbook | `docs/runbooks/` | Operational procedures |
| Architecture | `docs/architecture/` | System design documentation |
| API Docs | `docs/api/` | API reference documentation |
| Requirements | `docs/requirements/` | Feature requirements |
| Plans | `docs/plans/` | Implementation plans |
| Incident | `docs/runbooks/incidents/` | Post-incident reports |

### Step 2: Use Documentation Writer Agent
Use the **documentation-writer agent** to:
- Follow project templates
- Use correct terminology
- Maintain consistency with existing docs

### Step 3: Templates

#### Architecture Decision Record (ADR)
Location: `docs/adr/NNNN-title.md`
```markdown
# ADR-NNNN: {Title}

**Status**: Proposed | Accepted | Deprecated | Superseded
**Date**: YYYY-MM-DD
**Deciders**: {Names}

## Context
{What is the issue we're seeing that motivates this decision?}

## Decision
{What is the change we're proposing?}

## Consequences

### Positive
- {Benefit}

### Negative
- {Drawback}

### Neutral
- {Consequence}

## Alternatives Considered
### Option 1: {Name}
- **Pros**: ...
- **Cons**: ...
- **Why rejected**: ...
```

#### Runbook
Location: `docs/runbooks/{category}/{name}.md`
```markdown
# Runbook: {Title}

**Last Updated**: YYYY-MM-DD
**Owner**: {Team/Person}
**Severity**: P1/P2/P3/P4

## Overview
{When to use this runbook}

## Prerequisites
- [ ] Access to {system}
- [ ] {Other requirements}

## Procedure

### Step 1: {Title}
```bash
command here
```
**Expected output**: {What you should see}

### Step 2: {Title}
{Instructions}

## Verification
How to confirm the procedure worked.

## Rollback
If something goes wrong:
1. {Step}

## Troubleshooting
| Symptom | Cause | Solution |
|---------|-------|----------|
| {symptom} | {cause} | {solution} |
```

#### Implementation Plan
Location: `docs/plans/YYYY-MM-DD-{name}.md`
```markdown
# Plan: {Feature Name}

**Date**: YYYY-MM-DD
**Author**: {Name}
**Status**: Draft | In Progress | Complete

## Summary
{What we're building and why}

## Requirements
- [ ] {Requirement}

## Technical Approach
{How we'll implement this}

## Files to Change
| File | Change |
|------|--------|
| `path/to/file.ts` | {Description} |

## Testing Strategy
- Unit tests: {what to test}
- Integration tests: {what to test}

## Risks
| Risk | Mitigation |
|------|------------|
| {risk} | {mitigation} |
```

### Step 4: Writing Guidelines

**DO:**
- Use simple, direct language
- Include code examples
- Add diagrams where helpful
- Keep sections focused
- Update "Last Updated" date
- Link to related docs

**DON'T:**
- Use jargon without explanation
- Write walls of text
- Assume reader knows context
- Leave TODOs in published docs
- Duplicate information (link instead)

### Step 5: Project Terminology

| Term | Correct Usage |
|------|---------------|
| TradingCompany | Multi-tenant entity (not "company") |
| Big.js | Decimal library (not "BigNumber") |
| MSAL | Authentication (not "Azure AD") |
| pg-boss | Background jobs (not "queue") |
| Deployment slot | Azure staging (not "blue-green") |

### Step 6: Review
Use **review-tech-lead agent** to verify:
- Documentation is accurate
- Code examples follow project conventions
- Terminology is correct
- Links work

### Step 7: Location Verification
Ensure doc is in correct location:
```bash
# List existing docs in category
ls docs/{category}/

# Check naming convention
# ADRs: NNNN-title.md
# Plans: YYYY-MM-DD-title.md
# Runbooks: descriptive-name.md
```

## Documentation Checklist
- [ ] Correct template used
- [ ] Placed in correct directory
- [ ] Follows naming convention
- [ ] All code examples tested
- [ ] Links verified
- [ ] Terminology correct
- [ ] Date updated

## Output
Provide:
- Document created/updated
- File path
- Summary of content
- Related docs that may need updates
