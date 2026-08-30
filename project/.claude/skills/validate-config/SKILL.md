---
name: validate-config
description: "Spawn parallel agents to validate configuration consistency across all environments, catching secret and variable mismatches before runtime. Use when deploying or modifying environment configuration. Do not use for checking local dev environment (use env-status) or running scripts (use run-script)."
---

# Parallel Configuration Validation

## Architecture

```
                    ┌─────────────────────┐
                    │ Main Orchestrator   │
                    │ (/validate-config)  │
                    └──────────┬──────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
         ┌──────▼──────┐ ┌────▼─────┐ ┌─────▼──────┐
         │  Agent 1    │ │ Agent 2  │ │  Agent 3   │
         │  Dev Env    │ │ Staging  │ │  Production│
         └──────┬──────┘ └────┬─────┘ └─────┬──────┘
                │              │              │
         [Validation] [Validation]    [Validation]
                │              │              │
                └──────────────┼──────────────┘
                               │
                    ┌──────────▼──────────┐
                    │ Consolidated Report │
                    │ ✅ ⚠️ ❌            │
                    └─────────────────────┘
```

## Workflow

### Phase 1: Discovery

Identify all configuration sources:

- `.env` files (all variants: `.env`, `.env.local`, `.env.production`)
- `config/` directory files
- Infrastructure code (Terraform `*.tf`, `*.tfvars`)
- CI/CD configurations (`.github/workflows/*.yml`, `azure-pipelines.yml`)
- Cloud provider secrets (Azure Key Vault, AWS Secrets Manager)
- Application configuration files (`appsettings.json`, `config.ts`)

### Phase 2: Schema Definition

Define expected configuration structure:

- Required secrets (e.g., `ERP_CLIENT_SECRET`, `DATABASE_PASSWORD`)
- Required environment variables (e.g., `PORT`, `NODE_ENV`)
- Expected formats (URLs, connection strings, GUIDs)
- Conditional requirements (e.g., `AZURE_CLIENT_SECRET` only in prod)

### Phase 3: Parallel Agent Spawn

Use the Task tool to spawn agents concurrently:

```typescript
// Spawn 3 agents in parallel
Task(agent=config-validator, scope=development, config_sources=...)
Task(agent=config-validator, scope=staging, config_sources=...)
Task(agent=config-validator, scope=production, config_sources=...)
```

Each agent independently:

1. Reads its assigned configuration sources
2. Extracts all variable references
3. Cross-checks against schema
4. Validates formats and values
5. Reports findings

### Phase 4: Agent Tasks

Each validation agent performs:

#### A. Extraction

- Find all environment variable references (`process.env.X`, `$VAR`, `%VAR%`)
- Locate all secret names (KeyVault refs, Secrets Manager ARNs)
- Extract database credential patterns
- Identify API endpoint URLs

#### B. Validation

- **Existence check**: Does the variable exist in config files?
- **Naming consistency**: Same name across all files?
- **Format validation**: URL? GUID? Connection string?
- **Placeholder detection**: Contains `TODO`, `CHANGEME`, `<placeholder>`?
- **Drift detection**: Production value differs from staging?

#### C. Reporting

- ✅ **Valid**: All checks passed
- ⚠️ **Warning**: Non-critical issue (e.g., localhost in dev)
- ❌ **Error**: Critical missing or misnamed variable

### Phase 5: Consolidation

Main orchestrator collects results:

- Merge findings from all agents
- Identify cross-environment inconsistencies
- Prioritize critical errors
- Generate actionable report

## Output Format

### Summary

```
🔍 Configuration Validation Report
📅 Run at: 2026-02-05 16:45:23 UTC

🌍 Environments checked: 3 (dev, staging, production)
📁 Config files scanned: 47
🔑 Secrets validated: 23
🔧 Variables checked: 89

Status: ⚠️ 2 critical errors, 5 warnings
```

### Critical Errors (❌)

