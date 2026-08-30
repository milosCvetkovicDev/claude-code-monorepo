---
name: always-use-pm-workflow
description: CRITICAL — always use PM plugin commands to manage issue lifecycle, never do manual GitHub/frontmatter updates
type: feedback
originSessionId: 00000000-0000-0000-0000-000000000049
---
CRITICAL: Always use PM plugin commands (`/pm:*`) to manage the full issue lifecycle. Never manually update GitHub issues, frontmatter status, or epic progress outside the PM workflow.

**Why:** User requires consistent workflow discipline. Manual updates bypass the PM system's tracking, coordination, and state management. The PM commands handle frontmatter, GitHub sync, epic progress, and next-step suggestions as an integrated pipeline.

**How to apply:**
- Starting work: `/pm:issue-analyze` → `/pm:issue-start`
- Closing work: `/pm:issue-close`
- Checking status: `/pm:epic-status`, `/pm:issue-status`
- Syncing: `/pm:issue-sync`, `/pm:epic-sync`
- Never manually `gh issue close`, `gh issue edit`, or hand-edit frontmatter status fields — let the PM commands handle it
- After agents complete work, run the appropriate PM command to finalize
