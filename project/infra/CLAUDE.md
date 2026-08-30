# CLAUDE.md - Infrastructure (Terraform)

Extends root `CLAUDE.md`. Azure infra managed via Terraform modules.

## Critical Rules

**NEVER delete `shared-acme-rg` resources** (Azure sub 1) — DNS zones + Communication Services route production traffic. Protected by `prevent_destroy` + Azure management locks.

**NEVER hardcode** IDs, secrets, subscription IDs, tenant IDs, or IPs in Terraform. Use `data.azurerm_client_config.current`, variables, or module outputs.

## Commands

```bash
nx run infra:{fmt,validate,plan,apply}:{environment}
```

## Environments & Subscriptions

| Environment | Subscription (ID)                                    | Resource Group | Key Vault |
| ------------------ | ---------------------------------------------------- | ----------------------- | ----------------------- |
| development | Sponsorship (`00000000-0000-0000-0000-000000000002`) | `development-acme-rg` | `development-acme-kv` |
| prod-acme-legacy | Sponsorship (`00000000-...`)                         | `prod-acme-rg` | `prod-acme-kv` |
| shared | Sub 1 (`00000000-0000-0000-0000-000000000004`)       | `shared-acme-rg`      | —                       |

## Module Standards

Every module: `main.tf`, `variables.tf` (with descriptions+validation), `outputs.tf` (with descriptions). Use `locals` for complex expressions. Mark sensitive vars/outputs. Use `${var.environment}-acme` prefix.

## Key Patterns

- **Providers**: Environment level only, never in modules
- **Secrets**: Manage via Azure CLI (not Terraform) — KV firewall blocks CI runners
- **Conditional resources**: `count`/`for_each` — keys must be non-sensitive; sensitive values inside `content` only
- **Dependencies**: `depends_on` for ordering, module outputs for implicit deps
- **Security**: Managed Identity, KV references for secrets, network isolation by default, TLS 1.2+
- **CI SP permissions**: OIDC service principal has `Contributor` — CANNOT create `azurerm_management_lock` or `azurerm_role_assignment` (require `Owner`/`User Access Administrator`). Create these manually.

## CI/CD

| Workflow | Trigger | Purpose |
| ------------------------ | ----------------- | --------------------------------- |
| `ci.yml`                 | push/PR           | Build+test affected |
| `deploy.yml`             | after CI / manual | Deploy apps (Nx affected)         |
| `terraform-validate.yml` | PRs with `infra/` | Format+validate+plan |
| `terraform-deploy.yml`   | Manual only | Apply infra (prod needs approval) |

Deploy order: shared → development (auto) → prod-acme-legacy (manual + approval). Pin GitHub Actions to full commit SHAs. OIDC auth with Azure.

### Self-Hosted Runner (`github-runner` module)

8-core Azure VM for faster frontend tests. Development only.

- **Module**: `infra/modules/github-runner/` — VM, NIC, NSG (NIC-level), auto-shutdown
- **Network**: Conditional subnet `10.0.3.0/28` via `enable_runner_subnet` on network module
- **Registration**: Manual post-provisioning (binary installed by cloud-init, registered via `az vm run-command invoke`)
- **Manual resources** (not in TF — CI SP lacks permissions): management lock, role assignment (VM Contributor → OIDC SP)
- **CI flow** (`ci.yml`): `start-runner` (no dependencies, parallel) → `main` (all tests on self-hosted) OR `fallback-main` + `fallback-frontend-tests` (hosted, with `always()` safety net)
- **Development `terraform-deploy.yml`**: Full `terraform apply` (dependency cycle fixed in PR #133)

## Common Gotchas (terse)

| Issue | Fix |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| KV `ForbiddenByFirewall` in CI                                  | Manage secrets via `az keyvault secret set` locally |
| `workflow_run` not triggering on feature branch | Use `workflow_dispatch`; `workflow_run` only works from main |
| Cross-subscription `ResourceGroupNotFound`                      | Multi-provider setup or local resources |
| Storage 403 race condition | Wait 60s after network rule change, or staged apply |
| `Invalid count argument` (computed)                             | Staged targeted applies |
| Front Door custom domain migration | Pre-create 2+ hours early; cert takes 30-45 min |
| Container App can't reach PG                                    | `allow_azure_services = true` on postgres module |
| `EBADPLATFORM` in CI                                            | Move platform-specific deps to `optionalDependencies`                                                                                                                                                                                                                                                                                                                                                                                                            |
| Sensitive var in `for_each`                                     | Condition on non-sensitive var; sensitive values inside `content` only |
| KV secrets deleted by Terraform | Recover: `az keyvault secret recover`; then manage outside TF                                                                                                                                                                                                                                                                                                                                                                                                    |
| State lock stuck | `terraform force-unlock -force <id>`                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Container App KV access | `bypass = "AzureServices"` on KV network ACLs |
| Commission-api accidentally deleted | `enable_delete_lock = false` in both envs (CI SP lacks locks/write); manage locks manually via `az lock create`. Remove lock before intentional teardown |
| Runner lock/role 403 in CI                                      | CI SP has `Contributor` only; create `azurerm_management_lock` and `azurerm_role_assignment` manually via `az` CLI                                                                                                                                                                                                                                                                                                                                               |
| Runner not coming online in CI                                  | Check cloud-init finished (`az vm run-command invoke`), check systemd service (`svc.sh status`), verify registration token not expired |
| KV access policy state drift | `az keyvault delete-policy --object-id <id>` → re-run `terraform apply` to recreate in state |
| Development TF apply fails on commission_api | Dependency cycle fixed: `data.azurerm_container_app` + standalone KV policies. Full apply works. **Greenfield:** deploy `module.commission_api` first via `-target`                                                                                                                                                                                                                                                                                              |
| Commission-api 503 after deploy | Check `COMMISSION_API_URL` FQDN matches actual Container App + `WEBSITE_VNET_ROUTE_ALL=1` is set. Smoke test (Test 5) now catches this pre-swap (PR #121)                                                                                                                                                                                                                                                                                                        |
| App settings drift after slot swap | Both `COMMISSION_API_URL` and `COMMISSION_API_WEBHOOK_URL` are sticky (PR #121, #132). Run Terraform Deploy after infra changes |
| KQL alert HTTP 400 on greenfield apply | `ContainerAppSystemLogs_CL` / `ContainerAppConsoleLogs_CL` materialize only after Container Apps emit logs. Apply with `enable_log_dependent_alerts = false`, wait 5-15 min for logs, flip to `true`, re-apply. See #739                                                                                                                                                                                                                                         |
| Public traffic to AKS LB times out (80 **and** 443, no SYN-ACK) | The custom subnet NSG (`*-nsg-aks-nodes`) has no public-inbound rule, so traffic dies at `deny-all-inbound`. **AKS's cloud-controller only updates the NSG it manages (the `MC_…` agentpool/NIC NSG) — it NEVER touches a Terraform-owned subnet NSG.** Set `enable_public_web_ingress = true` on `modules/network` → adds `Internet → TCP 80,443` @ priority 300. Symptom is invisible to every gate + pod-health (kubelet probes are node-local). See PR #1483 |

## Checklist Before Committing

- No hardcoded IDs/secrets, all vars have descriptions, sensitive marked, `terraform fmt` + `validate` pass
