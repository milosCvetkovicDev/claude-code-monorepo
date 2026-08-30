#!/bin/bash
# Hook: Validate configuration files before Bash execution
# Catches missing/misnamed env vars, secrets, and credentials early

set -euo pipefail

# Extract the Bash command from stdin
BASH_COMMAND=$(cat)

# Skip validation for safe/read-only commands
if [[ "$BASH_COMMAND" =~ ^(ls|pwd|echo|cat|grep|find|which|git\ status|git\ log|git\ diff|git\ branch|npm\ test|npx\ nx\ test) ]]; then
    exit 0
fi

# Check for script execution
if [[ "$BASH_COMMAND" =~ (npm\ run|npx|node|bun|deno|python|bash\ -c|sh\ -c|\./.*\.sh|\./.*\.ts) ]]; then
    # Look for common configuration files
    CONFIG_FILES=()

    if [[ -f ".env" ]]; then
        CONFIG_FILES+=(".env")
    fi

    if [[ -f ".env.local" ]]; then
        CONFIG_FILES+=(".env.local")
    fi

    if [[ -f "apps/legacy-api/.env" ]]; then
        CONFIG_FILES+=("apps/legacy-api/.env")
    fi

    if [[ -f "apps/domain-api/.env" ]]; then
        CONFIG_FILES+=("apps/domain-api/.env")
    fi

    # Warn if no config files found for script execution
    if [[ ${#CONFIG_FILES[@]} -eq 0 ]]; then
        echo "⚠️  Warning: Running script but no .env files found"
        echo "   Command: $BASH_COMMAND"
        echo "   Consider checking configuration before execution"
    fi

    # Check for common config issues
    if [[ ${#CONFIG_FILES[@]} -gt 0 ]]; then
        # Look for placeholder values that might not be set
        for file in "${CONFIG_FILES[@]}"; do
            if grep -qi "placeholder\|changeme\|todo\|fixme\|<.*>" "$file" 2>/dev/null; then
                echo "⚠️  Warning: Found placeholder values in $file"
                echo "   Review configuration before running scripts"
            fi
        done
    fi
fi

exit 0
