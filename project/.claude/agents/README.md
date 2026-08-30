# Claude Code Custom Agents

This directory contains custom subagents for the Acme project.

## Available Agents

### Requirements & Planning

| Agent | Description |
| ------------------- | ---------------------------------------------------------------------------------------------------- |
| `interview-user`    | Requirements gathering interview agent - conducts structured interviews and creates requirement docs |
| `technical-spec`    | Converts requirements into technical specifications and implementation plans |
| `user-story-writer` | Formats rough ideas into proper Agile user stories with acceptance criteria |

### Domain & Architecture Experts

| Agent | Expertise |
| ----------------------------- | -------------------------------------------------------------------------------- |
| `ddd-expert`                  | Domain-Driven Design, bounded contexts, aggregates, value objects, domain events |
| `review-enterprise-architect` | Clean Architecture, SOLID principles, system design, API design |
| `review-devops-architect`     | CI/CD pipelines, IaC, deployment strategies, security, observability |
| `review-azure-architect`      | Azure Well-Architected Framework, Azure services, cost optimization |
| `review-tech-lead`            | Code quality, developer experience, technical debt, documentation |
| `review-test-architect`       | Test strategy, test automation, coverage, testing patterns |
| `e2e-testing-expert`          | Playwright E2E testing, flaky tests, Page Objects, mocking strategies, CI/CD     |

### UX/UI Experts

| Agent | Expertise |
| ----------- | ---------------------------------------------------------------------------------- |
| `ux-expert` | User flows, information architecture, usability, accessibility, business app UX    |
| `ui-expert` | Visual design, MUI components, design systems, responsive layouts, business app UI |

## Usage

### Invoke a Single Reviewer

```
Use the review-enterprise-architect agent to review the domain model
Use the review-azure-architect agent to review our Terraform infrastructure
```

### Run Multiple Reviews

```
Have review-devops-architect and review-test-architect review our CI pipeline
```

### Requirements Workflow

```
1. Use interview-user to gather requirements for user authentication
2. Use technical-spec to create implementation plan from docs/requirements/REQ-auth.md
```

## Output Locations

| Agent Type | Output Location |
| --------------- | ---------------------------------------------------- |
| Requirements | `docs/requirements/REQ-{feature-name}.md`            |
| User Stories | `docs/requirements/stories/`                         |
| Technical Specs | `docs/architecture/{feature-name}/technical-spec.md` |
| Reviews | Displayed in conversation (not saved to file)        |

## Reviewer Scorecards

Each reviewer produces a scorecard rating areas 1-5:

**DDD Expert**: Bounded Contexts, Aggregates, Value Objects, Ubiquitous Language, Domain Events

**Enterprise Architect**: Clean Architecture, SOLID, API Design, System Integration, Maintainability

**DevOps Architect**: CI/CD, IaC, Deployment, Security, Observability, Operational Readiness

**Azure Architect**: Reliability, Security, Cost, Operational Excellence, Performance (Well-Architected pillars)

**Tech Lead**: Code Quality, Developer Experience, Documentation, Testing, Maintainability, Onboarding

**Test Architect**: Test Strategy, Unit Tests, Integration Tests, E2E Tests, Test Quality, CI Integration

**E2E Testing Expert**: Page Objects, Flaky Test Resolution, Auth Flows, Mocking Strategies, CI Optimization, Test Isolation

**UX Expert**: Information Architecture, User Flows, Form Design, Error Handling, Accessibility, Cognitive Load

**UI Expert**: Theme Compliance, Component Quality, Responsive Design, Visual Hierarchy, Loading States, Consistency

## Adding New Agents

Create a markdown file with YAML frontmatter:

```markdown
---
name: agent-name
description: When to use this agent (Claude reads this to decide delegation)
tools: Read, Glob, Grep, Bash
model: sonnet
---

Your system prompt here...
```

### Available Tools

- **Read-only**: `Read`, `Glob`, `Grep`, `WebFetch`, `WebSearch`
- **Write**: `Write`, `Edit`
- **Execution**: `Bash`
- **Interactive**: `AskUserQuestion`

### Model Options

- `sonnet` - Balanced (default)
- `opus` - Most capable
- `haiku` - Fast and cheap
- `inherit` - Use parent's model
