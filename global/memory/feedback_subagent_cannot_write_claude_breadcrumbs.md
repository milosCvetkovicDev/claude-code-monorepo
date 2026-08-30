---
name: feedback_subagent_cannot_write_claude_breadcrumbs
description: "Isolation-worktree subagents CANNOT do source-driven-dev-gated framework edits (own real .claude, can't write the breadcrumb) — do those edits in the main session"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000035
---

The `source-driven-dev.sh` PreToolUse hook blocks Edit/Write to any file importing a detected framework (nestjs, mikroorm, fastify, react, mui, playwright, terraform, helm, argocd) unless a breadcrumb `$CLAUDE_PROJECT_DIR/.claude/.source-driven-dev/<fw>.fetched` exists. **Spawned subagents in an isolation worktree cannot satisfy this, so they cannot do such edits at all** — they hit the hook and (correctly, if briefed with a STOP rule) stall.

**Two independent walls (both verified 2026-05-27 on #956's TF subagent):**
1. **Each isolation worktree has its OWN real `.claude` dir — NOT a symlink to the primary worktree.** (`readlink` on every `.claude/worktrees/agent-*/.claude` → REAL DIR.) So a breadcrumb created in the main repo does NOT propagate into the agent's worktree; `$CLAUDE_PROJECT_DIR` resolves to the worktree, where the breadcrumb is absent → hook blocks.
2. **Subagents can't write under `.claude/`** (Bash/Write/sandbox-disabled all denied), so they can't create the breadcrumb themselves. Subagent Bash can also get broadly denied mid-run.

Doc-fetch fallback is unreliable too: WebFetch's summarizer model was down this session and context7/WebSearch weren't in the toolset.

**Why #957 (a mikroorm-area edit) still passed:** its file `apps/platform/ai-service/src/config/mikro-orm.config.ts` has **no `@mikro-orm/` import string**, so the hook's `grep -q "@mikro-orm/"` never matched — the file was never gated. It was NOT breadcrumb-sharing (there is none). My first version of this note wrongly claimed the `.claude` symlink is shared across worktrees — it is not.

**How to apply:** Do source-driven-dev-gated framework-file edits in the **MAIN session** (which has `.claude` write access + the breadcrumb + Bash); reserve subagents for NON-gated files. Before assuming a file is gated, check it against the detector greps in `.claude/hooks/source-driven-dev.sh` — a file can use a framework's *types* without matching (as #957 showed), and conversely it can FALSE-POSITIVE on an incidental word: editing a terraform-only file (`infra/modules/platform-key-vault-secrets/main.tf`) demanded an `argocd.fetched` breadcrumb merely because the file mentions `argocd` in a comment + a secret name (#956). The detector accumulates ALL matched frameworks, so one file may need several breadcrumbs. Clear a genuine false-positive with a breadcrumb whose body documents why it's incidental. Earn any breadcrumb honestly: when WebFetch is down, verify against installed `node_modules`/in-repo source. Related: [[feedback_subagent_briefs_need_hard_rules]], [[feedback_subagent_no_node_modules_skips_verification]], [[feedback_reproduce_ci_exact_env]].
