---
name: review-design
description: "Review a system design document for architectural soundness, scalability, security, and alignment with Acme patterns. Use when the user has a design doc and wants feedback. Do not use for UI/UX design review (use design-review) or code review (use code-review)."
model: sonnet
disable-model-invocation: true
args: <design-document-path>
---

# Review System Design

You are reviewing a system design document for quality and completeness.

## Input

- **design-document-path**: Path to the system design document (e.g., `docs/architecture/invoicing/finalization.md`)

## Workflow

### Step 1: Read the Design Document

Read the design document and extract:

1. Feature/system being designed
2. Key components and interactions
3. Data models
4. API contracts
5. Security considerations

### Step 2: Run Completeness Checklist

Check for required sections:

| Section | Required | Present | Notes |
| --------------------------- | -------- | ------- | ---------------------------- |
| Executive Summary | ✅       | ?       | Problem + solution |
| Context Diagram | ✅       | ?       | C4 Level 1                   |
| Container Diagram | ✅       | ?       | C4 Level 2                   |
| Component Design | ✅       | ?       | Responsibilities, interfaces |
| Data Model | ✅       | ?       | ERD with relationships |
| Sequence Diagrams | ✅       | ?       | Critical flows |
| API Contract | ✅       | ?       | OpenAPI format |
| Non-Functional Requirements | ✅       | ?       | Performance, availability |
| Security Considerations | ✅       | ?       | Auth, encryption, audit |
| Trade-offs | ✅       | ?       | Decisions with rationale |
| Implementation Phases | ⚠️       | ?       | Optional but recommended |
| Risks | ⚠️       | ?       | Optional but recommended |
| Open Questions | ✅       | ?       | Must be listed |

### Step 3: Validate Correctness

1. **Diagram Validation**

   - Check Mermaid syntax is valid
   - Verify relationships are bidirectional where expected
   - Confirm data flows are complete

2. **Consistency Check**

   - API contracts match component interfaces
   - Data models align with entity descriptions
   - Security requirements are addressed in design

3. **Clean Architecture Compliance**
   - Dependencies flow inward
   - Domain layer has no external dependencies
   - Infrastructure concerns are separated

### Step 4: Check Alignment

Compare against project conventions:

1. **Technology Choices**

   - Uses approved technologies (PostgreSQL, TypeORM, React, MUI)
   - Follows existing patterns in codebase
   - Consistent with CLAUDE.md guidelines

2. **Multi-Tenancy**

   - tradingCompanyId is considered
   - Data isolation is enforced
   - No cross-tenant data leaks possible

3. **Integration Patterns**
   - Matches existing API patterns
   - Uses pg-boss for async jobs
   - Follows ERP integration patterns (if applicable)

### Step 5: Assess Feasibility

1. **Implementation Effort**

   - Are phases realistic?
   - Are dependencies identified?
   - Is rollback strategy defined?

2. **Risk Assessment**
   - Are risks documented?
   - Are mitigations reasonable?
   - Are there missing risks?

### Step 6: Generate Review Report

## Output Format

```markdown
## System Design Review

**Document**: <path>
**Reviewer**: Claude Code (review-design skill)
**Date**: YYYY-MM-DD

### Verdict: APPROVED | CONDITIONAL | BLOCKED

### Scores

| Category | Score | Notes |
| ------------ | ----- | ------- |
| Completeness | X/5   | <notes> |
| Correctness | X/5   | <notes> |
| Alignment | X/5   | <notes> |
| Feasibility | X/5   | <notes> |

### Critical Issues (Must Fix)

1. **<Issue Title>**
   - Location: <section/line>
   - Problem: <description>
   - Fix: <required action>

### High Priority Issues (Should Fix)

1. **<Issue Title>**
   - Location: <section/line>
   - Problem: <description>
   - Recommendation: <suggested fix>

### Medium Priority Issues (Consider)

1. **<Issue Title>**
   - Recommendation: <suggestion>

### Positive Observations

1. <What's done well>
2. <Strong points>

### Recommendations

1. <Improvement suggestion>
2. <Enhancement idea>

### Open Questions to Address

- [ ] <Question from design that needs answer>
- [ ] <Question raised by review>

### Approval Conditions

If CONDITIONAL, list what must be done:

- [ ] <Required change 1>
- [ ] <Required change 2>

### Diagrams Validated

| Diagram | Status | Issues |
| ----------------- | ------ | --------------- |
| Context Diagram | ✅/❌  | <issues if any> |
| Container Diagram | ✅/❌  | <issues if any> |
| Data Model ERD    | ✅/❌  | <issues if any> |
| Sequence Diagrams | ✅/❌  | <issues if any> |
```

## Verdict Criteria

**APPROVED**: All required sections present, no critical issues, aligns with conventions.

**CONDITIONAL**: Minor issues that must be fixed before implementation, but design is sound.

**BLOCKED**: Critical issues that require significant redesign, or missing essential sections.

## Next Steps After Review

1. If APPROVED: Run `/design-to-spec` to create technical specification
2. If CONDITIONAL: Address required changes, then re-run `/review-design`
3. If BLOCKED: Revise design significantly, may need `/system-design` again
