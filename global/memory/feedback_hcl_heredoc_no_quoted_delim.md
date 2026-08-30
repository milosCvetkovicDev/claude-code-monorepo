---
name: feedback-hcl-heredoc-no-quoted-delim
description: HCL heredoc doesn't support `<<-'EOT'` (bash-style single-quoted delimiter to suppress interpolation). Use `<<-EOT` and rely on the fact that HCL only treats `${...}` (braces required) as interpolation — unbraced `$VAR` passes through as literal text to the consumer (shell, etc.).
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

In bash, `<<-'EOT'` suppresses parameter expansion inside the heredoc body. In HCL, that syntax is invalid:

```
Error: Invalid expression
  on main.tf line 80, in resource "null_resource" "quota_check":
  80:     command = <<-'EOT'

Expected the start of an expression, but found an invalid expression token.

Error: Invalid character
  on main.tf line 80, ...
  80:     command = <<-'EOT'
Single quotes are not valid. Use double quotes (") to enclose strings.
```

**Why:** HCL's heredoc spec only supports `<<EOT` and `<<-EOT` (the dash variant strips leading whitespace). No quoting modifier exists.

But there's good news: HCL only treats `${...}` (with braces) as interpolation. Unbraced `$VAR` (bash-style) passes through as literal text to whatever consumes the heredoc — most commonly a shell via `provisioner.local-exec.command`. So you can route values to the shell via `environment` and use `$VAR` references inside the heredoc body without HCL trying to interpolate them.

**How to apply:**

Pattern for a Terraform `local-exec` that needs values from variables but should NOT shell-inject them via HCL interpolation:

```hcl
resource "null_resource" "example" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    # Route values through `environment` — keeps HCL out of the interpolation path
    # and gives shell-level quoting safety.
    environment = {
      MY_LOCATION = var.location
      MY_NAME     = var.name
    }
    # `<<-EOT` (no single quote!) — HCL's heredoc. Unbraced `$VAR` survives
    # HCL's parser and is resolved by bash at runtime.
    command = <<-EOT
      set -eu
      echo "Running in $MY_LOCATION for $MY_NAME"
      az something --location "$MY_LOCATION"
    EOT
  }
}
```

If you ACTUALLY need HCL interpolation inside the heredoc (e.g. you want HCL to substitute `${var.foo}` at plan time), just use `${var.foo}` directly — that always works. The escape rule is for the OPPOSITE case where you want HCL to leave the `$` alone.

**Anti-pattern caught:** Initially I copy-pasted a bash-style `<<-'EOT'` heredoc into the TF, which broke `terraform validate`. PR #862 commit `97551614` corrected this when applying review feedback for the shell-injection finding.
