# CLAUDE.md - Documentation

Project documentation organized by purpose and domain.

## Structure

```
docs/
├── architecture/          # Technical design & architecture
│   ├── backend/          # Backend service architecture (Express, TypeORM)
│   └── integrations/     # External system integrations
│       └── erp/         # the ERP accounting integration
│
├── runbooks/             # Operational procedures
│   └── migration/        # Migration execution steps
│
├── adr/                  # Architecture Decision Records
│
├── business/             # Business requirements & scoping
│
├── migration/            # Migration planning documents
│
├── deployment/           # Historical deployment guides
│
└── _archive/             # Deprecated documentation
```

## Quick Links

| Document | Path |
| ---------------------------- | ----------------------------------------------------------- |
| Backend Architecture | `architecture/backend/01-overview.md`                       |
| ERP Integration | `architecture/integrations/erp/`                           |
| Migration Runbook | `runbooks/migration/phase3-7pm-runbook.md`                  |
| Migration Plan | `migration/production-to-sponsorship-sub-migration-plan.md` |
| **Claude Code Skills Guide** | `runbooks/claude-code/skills-guide.md`                      |

## Documentation Guidelines

### Where to Put New Docs

| Type | Location | Example |
| ---------------------- | ------------------------ | ----------------------------------- |
| Architecture/Design | `architecture/<domain>/` | New service design |
| Operational Procedures | `runbooks/<category>/`   | Deployment steps, incident response |
| Architecture Decisions | `adr/NNNN-title.md`      | Why we chose PostgreSQL             |
| Business Requirements | `business/`              | Feature specifications |
| Migration Plans | `migration/`             | Database migration strategy |

### Naming Conventions

- **Files**: kebab-case (`my-document.md`)
- **Numbered series**: `01-overview.md`, `02-details.md`
- **ADRs**: `0001-decision-title.md`
- **Runbooks**: Include date if time-sensitive (`phase3-7pm-runbook.md`)

### Active vs Archived

- **Active docs** live in their domain folders
- **Deprecated docs** move to `_archive/` with a note explaining why
- ERP integration docs are ACTIVE (in `architecture/integrations/erp/`), not archived

## Key Documents

### Backend Architecture

10-part series covering:

1. Overview
2. High-Level Architecture
3. Module Structure
4. API Architecture
5. Database Architecture
6. Authentication
7. Integrations
8. Background Jobs
9. Testing Strategy
10. Migration Plan

### ERP Integration

Documentation for the ERP accounting system integration:

- Business requirements
- E2E analysis
- Error handling
- Sync deep-dive

### Claude Code Configuration

Claude Code is configured with hooks and skills for this workspace:

**Hooks** (automatic actions):

- Session start: Git sync, Docker check, GitHub context load
- File edits: Auto-format with Prettier
- Session end: Resource cleanup
- See `.claude/hooks/README.md` for details

**Skills** (workflow automation):

- Development: `/bug-fix`, `/new-feature`, `/api-change`, `/frontend-change`
- Database: `/db-migration`
- Code quality: `/refactor`, `/full-review`, `/security-audit`
- Operations: `/hotfix`, `/incident`, `/performance`
- Utilities: `/cleanup`, `/env-status`, `/test-affected`, `/github-refresh`
- See `runbooks/claude-code/skills-guide.md` for complete guide
