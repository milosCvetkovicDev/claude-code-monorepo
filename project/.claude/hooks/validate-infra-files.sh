#!/bin/bash

# Validate infrastructure files after Claude edits them
# PostToolUse hook for Write/Edit operations on .tf and .github/ YAML files

set -e

# Parse input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only process Write and Edit tools
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Get file extension and directory
EXT="${FILE_PATH##*.}"
DIR=$(dirname "$FILE_PATH")

WARNINGS=""

# ─── Terraform Files (.tf) ───
if [[ "$EXT" == "tf" ]]; then
  # 1. Run terraform fmt check
  if command -v terraform &> /dev/null; then
    FMT_OUTPUT=$(terraform fmt -check -diff "$FILE_PATH" 2>&1) || true
    if [[ -n "$FMT_OUTPUT" ]]; then
      # Auto-fix formatting
      terraform fmt "$FILE_PATH" 2>/dev/null || true
      WARNINGS="$WARNINGS Terraform formatting was auto-corrected."
    fi
  fi

  # 2. Check for hardcoded values (common mistake)
  HARDCODED=$(grep -nE '(subscription_id|tenant_id|object_id)\s*=\s*"[a-f0-9]{8}-' "$FILE_PATH" 2>/dev/null || true)
  if [[ -n "$HARDCODED" ]]; then
    WARNINGS="$WARNINGS CRITICAL: Hardcoded Azure IDs detected! Use data sources (data.azurerm_client_config.current) or variables instead. Found: $HARDCODED"
  fi

  # 3. Check for missing variable descriptions
  MISSING_DESC=$(awk '/^variable\s+"/{name=$2; has_desc=0} /description\s*=/{has_desc=1} /^\}/{if(!has_desc && name) print "variable " name " missing description"; name=""}' "$FILE_PATH" 2>/dev/null || true)
  if [[ -n "$MISSING_DESC" ]]; then
    WARNINGS="$WARNINGS WARNING: Variables without descriptions found: $MISSING_DESC"
  fi

  # 4. Check for hardcoded locations
  HARDCODED_LOC=$(grep -nE 'location\s*=\s*"(UK South|East US|West Europe)' "$FILE_PATH" 2>/dev/null || true)
  if [[ -n "$HARDCODED_LOC" ]]; then
    WARNINGS="$WARNINGS WARNING: Hardcoded location found. Use var.location instead. Found: $HARDCODED_LOC"
  fi

  # 5. Check for missing sensitive markers on outputs with secret-like names
  SENSITIVE_OUTPUTS=$(grep -nE 'output\s+".*(_password|_secret|_key|_token|_connection_string)' "$FILE_PATH" 2>/dev/null || true)
  if [[ -n "$SENSITIVE_OUTPUTS" ]]; then
    HAS_SENSITIVE=$(grep -c 'sensitive\s*=\s*true' "$FILE_PATH" 2>/dev/null || echo "0")
    if [[ "$HAS_SENSITIVE" == "0" ]]; then
      WARNINGS="$WARNINGS WARNING: Outputs with sensitive names found but no 'sensitive = true' marker: $SENSITIVE_OUTPUTS"
    fi
  fi
fi

# ─── GitHub Actions YAML (.yml/.yaml in .github/) ───
if [[ ("$EXT" == "yml" || "$EXT" == "yaml") && "$FILE_PATH" == *".github/"* ]]; then
  # 1. Basic YAML syntax validation (try yq first, then python3 with PyYAML)
  YAML_VALIDATED=false
  if command -v yq &> /dev/null; then
    YAML_CHECK=$(yq '.' "$FILE_PATH" > /dev/null 2>&1) || YAML_CHECK="YAML syntax error in $FILE_PATH"
    if [[ -n "$YAML_CHECK" ]]; then
      WARNINGS="$WARNINGS CRITICAL: $YAML_CHECK"
    fi
    YAML_VALIDATED=true
  fi
  if [[ "$YAML_VALIDATED" == "false" ]] && command -v python3 &> /dev/null; then
    YAML_CHECK=$(python3 -c "
import sys
try:
    import yaml
    with open('$FILE_PATH', 'r') as f:
        yaml.safe_load(f)
except ImportError:
    pass  # PyYAML not installed, skip
except yaml.YAMLError as e:
    print(f'YAML syntax error: {e}')
" 2>&1) || true
    if [[ -n "$YAML_CHECK" ]]; then
      WARNINGS="$WARNINGS CRITICAL: $YAML_CHECK"
    fi
  fi

  # 2. Check for unpinned actions (should use SHA, not @v4 or @main)
  UNPINNED=$(grep -nE 'uses:\s+[^#]+@(v[0-9]+|main|master|latest)\s*$' "$FILE_PATH" 2>/dev/null || true)
  if [[ -n "$UNPINNED" ]]; then
    WARNINGS="$WARNINGS WARNING: Unpinned GitHub Actions detected (supply chain risk). Pin to commit SHA with version comment. Found: $UNPINNED"
  fi

  # 3. Check for secrets being echoed
  LEAKED_SECRETS=$(grep -nE 'echo.*\$\{\{\s*secrets\.' "$FILE_PATH" 2>/dev/null || true)
  if [[ -n "$LEAKED_SECRETS" ]]; then
    WARNINGS="$WARNINGS CRITICAL: Secrets may be leaked to logs! Never echo secrets. Found: $LEAKED_SECRETS"
  fi

  # 4. Check for silent failures
  SILENT_FAILURES=$(grep -nE '(continue-on-error:\s*true|\|\|\s*true|\|\|\s*exit\s*0)' "$FILE_PATH" 2>/dev/null || true)
  if [[ -n "$SILENT_FAILURES" ]]; then
    WARNINGS="$WARNINGS WARNING: Silent failure patterns detected. Ensure errors are handled intentionally. Found: $SILENT_FAILURES"
  fi

  # 5. Check for missing concurrency on deploy workflows
  if grep -q 'deploy' "$FILE_PATH" 2>/dev/null; then
    if ! grep -q 'concurrency:' "$FILE_PATH" 2>/dev/null; then
      WARNINGS="$WARNINGS WARNING: Deploy workflow without concurrency controls. Add concurrency group to prevent race conditions."
    fi
  fi
fi

# Output warnings as additional context for Claude
if [[ -n "$WARNINGS" ]]; then
  # Escape for JSON
  ESCAPED_WARNINGS=$(echo "$WARNINGS" | sed 's/"/\\"/g' | tr '\n' ' ')
  echo "{\"additionalContext\": \"Infrastructure validation warnings:$ESCAPED_WARNINGS Please fix these issues.\"}"
fi

exit 0
