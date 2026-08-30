## Writing Style

- Never append call invitation phrases (e.g. "Happy to go through these on a call") to emails or messages.

## Development Workflow

Maximum Confidence: Requirements → Tests (RED) → Sync → Implement (GREEN) → Review → Merge → Verify → Cleanup.

Sequence: `prd-new` → `prd-parse` → [`arch-create`] → `epic-decompose` → `tests-generate` → [`readiness-check`] → `epic-sync` → `issue-start` → `issue-close` → `epic-review` → `epic-merge` → `prod-verify` → `epic-close`

When user runs `/pm:*`, check `~/.claude/rules/reference-loading.md` for which reference file to read. When a PM command completes, suggest the next step briefly.

**Loop engineering** weaves through the ceremony: a system prompts the agents, not you — _maker ≠ checker_ (the agent that does the work never grades it) and _verifiable stop conditions_ (machine-checkable, never a vibe). RED tests from `tests-generate` are the stop condition; a separate checker confirms at `issue-close`/`epic-review`/`prod-verify`; leftovers route to the triage inbox at `epic-close`. Discovery loop = `/triage`; verifiable-finish loop = `verify-loop`. See `~/.claude/references/workflow/loop-engineering.md` (routed automatically) and a project's `docs/loop-engineering.md`.
