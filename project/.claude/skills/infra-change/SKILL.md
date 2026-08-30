---
name: infra-change
description: 'Modify Terraform infrastructure or Azure resource configurations. Use when the user needs to add, change, or remove cloud resources (App Services, databases, Key Vaults, networking). Do not use for application code changes or CI/CD workflow modifications (use cicd-troubleshoot).'
model: sonnet
disable-model-invocation: true
---

# Infrastructure Change Workflow

You are orchestrating an infrastructure change with proper review and safety checks.

## Workflow Steps

### Step 1: Technical Specification

Use the **technical-spec agent** to:

- Document the infrastructure change
- Identify affected resources
- Plan the change sequence
- Define rollback strategy
- Assess blast radius

Output: Technical spec in `docs/plans/`

### Step 2: Implementation

Use the **terraform-expert agent** to implement the infrastructure change:

- Modify Terraform in `infra/modules/` or `infra/environments/`
- Update CI/CD workflows in `.github/workflows/`

The **terraform-expert agent** ensures:

- No hardcoded subscription/tenant IDs
- Variables have descriptions
- Sensitive outputs are marked
- `prevent_destroy` on critical resources
- Proper module structure
- Azure best practices

### Step 3: Validation

Use **terraform-expert agent** and run validation:

```bash
npx nx run infra:fmt
npx nx run infra:validate
npx nx run infra:plan:<environment>
```

Review the plan output carefully for:

- Unexpected destroys
- Resource replacements
- Cost implications

### Step 4: Azure Architecture Review

Use the **review-azure-architect agent** to verify:

- Azure Well-Architected Framework compliance
- Security hardening (managed identity, private endpoints)
- Cost optimization (right-sized SKUs)
- Reliability (zone redundancy, backups)
- No changes to protected resources (DNS zones, Communication Services)

### Step 5: DevOps Review

Use the **review-devops-architect agent** to verify:

- CI/CD pipeline safety
- Deployment can be rolled back
- Health checks configured
- No secrets in logs
- Concurrency controls in place
- Actions pinned to SHA

### Step 6: Documentation

Use the **documentation-writer agent** if needed to:

- Update infrastructure documentation
- Create ADR for significant changes
- Update runbooks

## Protected Resources Warning

**NEVER modify these without explicit approval:**

- `acme-example.co.uk` DNS Zone
- `partner-portal.example` DNS Zone
- Communication Services in shared-acme-rg

## Output

Provide a summary including:

- Resources created/modified/destroyed
- Terraform plan summary
- Review findings addressed
- Rollback procedure
- Apply instructions
