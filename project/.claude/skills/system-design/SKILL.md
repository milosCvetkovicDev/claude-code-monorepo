---
name: system-design
description: "Create a system design document covering architecture, data models, API contracts, and deployment topology. Use when the user needs to design a new system or major feature before implementation. Do not use for smaller feature specs (use technical-spec) or reviewing existing designs (use review-design)."
model: sonnet
disable-model-invocation: true
args: '<feature-or-system-description>'
---

# Create System Design

## Input

- **description**: What system or feature to design (e.g., "Invoice finalization with ERP integration")

## Workflow

### Step 1: Gather Requirements

If requirements are unclear, use the `interview-user` agent to clarify:

1. What problem is being solved?
2. Who are the users/actors?
3. What are the key workflows?
4. What are the constraints (performance, security, cost)?
5. What existing systems does it integrate with?

### Step 2: Analyze Existing Architecture

1. Read relevant CLAUDE.md files
2. Identify affected components
3. Find similar patterns in the codebase
4. Note existing integrations and data flows

### Step 3: Create System Design Document

Save to: `docs/architecture/<domain>/<feature-name>.md`

Use the template from `references/system-design-template.md`. Populate all 14 sections from the requirements gathered in Steps 1-2. Use C4 model notation for context and container diagrams.

### Step 4: Render Diagrams

Use the Mermaid Chart MCP tool (`validate_and_render_mermaid_diagram`) to validate and render all Mermaid diagrams in the document.

### Step 5: Suggest Reviews

Run `/review-design docs/architecture/<domain>/<feature-name>.md` to validate the design before implementation.

## Output

```markdown
## System Design Created

### Document

`docs/architecture/<domain>/<feature-name>.md`

### Sections Completed

- ✅ Executive Summary
- ✅ Context Diagram (C4 Level 1)
- ✅ Container Diagram (C4 Level 2)
- ✅ Component Design
- ✅ Data Model
- ✅ Sequence Diagrams
- ✅ API Contract
- ✅ Non-Functional Requirements
- ✅ Security Considerations
- ✅ Trade-offs
- ✅ Implementation Phases
- ✅ Risks
- ✅ Open Questions

### Diagrams Rendered

- Context Diagram
- Container Diagram
- Data Model ERD
- Sequence Diagram(s)

### Next Steps

1. Run `/review-design docs/architecture/<domain>/<feature-name>.md`
2. Address review findings
3. Run `/design-to-spec` to create technical specification
````

## Conventions

- Use C4 model for architecture diagrams
- Use Mermaid syntax for all diagrams
- Include both happy path and error handling in sequences
- Document security considerations explicitly
- List all open questions that need resolution
- Reference existing patterns from CLAUDE.md
