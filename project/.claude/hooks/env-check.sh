#!/bin/bash

# Combined environment check: Node.js, Docker, dependencies, git identity
# SessionStart hook - replaces check-node-version.sh, docker-health-check.sh, check-git-identity.sh

set -e

cd "$CLAUDE_PROJECT_DIR" || exit 0

# --- Node.js version check ---
REQUIRED_MAJOR=22
HAS_ERROR=0

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
fi

CURRENT_VERSION=$(node --version 2>/dev/null || echo "none")
NODE_STATUS=""

if [[ "$CURRENT_VERSION" == "none" ]]; then
    NODE_STATUS="NOT INSTALLED — run: nvm install 22 && nvm use 22"
    HAS_ERROR=1
else
    CURRENT_MAJOR=$(echo "$CURRENT_VERSION" | sed 's/v//' | cut -d'.' -f1)
    if [[ "$CURRENT_MAJOR" != "$REQUIRED_MAJOR" ]]; then
        NODE_STATUS="$CURRENT_VERSION (WRONG — need v${REQUIRED_MAJOR}.x)"
        HAS_ERROR=1
        if command -v nvm &>/dev/null; then
            if nvm use $REQUIRED_MAJOR &>/dev/null; then
                CURRENT_VERSION=$(node --version)
                NODE_STATUS="Switched to $CURRENT_VERSION"
                nvm alias default $REQUIRED_MAJOR &>/dev/null
                HAS_ERROR=0
            else
                NODE_STATUS="$NODE_STATUS | Fix: nvm install 22 && nvm alias default 22"
            fi
        fi
    else
        NODE_STATUS="$CURRENT_VERSION"
    fi
fi

# --- Docker check ---
DOCKER_STATUS=""
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        DOCKER_STATUS="running"
        if [[ -f "docker-compose.yml" || -f "docker-compose.yaml" || -f "compose.yml" ]]; then
            RUNNING_CONTAINERS=$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$RUNNING_CONTAINERS" -gt 0 ]]; then
                DOCKER_STATUS="$DOCKER_STATUS ($RUNNING_CONTAINERS containers)"
            else
                DOCKER_STATUS="$DOCKER_STATUS (no containers — hint: docker compose up -d)"
                HAS_ERROR=1
            fi
        fi
    else
        DOCKER_STATUS="not running"
        HAS_ERROR=1
    fi
else
    DOCKER_STATUS="not installed"
fi

# --- Dependencies check ---
DEPS_STATUS=""
if [[ -d "node_modules" ]]; then
    DEPS_STATUS="OK"
else
    DEPS_STATUS="NOT INSTALLED — run: npm install"
    HAS_ERROR=1
fi

# --- Git identity check ---
GIT_NAME=$(git config user.name 2>/dev/null || true)
GIT_EMAIL=$(git config user.email 2>/dev/null || true)
GIT_ISSUE=""

if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]]; then
    HAS_ERROR=1
    [[ -z "$GIT_NAME" ]] && GIT_ISSUE="${GIT_ISSUE}Missing name: git config user.name \"Your Name\" | "
    [[ -z "$GIT_EMAIL" ]] && GIT_ISSUE="${GIT_ISSUE}Missing email: git config user.email \"your@email.com\""
fi

# --- Output ---
if [[ $HAS_ERROR -eq 0 ]]; then
    echo "Dev env: Node $NODE_STATUS | Docker: $DOCKER_STATUS | Deps: $DEPS_STATUS"
else
    echo "=== Dev Environment Status ==="
    echo "Node.js: $NODE_STATUS"
    echo "Docker: $DOCKER_STATUS"
    echo "Dependencies: $DEPS_STATUS"
    if [[ -n "$GIT_ISSUE" ]]; then
        echo "Git Identity: MISSING"
        echo "  $GIT_ISSUE"
    fi
    echo "=============================="
fi

exit 0
