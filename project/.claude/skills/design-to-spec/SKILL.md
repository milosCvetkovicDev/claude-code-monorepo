---
name: design-to-spec
description: "Convert UI/UX designs (mockups, wireframes, Figma files) into a detailed technical specification with component breakdown and implementation plan. Use when the user has an approved design ready for spec. Do not use for creating designs (use design-ui) or implementing from a spec (use implement-phase)."
model: sonnet
disable-model-invocation: true
args: <design-document-path>
---

# Design to Technical Specification

## Input

- **design-document-path**: Path to the approved system design document

## Prerequisites

Before converting:

1. Verify the design has been reviewed (`/review-design`)
2. Check the review verdict was APPROVED or CONDITIONAL (with conditions met)
3. Ensure all open questions in the design have answers

## Workflow

### Step 1: Read the Design Document

Extract from the design:

1. **Components to build**: What needs to be created
2. **Data models**: Entities and relationships
3. **API contracts**: Endpoints and schemas
4. **Integrations**: External system connections
5. **Security requirements**: Auth, encryption, audit

### Step 2: Identify Implementation Tasks

For each component in the design:

1. **Backend tasks**:

   - Entity/model creation
   - Repository implementation
   - Service layer implementation
   - Controller/route creation
   - Job handlers (if async)

2. **Frontend tasks**:

   - Component creation
   - Page implementation
   - API hooks
   - State management

3. **Infrastructure tasks**:

   - Database migrations
   - Configuration changes
   - CI/CD updates

4. **Testing tasks**:
   - Unit tests
   - Integration tests
   - E2E tests

### Step 3: Organize into Phases

Group tasks into logical phases:

```
Phase 1: Foundation
- Database schema/migrations
- Core entities
- Basic CRUD operations

Phase 2: Business Logic
- Service layer
- Validation rules
- Business rules

Phase 3: Integration
- External API connections
- Background jobs
- Event handlers

Phase 4: UI Implementation
- Components
- Pages
- User workflows

Phase 5: Testing & Polish
- Unit tests
- Integration tests
- E2E tests
- Documentation
```

### Step 4: Create Technical Specification

Save to: `docs/plans/YYYY-MM-DD-<feature>-technical-spec.md`

Use the template from `references/technical-spec-template.md`. Populate all sections from the design analysis in Steps 1-3.

### Step 5: Add Detailed Tool/Endpoint Specs

For each tool or endpoint, add detailed specifications using the template from `references/endpoint-spec-template.md`.

### Step 6: Run Technical Spec Reviews

Run the `/technical-spec` review workflow:

1. `review-enterprise-architect`
2. `review-azure-architect` (if Azure involved)
3. `review-devops-architect`
4. `review-tech-lead`

## Output

```markdown
## Technical Specification Created

### Document

`docs/plans/YYYY-MM-DD-<feature>-technical-spec.md`

### Source Design

`docs/architecture/<domain>/<feature>.md`

### Phases

| Phase | Title | Tasks | Est. Days |
|-------|-------|-------|-----------|
| 1 | Foundation | 4 | 2 |
| 2 | Business Logic | 6 | 3 |
| 3 | Integration | 3 | 2 |
| 4 | UI | 5 | 2 |
| 5 | Testing | 4 | 2 |

### Total Estimated: 11 days

### Review Status

Running technical-spec reviews...

| Reviewer | Verdict | Critical | High | Medium |
|----------|---------|----------|------|--------|
| Enterprise | ... | ... | ... | ... |
| Azure | ... | ... | ... | ... |
| DevOps | ... | ... | ... | ... |
| Tech Lead | ... | ... | ... | ... |

### Next Steps

1. Address review findings
2. Get team approval
3. Run `/implement-phase <spec> --phase 1` to start
````

## Conventions

- One task = one logical unit of work
- Each phase has clear validation criteria
- Include all file paths that will be created/modified
- Reference the source design document
- Phases should be independently deployable when possible
