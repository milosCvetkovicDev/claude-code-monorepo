---
name: run-script
description: "Run scripts with automatic configuration validation to catch secret names, env vars, and credential mismatches before execution. Use when the user wants to run a script that depends on environment configuration. Do not use for running tests (use test-affected) or starting dev servers (use dev-servers)."
---

# Script Runner with Config Validation

This skill validates configuration before running scripts, preventing runtime failures from misnamed secrets, incorrect environment variables, or username mismatches.

## When to Use

- Running database seeding scripts
- Executing deployment scripts
- Running any script that depends on environment variables or secrets
- Testing scripts locally before CI/CD

## Workflow

### 1. Identify Configuration Dependencies

Scan the script to find all configuration requirements:

- Environment variable references (`process.env.X`, `$VAR_NAME`)
- Secret names (KeyVault, AWS Secrets Manager, etc.)
- Database credentials (host, port, username, password)
- API endpoints and URLs

### 2. Validate Configuration Files

Check all relevant configuration sources:

- `.env` and `.env.local` files
- `config/` directory files
- Infrastructure-as-code files (Terraform, CloudFormation)
- CI/CD configuration (`.github/workflows/`, `.gitlab-ci.yml`)

### 3. Cross-Reference Values

For each configuration dependency:

- ✅ Verify it exists in the configuration files
- ✅ Check naming is consistent across all files
- ✅ Validate format (URLs, connection strings, etc.)
- ✅ Flag any mismatches between environments

### 4. Report Validation Results

Before running the script, report:

- ✅ **All valid**: List all verified configuration values
- ⚠️ **Warnings**: Values that exist but might be incorrect (e.g., localhost in prod)
- ❌ **Errors**: Missing or misnamed configuration that will cause failures

### 5. Run Script (If Valid)

Only proceed with execution if:

- No critical errors found
- User confirms warnings are acceptable
- All required configuration is present

### 6. Monitor Execution

During script execution:

- Capture all output (stdout and stderr)
- Watch for configuration-related errors
- If errors occur, re-validate the failing configuration

## Example Usage

```bash
# User says: "Run the seeding script"
# Skill automatically:

1. Read apps/legacy-api/scripts/seed-database.ts
2. Extract: DATABASE_URL, AZURE_CLIENT_ID, ERP_CLIENT_SECRET
3. Check .env: ✅ DATABASE_URL present, ✅ AZURE_CLIENT_ID present
4. Check .env: ❌ ERP_CLIENT_SECRET not found
5. Report: "Found missing secret ERP_CLIENT_SECRET - check .env file"
6. Ask: "Fix configuration before running?"
```

## Common Issues Caught

- ❌ Secret name typos (`ERP_CLINET_SECRET` instead of `ERP_CLIENT_SECRET`)
- ❌ Username variable mismatches (`DB_USER` in code, `DB_USERNAME` in env)
- ❌ Environment-specific URLs hardcoded (localhost in production config)
- ❌ Missing port numbers in connection strings
- ❌ Incorrect schema names in database URLs

## Configuration Sources Checked

1. **Environment Files**: `.env`, `.env.local`, `.env.production`, `.env.development`
2. **Config Directories**: `config/`, `apps/*/config/`
3. **Infrastructure**: `infra/`, Terraform variable files
4. **CI/CD**: `.github/workflows/`, workflow environment variables
5. **Code**: Direct `process.env` or `import.meta.env` references

## Exit Conditions

- ✅ **Proceed**: All configuration valid, script executes
- ⚠️ **Warning**: Non-critical issues, user decides to proceed or fix
- ❌ **Block**: Critical configuration missing, must fix before running
