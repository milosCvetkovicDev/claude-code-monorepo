---
allowed-tools: Bash, Read, Write, LS
---

# PRD New

Launch brainstorming for new product requirement document.

## Usage
```
/pm:prd-new <feature_name>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress ("I'm not going to ..."). Just do them and move on.

### Input Validation
1. **Validate feature name format:**
   - Must contain only lowercase letters, numbers, and hyphens
   - Must start with a letter
   - No spaces or special characters allowed
   - If invalid, tell user: "❌ Feature name must be kebab-case (lowercase letters, numbers, hyphens only). Examples: user-auth, payment-v2, notification-system"

2. **Check for existing PRD:**
   - Check if `.claude/prds/$ARGUMENTS.md` already exists
   - If it exists, ask user: "⚠️ PRD '$ARGUMENTS' already exists. Do you want to overwrite it? (yes/no)"
   - Only proceed with explicit 'yes' confirmation
   - If user says no, suggest: "Use a different name or run: /pm:prd-parse $ARGUMENTS to create an epic from the existing PRD"

3. **Verify directory structure:**
   - Check if `.claude/prds/` directory exists
   - If not, create it first
   - If unable to create, tell user: "❌ Cannot create PRD directory. Please manually create: .claude/prds/"

## Instructions

You are a product manager creating a comprehensive Product Requirements Document (PRD) for: **$ARGUMENTS**

Follow this structured approach:

### 1. Discovery & Context
- Ask clarifying questions about the feature/product "$ARGUMENTS"
- Understand the problem being solved
- Identify target users and use cases
- Gather constraints and requirements

### 2. PRD Structure
Create a comprehensive PRD with these sections:

#### Executive Summary
- Brief overview and value proposition

#### Problem Statement
- What problem are we solving?
- Why is this important now?

#### User Stories
- Primary user personas
- Detailed user journeys
- Pain points being addressed

#### Acceptance Criteria (Gherkin)
For each user story, write acceptance criteria using Gherkin syntax:
```gherkin
Feature: {feature_name}
  As a {persona}
  I want {capability}
  So that {benefit}

  Scenario: {scenario_name}
    Given {precondition}
    When {action}
    Then {expected_result}
    And {additional_assertion}

  Scenario: {edge_case_name}
    Given {edge_case_precondition}
    When {edge_case_action}
    Then {edge_case_result}
```
- Write at least one Scenario per user story
- Include happy path AND edge case scenarios
- Use concrete examples, not abstract descriptions
- These scenarios will become automated acceptance tests

#### Requirements
**Functional Requirements**
- Core features and capabilities
- User interactions and flows

**Non-Functional Requirements**
- Performance expectations
- Security considerations
- Scalability needs

#### Testing Requirements
- Required test types: unit, integration, E2E, acceptance
- Coverage expectations (which paths must be tested)
- Test data requirements (what seed data is needed)
- Performance benchmarks with pass/fail thresholds (if applicable)

#### Success Criteria
- Measurable outcomes
- Key metrics and KPIs

#### Constraints & Assumptions
- Technical limitations
- Timeline constraints
- Resource limitations

#### Out of Scope
- What we're explicitly NOT building

#### Dependencies
- External dependencies
- Internal team dependencies

#### Production Verification
Define how to verify this feature works correctly in production after deployment:
- Health check endpoints to verify
- Business logic smoke tests (specific API calls with expected responses)
- UI flows to verify manually (if applicable)
- Monitoring duration and what to watch for (Application Insights, error rates)
- Rollback criteria (what failure looks like, when to roll back)
- Stakeholder sign-off requirements (who needs to verify, if anyone)

### 3. File Format with Frontmatter
Save the completed PRD to: `.claude/prds/$ARGUMENTS.md` with this exact structure:

```markdown
---
name: $ARGUMENTS
description: [Brief one-line description of the PRD]
status: backlog
created: [Current ISO date/time]
---

# PRD: $ARGUMENTS

## Executive Summary
[Content...]

## Problem Statement
[Content...]

[Continue with all sections...]
```

### 4. Frontmatter Guidelines
- **name**: Use the exact feature name (same as $ARGUMENTS)
- **description**: Write a concise one-line summary of what this PRD covers
- **status**: Always start with "backlog" for new PRDs
- **created**: Get REAL current datetime by running: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
  - Never use placeholder text
  - Must be actual system time in ISO 8601 format

### 5. Quality Checks

Before saving the PRD, verify:
- [ ] All sections are complete (no placeholder text)
- [ ] User stories include acceptance criteria
- [ ] Gherkin scenarios cover happy paths AND edge cases
- [ ] At least one Gherkin scenario per user story
- [ ] Testing requirements specify required test types
- [ ] Success criteria are measurable
- [ ] Dependencies are clearly identified
- [ ] Out of scope items are explicitly listed
- [ ] Production verification steps are concrete and actionable

### 6. Post-Creation

After successfully creating the PRD:
1. Confirm: "✅ PRD created: .claude/prds/$ARGUMENTS.md"
2. Show brief summary of what was captured
3. Suggest next step: "Ready to create implementation epic? Run: /pm:prd-parse $ARGUMENTS"

## Error Recovery

If any step fails:
- Clearly explain what went wrong
- Provide specific steps to fix the issue
- Never leave partial or corrupted files

Conduct a thorough brainstorming session before writing the PRD. Ask questions, explore edge cases, and ensure comprehensive coverage of the feature requirements for "$ARGUMENTS".

## Agent Skill Integration

When executing this command, invoke `agent-skills:idea-refine` for the brainstorming phase and `agent-skills:spec-driven-development` when structuring requirements and acceptance criteria.
