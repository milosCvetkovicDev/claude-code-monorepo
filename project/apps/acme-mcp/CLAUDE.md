# CLAUDE.md - Acme MCP Server

MCP server providing runtime intelligence tools for Acme development.

## Overview

acme-mcp is a Model Context Protocol (MCP) server that provides Claude Code with real-time insights into the Acme codebase and infrastructure. It runs alongside Claude Code and exposes tools for:

- Database health monitoring and pg-boss job queue statistics
- Development environment status checks
- ERP integration debugging (pending sync, failed jobs, token status)
- Code navigation (entity schema, route tracing)
- Azure Application Insights error queries
- Deployment slot status and management

## Quick Reference

```bash
# Development
npx nx run acme-mcp:serve     # Start with hot reload
npx nx run acme-mcp:build     # Build for production

# Type checking
npx tsc --noEmit -p apps/acme-mcp/tsconfig.json
```

## Architecture

```
src/
├── index.ts                    # MCP server entry point, tool + resource registration
├── config/
│   └── env.ts                  # Environment configuration
├── domain/
│   ├── types.ts                # Domain types (pure, no dependencies)
│   ├── errors.ts               # Domain errors with MCP mapping
│   └── interfaces.ts           # Clean Architecture interfaces
├── infrastructure/
│   ├── database/
│   │   ├── pool.ts             # Shared PostgreSQL connection pool
│   │   └── postgres-adapter.ts # PostgreSQL + pg-boss queries
│   ├── environment/
│   │   └── environment-checker.ts # Docker, Node, dependencies checks
│   ├── erp/
│   │   └── erp-query.ts       # ERP sync monitoring
│   ├── code/
│   │   └── code-repository.ts  # TypeORM entity/route analysis
│   └── azure/
│       ├── azure-insights.ts   # Application Insights queries
│       └── azure-deployment.ts # Deployment slot management
└── utils/
    ├── logger.ts               # Structured JSON logger
    ├── pii-masker.ts           # PII masking utility
    └── response-formatter.ts   # Compact MCP response formatter
```

## Available Tools

| Tool | Description | Required Params |
| ------------------------- | ----------------------------------------- | ------------------------ |
| `health_check`            | Server health and configuration status | None |
| `db_status`               | Database connection and job queue stats | `tradingCompanyId?`      |
| `env_check`               | Docker, Node.js, dependencies, .env files | None |
| `erp_pending_sync`       | Entities pending ERP sync | `tradingCompanyId`       |
| `erp_failed_jobs`        | Failed pg-boss ERP jobs | `tradingCompanyId`       |
| `erp_token_status`       | OAuth token expiration status | `tradingCompanyId?`      |
| `entity_info`             | TypeORM entity schema and relations | `entityName`             |
| `route_chain`             | Route → controller → service chain | `method`, `path`         |
| `azure_errors`            | Application Insights error query | `environment`            |
| `azure_deployment_status` | Slot status for services | `environment`, `service` |
| `azure_slot_swap`         | Swap deployment slots | `environment`, `confirm` |
| `invalidate_cache`        | Clear code analysis cache | `filePath?`              |

## MCP Resources

Static data accessible without tool calls (via `ReadMcpResourceTool`):

| Resource | URI                    | Description |
| ------------- | ---------------------- | ------------------------------- |
| `health`      | `acme://health`      | Server health and config status |
| `environment` | `acme://environment` | Docker, Node, deps, .env status |

## Tool Annotations

All tools include MCP annotations for permission hints:

- Most tools: `readOnlyHint: true` — safe to auto-approve
- `azure_slot_swap`: `destructiveHint: true` — requires explicit confirmation
- `invalidate_cache`: `readOnlyHint: false` — modifies internal state
- Azure tools: `openWorldHint: true` — interact with external services

## Configuration

Environment variables (set in `.mcp.json` or shell):

| Variable | Required | Default | Description |
| --------------------------------------- | -------- | ------------------- | ------------------------------------- |
| `DB_HOST`                               | No | `localhost`         | PostgreSQL host |
| `DB_PORT`                               | No | `5433`              | PostgreSQL port |
| `DB_USERNAME`                           | No | `legacy`             | Database username |
| `DB_PASSWORD`                           | No | Empty | Database password |
| `DB_NAME`                               | No | `legacy_development` | Database name |
| `DB_SSL_ENABLED`                        | No | `false`             | Enable SSL for DB connection |
| `LOG_LEVEL`                             | No | `info`              | Logging level (debug/info/warn/error) |
| `AZURE_LOG_ANALYTICS_WORKSPACE_ID_DEV`  | No | -                   | Development workspace ID              |
| `AZURE_LOG_ANALYTICS_WORKSPACE_ID_PROD` | No | -                   | Production workspace ID               |
| `AZURE_SUBSCRIPTION_ID_DEV`             | No | -                   | Development subscription |
| `AZURE_SUBSCRIPTION_ID_PROD`            | No | -                   | Production subscription |

## Clean Architecture

The codebase follows Clean Architecture principles:

1. **Domain Layer** (`domain/`) - Pure business logic

   - Types with no external dependencies
   - Domain errors that map to MCP error codes
   - Interfaces that infrastructure must implement

2. **Infrastructure Layer** (`infrastructure/`) - External adapters

   - PostgreSQL adapter for database queries
   - Environment checker using shell commands
   - Azure CLI integration for cloud operations
   - Code analysis using file system

3. **Application Layer** (`index.ts`) - Tool orchestration
   - Wires domain interfaces to infrastructure
   - Registers MCP tools with proper error handling
   - Manages server lifecycle

## Multi-Tenancy

ERP-related tools **require** `tradingCompanyId` parameter to enforce multi-tenancy:

```typescript
// Throws MultiTenancyViolationError if tradingCompanyId is missing
erp_pending_sync({ tradingCompanyId: 1 });
erp_failed_jobs({ tradingCompanyId: 1 });
```

## PII Masking

All outputs are automatically masked for PII:

- Email addresses: `j***@***.com`
- Phone numbers: `[PHONE_MASKED]`
- JWT tokens: `[JWT_MASKED]`
- Session/User IDs: `[SESSION_MASKED]`, `[USER_MASKED]`

## Error Handling

Domain errors are mapped to MCP error codes:

| Domain Error | MCP Code | HTTP Status |
| ---------------------------- | -------- | ----------- |
| `ValidationError`            | -32602   | 400         |
| `MultiTenancyViolationError` | -32602   | 400         |
| `EntityNotFoundError`        | -32001   | 404         |
| `DatabaseConnectionError`    | -32002   | 503         |
| `DatabaseQueryError`         | -32003   | 500         |
| `AzureQueryTimeoutError`     | -32004   | 504         |
| `AzureAuthenticationError`   | -32005   | 401         |
| `AzureNotConfiguredError`    | -32006   | 503         |

## Development

### Adding a New Tool

1. Define types in `domain/types.ts`
2. Add interface method in `domain/interfaces.ts`
3. Implement adapter in `infrastructure/`
4. Register tool in `index.ts` with zod schema, annotations, and `formatResponse()` for compact output

### Testing Locally

```bash
# Start the server
bun run apps/acme-mcp/src/index.ts

# The server communicates via stdio (JSON-RPC)
# Use an MCP client or Claude Code to interact
```

## Runtime Requirements

- **Bun** runtime (not Node.js)
- PostgreSQL database (for db*status, erp*\* tools)
- Azure CLI authenticated (`az login`) for azure\_\* tools
- Docker installed for env_check tool
