---
name: dev-ephemeral
description: "Manage on-demand Azure development instances: deploy, destroy, and check status of isolated environments for feature verification. Use when the user wants to test a feature branch on Azure. Do not use for local development (use dev-servers) or production deployments (use hotfix or infra-change)."
model: sonnet
disable-model-invocation: true
---

# On-Demand Azure Dev Instance Management

Manage isolated Azure development environments for feature verification.

## Available Actions

| Action | Description | Command |
| --------- | --------------------------------- | ----------------------------------------- |
| `status`  | Check which instances are running | `./scripts/azure-dev-ephemeral/status.sh`  |
| `deploy`  | Create a dev instance | `./scripts/azure-dev-ephemeral/deploy.sh`  |
| `destroy` | Remove a dev instance | `./scripts/azure-dev-ephemeral/destroy.sh` |

## Instance Naming

Instances use Azure aliases auto-generated from worktree names:

| Worktree Name | Azure Alias | Resource Group | Monthly Cost |
| ---------------------- | ----------- | ------------------- | ------------ |
| `commission-reporting` | `dev-cr`    | `dev-cr-acme-rg`  | ~$29         |
| `hotfix`               | `dev-h`     | `dev-h-acme-rg`   | ~$29         |
| `user-auth-flow`       | `dev-uaf`   | `dev-uaf-acme-rg` | ~$29         |

Find your alias: `acme-worktree list` or `acme-worktree status <name>`

## Workflow

### Check Status First

Always check which instances are running before deploying:

```bash
./scripts/azure-dev-ephemeral/status.sh
```

### Deploy an Instance

Deploy using your Azure alias or worktree name:

```bash
# By alias
./scripts/azure-dev-ephemeral/deploy.sh dev-cr

# By worktree name
./scripts/azure-dev-ephemeral/deploy.sh --name commission-reporting

# With auto-approve (no confirmation)
./scripts/azure-dev-ephemeral/deploy.sh dev-cr --auto-approve
```

### Deploy Application Code

After infrastructure is created, deploy your application:

```bash
# Deploy backend
gh workflow run deploy.yml -f environment=dev-cr -f app=legacy-api

# Deploy frontend
gh workflow run deploy.yml -f environment=dev-cr -f app=legacy-web
```

### Verify Feature

Test your feature at the Azure URLs shown in the deployment output.

### Track Deployment on Issue

Add a label to auto-destroy when the issue closes:

```bash
gh issue edit 55 --add-label "deployed:dev-cr"
```

### Destroy When Done

**IMPORTANT:** Destroy instances to save costs (~$29/month per instance):

```bash
./scripts/azure-dev-ephemeral/destroy.sh dev-cr

# With auto-approve
./scripts/azure-dev-ephemeral/destroy.sh dev-cr --auto-approve
```

## Using GitHub Actions Instead

For deploy/destroy without local Azure CLI setup:

```bash
# Deploy
gh workflow run deploy-dev-ephemeral.yml -f instance=dev-cr -f action=deploy

# Status
gh workflow run deploy-dev-ephemeral.yml -f instance=dev-cr -f action=status

# Destroy
gh workflow run deploy-dev-ephemeral.yml -f instance=dev-cr -f action=destroy
```

## Prerequisites

For local scripts:

- Azure CLI logged in (`az login`)
- Terraform installed
- IP whitelisted in development Key Vault

For GitHub Actions:

- No local setup required
- Uses OIDC authentication

## Common Issues

### Key Vault Access Denied

```bash
MY_IP=$(curl -s https://ifconfig.me)
az keyvault network-rule add --name development-acme-kv --ip-address "$MY_IP"
```

### Instance Already Exists

```bash
./scripts/azure-dev-ephemeral/destroy.sh dev-cr
./scripts/azure-dev-ephemeral/deploy.sh dev-cr
```

## Resources Created

Each instance creates:

- App Service (B1) - ~$13/month
- PostgreSQL (B_Standard_B1ms) - ~$15/month
- Storage Account - ~$1/month
- Static Web App (Free) - $0/month

## Documentation

- Full documentation: `docs/architecture/azure-dev-ephemerals/README.md`
- Scripts: `scripts/azure-dev-ephemeral/`
- Terraform: `infra/environments/dev-ephemeral/`
- Unified config: `scripts/local-multi-instance/multi-instance.config.json`
