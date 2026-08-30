---
name: use-subagents-for-checks
description: All checks, investigations, and analysis must be delegated to subagents rather than performed in the main thread
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000043
---
Always dispatch a subagent (Agent tool) for any check, investigation, or analysis task — do not perform these directly in the main thread.

**Why:** Keeps the main conversation context clean and focused on decisions/actions. Raw logs, grep output, curl responses, file contents from investigation bloat context and crowd out the user's actual workflow. Subagents return a concise summary while absorbing the noise.

**How to apply:**
- Checking status of anything (deployments, services, health endpoints, DB, Azure resources) → subagent
- Investigating a bug or incident → subagent
- Analyzing code, logs, or errors → subagent (code-analyzer, file-analyzer, or Explore)
- Tracing code paths, finding definitions across the codebase → subagent (Explore)
- Reading large files or multiple files to answer a question → subagent
- Running diagnostic commands (curl, az, kubectl, gh) → subagent
- Direct tool calls in main thread are OK only for: executing a user-approved action, single targeted Read when user cites the exact file, committing/pushing when explicitly requested
