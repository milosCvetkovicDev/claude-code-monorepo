#!/bin/bash

# Kubernetes manifest validation hook
# Trigger: PostToolUse hook for Write/Edit operations
# Checks K8s YAML files for common issues

set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only check yaml/yml files
case "$FILE_PATH" in
  *.yaml|*.yml) ;;
  *) exit 0 ;;
esac

# Skip if file doesn't exist
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Check if this is a K8s manifest (has apiVersion and kind)
if ! grep -q "apiVersion:" "$FILE_PATH" 2>/dev/null || ! grep -q "kind:" "$FILE_PATH" 2>/dev/null; then
  exit 0
fi

# Skip Helm templates (they have {{ }} syntax that won't validate)
if grep -q "{{" "$FILE_PATH" 2>/dev/null; then
  exit 0
fi

WARNINGS=""

# Check for hardcoded secrets
if grep -qE "password:|secret:|token:|apiKey:" "$FILE_PATH" 2>/dev/null; then
  if ! grep -qE "secretKeyRef|ExternalSecret" "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}• Possible hardcoded secret — use ExternalSecret CRD (ADR-0020)\n"
  fi
fi

# Check for 'latest' image tag
if grep -q "image:.*:latest" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS}• Using 'latest' image tag — use SHA or semantic version\n"
fi

# Check for missing resource limits on Deployments
KIND=$(grep "kind:" "$FILE_PATH" | head -1 | awk '{print $2}')
if [[ "$KIND" == "Deployment" ]] || [[ "$KIND" == "StatefulSet" ]]; then
  if ! grep -q "resources:" "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}• Missing resource limits on $KIND — all containers must have requests + limits\n"
  fi
fi

# Check for privileged containers
if grep -q "privileged: true" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS}• CRITICAL: privileged container detected — NEVER use privileged: true\n"
fi

# Check for hostNetwork
if grep -q "hostNetwork: true" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS}• CRITICAL: hostNetwork detected — NEVER use hostNetwork: true\n"
fi

# YAML syntax check
if command -v python3 >/dev/null 2>&1; then
  YAML_CHECK=$(python3 -c "import yaml; yaml.safe_load(open('$FILE_PATH'))" 2>&1 || true)
  if echo "$YAML_CHECK" | grep -q "Error\|error"; then
    WARNINGS="${WARNINGS}• YAML syntax error: $(echo "$YAML_CHECK" | head -1)\n"
  fi
fi

if [[ -n "$WARNINGS" ]]; then
  echo "{\"additionalContext\": \"⚠️ K8s manifest warnings in $(basename $FILE_PATH):\n${WARNINGS}\"}"
fi

exit 0