```
❌ ERP_CLIENT_SECRET
   ├─ Development: ✅ Present in .env
   ├─ Staging: ❌ MISSING in Azure Key Vault
   └─ Production: ✅ Present in Azure Key Vault

   Action: Add secret to staging Key Vault

❌ DATABASE_URL
   ├─ Development: postgresql://legacy:***@localhost:5434/legacy_dev_2
   ├─ Staging: postgresql://legacy:***@localhost:5432/legacy_staging
   └─ Production: postgresql://legacy:***@prod-db.postgres.database.azure.com:5432/legacy_prod

   Issue: Staging points to localhost (should be Azure PostgreSQL)
   Action: Update staging DATABASE_URL to Azure endpoint
```

### Warnings (⚠️)

```
⚠️ ENVIRONMENT_NAME
   ├─ Development: "development" ✅
   ├─ Staging: "dev" ⚠️ (expected: "staging")
   └─ Production: "production" ✅

   Suggestion: Standardize staging ENVIRONMENT_NAME

⚠️ PORT
   ├─ Development: 3001 ✅
   ├─ Staging: 3000 ⚠️ (differs from dev)
   └─ Production: 3000 ✅

   Note: Port mismatch between dev and staging (likely intentional)
```

### All Valid (✅)

```
✅ ENTRA_CLIENT_ID: Consistent across all environments
✅ ENTRA_TENANT_ID: Consistent across all environments
✅ AZURE_STORAGE_CONNECTION_STRING: Format valid, all environments
[... 18 more valid configurations]
```

## Agent Implementation

Each agent follows this pattern:

```typescript
// Agent: config-validator-{environment}
// Scope: Single environment (dev/staging/prod)

async function validateEnvironment(scope: string) {
  // 1. Load configuration sources
  const envFiles = await loadEnvFiles(scope);
  const infraConfig = await loadInfraConfig(scope);
  const cicdConfig = await loadCICDConfig(scope);

  // 2. Extract all variable references
  const variables = extractVariables([envFiles, infraConfig, cicdConfig]);

  // 3. Validate against schema
  const results = [];
  for (const variable of schema.requiredVariables) {
    const validation = validateVariable(variable, variables);
    results.push(validation);
  }

  // 4. Return structured results
  return {
    scope,
    timestamp: new Date().toISOString(),
    errors: results.filter((r) => r.severity === 'error'),
    warnings: results.filter((r) => r.severity === 'warning'),
    valid: results.filter((r) => r.severity === 'valid'),
  };
}
```

## Spawn Command

To invoke multiple validation agents:

```bash
# In Claude Code skill execution:
Task(
  subagent_type="general-purpose",
  description="Validate dev config",
  prompt="Load and validate all configuration for development environment..."
)

Task(
  subagent_type="general-purpose",
  description="Validate staging config",
  prompt="Load and validate all configuration for staging environment..."
)

Task(
  subagent_type="general-purpose",
  description="Validate prod config",
  prompt="Load and validate all configuration for production environment..."
)

# All three run in parallel!
```

## Configuration Schema Example

```typescript
export const ConfigSchema = {
  requiredVariables: [
    {
      name: 'DATABASE_URL',
      format: /^postgresql:\/\/.+/,
      required: ['development', 'staging', 'production'],
      validation: (value, env) => {
        if (env !== 'development' && value.includes('localhost')) {
          return { valid: false, message: 'Production DB should not use localhost' };
        }
        return { valid: true };
      },
    },
    {
      name: 'ERP_CLIENT_SECRET',
      format: /.{32,}/, // At least 32 characters
      required: ['staging', 'production'], // Not required in dev (can use mock)
      sensitive: true, // Don't log the value
    },
    {
      name: 'ENTRA_CLIENT_ID',
      format: /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, // GUID
      required: ['development', 'staging', 'production'],
      mustMatch: true, // Should be same across all environments
    },
  ],

  optionalVariables: [
    {
      name: 'AZURITE_PORT',
      format: /^\d{4,5}$/,
      required: ['development'], // Only used locally
    },
  ],
};
```

## Integration with CI/CD

Add as a pre-deployment check:

```yaml
# .github/workflows/deploy.yml
- name: Validate Configuration
  run: |
    claude --headless \
      --max-turns 5 \
      --task "Use /validate-config skill for ${{ github.event.inputs.environment }}" \
      --allowedTools "Read,Grep,Glob,Task"

    # Check exit code
    if [ $? -ne 0 ]; then
      echo "Configuration validation failed"
      exit 1
    fi
```

