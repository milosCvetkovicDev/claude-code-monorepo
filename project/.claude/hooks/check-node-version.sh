#!/bin/bash
# Check Node.js version and switch to v22 LTS if needed

REQUIRED_MAJOR=22

# Source nvm if available
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
fi

# Get current Node.js version
CURRENT_VERSION=$(node --version 2>/dev/null || echo "none")

if [[ "$CURRENT_VERSION" == "none" ]]; then
    echo "ALERT: Node.js is not installed!"
    echo "Run: nvm install 22 && nvm use 22"
    exit 0
fi

# Extract major version number (e.g., v22.1.0 -> 22)
CURRENT_MAJOR=$(echo "$CURRENT_VERSION" | sed 's/v//' | cut -d'.' -f1)

if [[ "$CURRENT_MAJOR" != "$REQUIRED_MAJOR" ]]; then
    echo ""
    echo "=========================================="
    echo "  NODE.JS VERSION MISMATCH"
    echo "=========================================="
    echo "  Current: $CURRENT_VERSION"
    echo "  Required: v${REQUIRED_MAJOR}.x (LTS)"
    echo ""

    # Try to switch using nvm
    if command -v nvm &>/dev/null; then
        echo "  Switching to Node $REQUIRED_MAJOR..."
        if nvm use $REQUIRED_MAJOR &>/dev/null; then
            NEW_VERSION=$(node --version)
            echo "  Switched to: $NEW_VERSION"
            # Set as default for new shells
            nvm alias default $REQUIRED_MAJOR &>/dev/null
            echo "  Set as nvm default: $REQUIRED_MAJOR"
            echo "=========================================="
            echo ""
        else
            echo "  Auto-switch failed. Run in your terminal:"
            echo "    nvm install 22 && nvm alias default 22"
            echo "=========================================="
            echo ""
        fi
    else
        echo "  Run in your terminal:"
        echo "    nvm use 22 && nvm alias default 22"
        echo ""
        echo "  If Node 22 is not installed:"
        echo "    nvm install 22 && nvm alias default 22"
        echo "=========================================="
        echo ""
    fi
else
    echo "Node.js: $CURRENT_VERSION"
fi
