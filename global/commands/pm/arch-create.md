---
allowed-tools: Bash, Read, Write, LS
---

# Architecture Create

Facilitate collaborative architecture decisions for an epic, producing an architecture document and ADRs.

## Usage
```
/pm:arch-create <feature_name>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time
- `.claude/references/architecture/architecture-operations.md` - For architecture conventions and formats

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress. Just do them and move on.

1. **Verify feature_name was provided:**
   - If not: "❌ Feature name required. Run: /pm:arch-create <feature_name>"

2. **Verify PRD exists:**
   - Check if `.claude/prds/$ARGUMENTS.md` exists
   - If not: "❌ PRD not found. Run: /pm:prd-new $ARGUMENTS first"

3. **Verify epic exists:**
   - Check if `.claude/epics/$ARGUMENTS/epic.md` exists
   - If not: "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS first"

4. **Check for existing architecture:**
   - If `.claude/epics/$ARGUMENTS/architecture.md` exists:
   - Ask: "⚠️ Architecture document already exists. Overwrite? (yes/no)"
   - Only proceed with explicit yes

5. **Check for master architecture (multi-milestone):**
   - Search for `.claude/milestones/*/master-architecture.md`
   - If found, note its path — this epic will inherit shared decisions

6. **Check ADR directory:**
   - Ensure `docs/adr/` exists: `mkdir -p docs/adr`

## Instructions

You are a senior architect facilitating collaborative technical decisions for: **$ARGUMENTS**

### 1. Load Context

Read these documents:
- PRD from `.claude/prds/$ARGUMENTS.md` — extract all FRs, NFRs, constraints
- Epic from `.claude/epics/$ARGUMENTS/epic.md` — extract technical approach, dependencies
- If master architecture exists: load shared decisions (these are inherited, not re-debated)
- If existing architecture docs exist at `docs/architecture/`: scan for relevant context
- Read project CLAUDE.md for existing tech stack conventions

### 2. Determine Next ADR Number

```bash
next_adr=$(ls docs/adr/[0-9]*.md 2>/dev/null | sed 's|.*/||;s|-.*||' | sort -n | tail -1 | awk '{printf "%04d", $1+1}')
[ -z "$next_adr" ] && next_adr="0001"
echo "Next ADR number: $next_adr"
```

### 3. Facilitate Decision Categories (COLLABORATIVE)

For each of the 5 categories below:
1. Present the relevant context from PRD and epic
2. If master architecture has a decision: show as "**Inherited from master**: [decision]" and ask if override needed
3. If no master decision: list 2-3 options with trade-offs
4. Ask the user to choose
5. For complex decisions, suggest spawning a Acme project agent (if available at project `.claude/agents/`):
   - Data Architecture → ddd-expert, database-migration-expert
   - API → api-designer
   - Frontend → frontend-specialist
   - Infrastructure → terraform-expert

**Categories:**

#### Category 1: Data Architecture
Database, ORM, schema design, migrations, validation, caching, DDD modeling.
Skip if no data changes in this epic.

#### Category 2: Auth & Security
Authentication, authorization, token strategy, API security, encryption.
Skip if no auth changes.

#### Category 3: API & Communication
REST/GraphQL, documentation, error format, rate limiting, inter-service.
Skip if no API changes.

#### Category 4: Frontend Architecture
State management, components, routing, performance, forms.
Skip if backend-only epic.

#### Category 5: Infrastructure & Deployment
Hosting, CI/CD, environments, monitoring, scaling, IaC.
Skip if no infrastructure changes.

### 4. Generate Implementation Patterns

Based on decisions made:
- **Naming Conventions**: DB columns, API endpoints, TypeScript, files, tests
- **Structure Conventions**: module organization, layer boundaries, directories
- **Format Conventions**: API response shapes, error format, dates, numbers
- **Anti-Patterns (NEVER DO)**: 3-5 specific things agents must NOT do

### 5. Generate Project Structure

- Map each FR/task to specific file locations
- Create directory tree showing new files
- Identify existing files to be modified

### 6. Create Architecture Document

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Create `.claude/epics/$ARGUMENTS/architecture.md` with frontmatter (`name`, `status: active`, `created`, `updated`, `prd`, `epic`, `master` if applicable) and sections: Context Analysis, Decision Matrix, Implementation Patterns, Project Structure, Cross-Cutting Concerns.

### 7. Create ADRs

For each significant decision (where alternatives were seriously considered):
- Create `docs/adr/{next_number}-{kebab-case-title}.md`
- Follow existing format from `docs/adr/README.md`
- Include: Context, Decision, Consequences, Alternatives Considered, References
- If superseding: add `**Supersedes:** ADR-NNNN` and update old ADR
- Increment number for each subsequent ADR
- Update `docs/adr/README.md` index table

### 8. Update Epic

Update `.claude/epics/$ARGUMENTS/epic.md`:
- Add to frontmatter: `architecture: .claude/epics/$ARGUMENTS/architecture.md`
- Add section `## Architecture` referencing the document and key decisions

### 9. Update Master Architecture (if multi-milestone)

If this is the first `arch-create` in a program and master is a stub:
- Populate master with shared decisions
- Mark project-wide vs epic-specific decisions

If master already has content:
- Ask: "Should any new decisions apply to all future epics?"

## Post-Creation

```
✅ Architecture created for: $ARGUMENTS

📄 Architecture: .claude/epics/$ARGUMENTS/architecture.md
📋 ADRs created: {count} (docs/adr/{numbers})

Key decisions:
  Data: {decision}
  API: {decision}
  [etc.]

Next: /pm:epic-decompose $ARGUMENTS
```

## Error Recovery

- If PRD lacks clear requirements: list what's missing
- If user can't decide: mark as "TBD" and continue — revisit later
- If ADR creation fails: architecture document is still valid
- Never leave the epic in an inconsistent state

## Important Notes

- This command is INTERACTIVE — asks the user for decisions, does not auto-generate
- Skip categories that are N/A for the epic
- Reference existing architecture docs at `docs/architecture/` rather than duplicating
- Follow `/rules/datetime.md` for timestamps
- Follow `/references/architecture/architecture-operations.md` for document format
