---
name: new-app
description: "Scaffold and configure a new application in the Acme Nx monorepo with proper project structure, configuration, and CI/CD integration. Use when the user needs a brand new app (frontend or backend) in the monorepo. Do not use for adding features to existing apps (use new-feature) or libraries (use scaffold-project)."
model: sonnet
---

# New App Workflow

You are orchestrating the creation of a new application in the Nx monorepo.

## Workflow Steps

### Step 1: Requirements & Design
Use the **technical-spec agent** to:
- Define the app's purpose and scope
- Identify technology stack (Express/React/other)
- Plan integration points with existing apps
- Define infrastructure requirements
- Specify CI/CD pipeline needs

Output: Technical spec in `docs/plans/`

### Step 2: Scaffold Application
Use the **nx-expert agent** to guide scaffolding:

```bash
# For backend app
npx nx generate @nx/node:application apps/<app-name> --framework=express

# For frontend app
npx nx generate @nx/react:application apps/<app-name> --bundler=vite

# For library
npx nx generate @nx/node:library libs/<lib-name> --buildable
```

**CRITICAL**: Always use Nx generators, never manually create directories.

The **nx-expert agent** will help with:
- Choosing the right generator and options
- Configuring project tags for module boundaries
- Setting up task pipelines and caching
- Verifying the project graph

### Step 3: Configure Application
Set up the app following project conventions:
- Create `CLAUDE.md` with app-specific guidance
- Configure TypeScript paths in `tsconfig.base.json`
- Set up ESLint with proper Nx tags (`scope:`, `layer:`, `type:`)
- Configure testing (Jest for unit, Playwright for E2E)
- Set up environment variables template

### Step 4: Infrastructure Setup
If the app needs Azure resources, use the **terraform-expert agent** to:
- Create Terraform module in `infra/modules/`
- Add environment configuration in `infra/environments/`
- Configure CI/CD workflow in `.github/workflows/`
- Ensure no hardcoded values (use variables)
- Add proper lifecycle protection for critical resources

### Step 5: Architecture Review
Use the **review-enterprise-architect agent** to verify:
- Clean Architecture compliance
- Proper separation of concerns
- Nx module boundaries configured
- No circular dependencies
- Follows monorepo conventions

### Step 6: DevOps Review
Use the **review-devops-architect agent** to verify:
- CI/CD pipeline is correct
- Health checks configured
- Deployment strategy defined
- Rollback capability exists

## Output
Provide a summary including:
- App location and structure
- Nx configuration
- Available commands (`nx run <app>:serve`, etc.)
- Infrastructure resources (if any)
- Next steps for development
