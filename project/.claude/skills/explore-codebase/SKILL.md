---
name: explore-codebase
description: 'Navigate and understand the Acme monorepo structure, find files, trace code paths, and map dependencies. Use when the user needs to understand how a feature works or explore unfamiliar code. Do not use for making code changes or implementing features.'
model: sonnet
disable-model-invocation: true
---

# Codebase Exploration Workflow

You are helping understand the Acme codebase structure and patterns.

## Quick Overview

```
acme/                          # Nx monorepo root
├── apps/
│   ├── legacy-api/          # Express.js API
│   ├── legacy-web/          # React SPA
│   └── legacy-web-e2e/      # Playwright E2E tests
├── libs/
│   ├── shared/domain-types/    # Shared value objects, interfaces
│   └── data-seeding/           # Test data generation
├── infra/                      # Terraform IaC
│   ├── environments/           # Per-environment configs
│   └── modules/                # Reusable Terraform modules
├── docs/                       # Documentation
│   ├── architecture/           # Design docs
│   ├── runbooks/               # Operational procedures
│   └── adr/                    # Architecture decisions
└── .claude/                    # Claude Code configuration
    ├── agents/                 # Specialized agents
    └── skills/                 # Workflow orchestrations
```

## Workflow Steps

### Step 1: Workspace Overview

Use the **nx-expert agent** to understand the workspace structure:

- Project graph and dependencies
- Module boundaries and tags
- Available targets and executors
- Nx caching configuration

```bash
# See project graph
nx graph

# List all projects
nx show projects

# See project dependencies
nx graph --focus=legacy-api
```

### Backend Exploration

```bash
# Entry point
cat apps/legacy-api/src/main.ts

# Routes (API endpoints)
ls apps/legacy-api/src/routes/

# Services (business logic)
ls apps/legacy-api/src/services/

# Entities (database models)
ls apps/legacy-api/src/entities/

# Find a specific feature
grep -rn "invoice" apps/legacy-api/src/routes/
```

### Frontend Exploration

```bash
# Entry point
cat apps/legacy-web/src/main.tsx

# Pages (routes)
ls apps/legacy-web/src/pages/

# Components
ls apps/legacy-web/src/components/

# API hooks
ls apps/legacy-web/src/hooks/
```

### Find Specific Code

```bash
# Find where something is defined
grep -rn "class Customer" apps/legacy-api/src/
grep -rn "interface Invoice" apps/

# Find usages
grep -rn "CustomersService" apps/legacy-api/src/

# Find tests for a file
find apps -name "*.spec.ts" | xargs grep "CustomerService"
```

## Key Patterns to Understand

### 1. Multi-Tenancy

Every business entity belongs to a `TradingCompany`:

```typescript
// All queries filter by company
const repo = CustomersRepository(tradingCompany);
const customers = await repo.findAll(); // Auto-filtered
```

### 2. Service Namespace Pattern

```typescript
// Services are imported as namespaces
import * as CustomersService from './CustomersService';

await CustomersService.findCustomer(id, tradingCompany);
```

### 3. Repository Factory Pattern

```typescript
// Repositories take TradingCompany in factory
export const CustomersRepository = (tradingCompany: TradingCompany) =>
  new (class extends RepositoryWithTradingCompany<Customer> {
    // methods
  })(tradingCompany);
```

### 4. Decimal Handling

```typescript
// API: strings ("123.45")
// Domain: Big.js (Big("123.45"))
// Database: numeric(19,4)
```

### 5. Controller Pattern

```typescript
// Controllers are THIN - just orchestration
const getById = async (req: Request, res: Response) => {
  const tradingCompany = req.getTradingCompanyOrThrow();
  const result = await CustomersService.findCustomer(id, tradingCompany);
  res.json(buildCustomerResponse(result));
};
```

## Common Questions

### "Where is X handled?"

Use the **Explore agent** to find code:

```
Find where invoice approval is handled
```

### "How does Y work?"

Read the relevant CLAUDE.md:

- Root: `CLAUDE.md` - Overall conventions
- Backend: `apps/legacy-api/CLAUDE.md`
- Frontend: `apps/legacy-web/CLAUDE.md`
- Infra: `infra/CLAUDE.md`

### "What's the architecture?"

Check `docs/architecture/`:

- Backend patterns
- Integrations (ERP)
- CI/CD workflows

### "How do I test Z?"

Check test examples:

```bash
# Find similar tests
find apps -name "*.spec.ts" | xargs grep -l "similar-feature"
cat apps/legacy-api/test/services/SimilarService.spec.ts
```

## Deep Dive by Area

### Understanding an Entity

1. Entity definition: `apps/legacy-api/src/entities/`
2. Repository: `apps/legacy-api/src/repositories/`
3. Service: `apps/legacy-api/src/services/`
4. Controller: `apps/legacy-api/src/controllers/`
5. Routes: `apps/legacy-api/src/routes/`
6. Tests: `apps/legacy-api/test/`

### Understanding a Frontend Feature

1. Page component: `apps/legacy-web/src/pages/`
2. Components: `apps/legacy-web/src/components/`
3. API hooks: `apps/legacy-web/src/hooks/`
4. Types: `apps/legacy-web/src/types/`

### Understanding Infrastructure

1. Environment config: `infra/environments/{env}/`
2. Modules used: `infra/modules/`
3. CI/CD: `.github/workflows/`

## Output

Provide:

- Relevant file paths
- Code examples
- Pattern explanations
- Links to documentation
