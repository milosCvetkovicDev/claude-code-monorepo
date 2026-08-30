---
name: ArgoCD MCP server setup
description: How to use and re-provision the user-scoped argocd-mcp server — available across all acme worktrees, URL is port-forward, token is env var
type: reference
originSessionId: 00000000-0000-0000-0000-000000000073
---
ArgoCD MCP (`argocd-mcp@latest`) is wired at **user scope** — available across every acme worktree (acme, acme-cc, acme-platform, acme-commissions, etc.) without committing to repo. ArgoCD on `development-acme-aks` is `ClusterIP`-only (no public ingress), so access is via port-forward.

**Config location:** `~/.claude.json` → top-level `mcpServers.argocd-mcp` (NOT under any project key). Env vars: `${ARGOCD_BASE_URL:-https://localhost:8080}`, `${ARGOCD_API_TOKEN}`, `NODE_TLS_REJECT_UNAUTHORIZED=0`, `MCP_READ_ONLY=${ARGOCD_MCP_READ_ONLY:-true}`. Added via `claude mcp add -s user`. Earlier project-local entry in `acme/.mcp.json` was reverted on 2026-05-07.

**Read-only by default.** Disabled tools when on: `create_application`, `update_application`, `delete_application`, `sync_application`, `run_resource_action`. Override per-session: `export ARGOCD_MCP_READ_ONLY=false`.

**To use:**
1. Port-forward must be running: `kubectl -n argocd port-forward svc/argocd-server 8080:443`
2. `ARGOCD_API_TOKEN` must be set in shell env (persisted in `~/.zshrc`)
3. Restart Claude Code to pick up env changes

**To regenerate token (token expires or new machine):**
```bash
# Ensure admin has apiKey capability (one-time, idempotent)
kubectl -n argocd patch cm argocd-cm --type merge -p '{"data":{"accounts.admin":"apiKey, login"}}'
kubectl -n argocd rollout restart deployment argocd-server

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Port-forward, then login + generate token
argocd login localhost:8080 --username admin --password '<pwd>' --insecure
argocd account generate-token --account admin
```

**Why port-forward, not ingress:** verified 2026-05-07 — `kubectl get ingress -A` returned none, `argocd-server` svc is `ClusterIP`. No public hostname configured in `argocd-cm` either. If a public ingress is added later, update `ARGOCD_BASE_URL` and consider removing `NODE_TLS_REJECT_UNAUTHORIZED=0`.

**AKS cluster:** `development-acme-aks` in `development-acme-rg`. Get creds: `az aks get-credentials -n development-acme-aks -g development-acme-rg`.
