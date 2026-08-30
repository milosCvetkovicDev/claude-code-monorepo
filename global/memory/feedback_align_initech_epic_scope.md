---
name: feedback_align_initech_epic_scope
description: Keep work anchored to the current epic's scope
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000010
---

Always keep work anchored to the current epic's (#986) scope and goal — the deliverable the epic exists to produce, not the plumbing discovered on the way to it.

**Why:** During a hardening + dry-run cutover (2026-06-02), the work drifted into credential/permissions/tooling plumbing (Key Vault reference resolution, `az` reads, the auto-mode classifier allow-rules, tsx→ts-node). All necessary to *run* the dry-run, but it consumed long back-and-forth and pulled focus off the epic deliverable other people were already waiting on.

**How to apply:** Before each step, ask "does this directly advance epic #986?" The in-scope critical path is the epic's own task list, in the order it already defines. Treat tooling/credential snags as the *minimum* fix needed to unblock that path — fix and move on, don't turn them into side projects. Don't expand scope beyond the epic's tasks without checking first.
