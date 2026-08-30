---
name: session-learnings
description: "Extract session learnings to global memory — compact, shared across all acme instances. Use at the end of a session to capture reusable knowledge (gotchas, patterns, fixes). Do not use for documenting features (use add-docs) or updating CLAUDE.md files directly."
---

# Session Learnings

Scan conversation for issues, gotchas, solutions, and patterns worth preserving. Be highly selective — only document what prevents future mistakes or saves real time.

## Process

1. **Scan** conversation for: errors hit, root causes found, non-obvious fixes, codebase gotchas, patterns learned
2. **Filter** ruthlessly — skip anything obvious or already documented
3. **Present** a brief numbered list: `[title] → [destination file] — [1-line summary]`
4. **After user approval**, read each target file and append/update. Keep entries terse (1-2 lines each)

## Destination Decision Tree

- Codebase pattern/gotcha → relevant `CLAUDE.md` (root or app-specific)
- Operational procedure → `docs/runbooks/`
- Architectural decision → `docs/adr/`
- Incident resolution → `docs/runbooks/incidents/`
- Workflow/tooling/cross-session knowledge → **`~/.claude/memory/`** (global, shared across all acme instances)

Memory: update **`~/.claude/memory/MEMORY.md`** index (keep under 200 lines) + topic file if needed. Global memory is shared across all acme worktrees (acme, acme2, acme3, etc.).

## Writing Rules

- One-liner per learning in MEMORY.md index; detail goes in linked topic files
- Match existing format/style of target file
- No duplication — check before adding
- Prefer updating existing entries over creating new ones

Now analyze the conversation above and extract learnings.
