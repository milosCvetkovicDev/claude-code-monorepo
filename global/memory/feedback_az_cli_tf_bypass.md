---
name: az-cli-tf-bypass-acceptable
description: When TF apply is blocked by unrelated issues, az CLI direct mutation of App Service / Container App config is an acceptable stopgap; state self-heals on next successful TF refresh
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000064
---
When `terraform apply` is blocked by an issue that has nothing to do with the
change you actually want to ship (e.g. a broken module elsewhere in the env,
a CI-SP permission gap, a state lock you can't clear), it is acceptable to
mutate the target Azure resource directly via `az` CLI as a stopgap, then let
TF state reconcile on the next successful apply.

**Why:** TF refreshes state from the live API at the start of every plan. So
a CLI-side change to an in-place attribute (e.g. App Service `linuxFxVersion`,
app_settings, container app revision config) creates a *temporary* drift that
disappears on the next clean `terraform plan`. No state surgery, no `import`,
no `taint`. The user gets the change today; the IaC discipline self-heals
tomorrow. Validated 2026-04-30 with `az webapp config set --linux-fx-version
"NODE|22-lts"` for development-acme-legacy-api-web-app while issue #608
blocked the dev TF path.

**How to apply:**
- Verify the bypass target is an in-place attribute (TF would `~ update` not
  `-/+ replace`). For replace-only attributes, this pattern doesn't work.
- Confirm the change is also already merged to `main` so the next TF refresh
  agrees with reality. If you bypass without first landing the code change,
  next apply will revert your CLI change.
- Open or update an issue capturing why TF was blocked, so the underlying
  problem doesn't get forgotten.
- Do NOT use this pattern for `azurerm_role_assignment`, secrets, or anything
  that creates new resources — only for in-place property updates on existing
  resources.
- Do NOT use this for prod-acme-legacy without explicit user approval — it
  bypasses the manual-approval gate built into `terraform-deploy.yml`.

2026-05-15: PR #777 queued (branch `infra/773-kv-delete-tf-runner`) to
grant the `development-acme-runner` VM MI `Get/List/Set/Delete` on
`development-acme-kv` via a standalone `azurerm_key_vault_access_policy`.
Once merged + applied by ops, the az-CLI bypass becomes optional for KV
secret rotations that go through that runner (taint + apply now succeeds end
to end). Rule remains for transitional cases — local-developer TF runs
still rely on a manually-set access policy that ping-pongs against the CI
SP via `data.azurerm_client_config.current.object_id`, and prod KV
has not yet been updated.
