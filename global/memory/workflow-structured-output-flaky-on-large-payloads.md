---
name: workflow-structured-output-flaky-on-large-payloads
description: 'Workflow agent({schema}) hits "StructuredOutput retry cap (5) exceeded" ~half the time on large-payload readers/implementers; use plain-text returns instead'
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000017
---

Workflow `agent(prompt, {schema})` forces the subagent to emit a validated JSON tool call. On **large payloads** (exhaustive readers over 1500–2200-line prototype files; implementation agents reporting many files) this fails **intermittently (~40–50%)** with `StructuredOutput retry cap (5) exceeded — 5 failed calls with no valid output`. Seen 3×: the #1446 kit impl agent, and 4-of-8 readers in the #1447/#1448/#1449/#1614 understand pass (one even returned a junk stub `{"summary":"test","findings":[{"topic":"a"}]}` that _passed_ the schema — worse than failing).

**Why:** agents did the real WORK (files exist, gates pass) but couldn't serialise the huge structured report; the schema retry is the failure point, not the task.

**Rules:**

1. For readers/reporters with big outputs, DROP the schema — `agent(prompt)` returns the final TEXT reliably. Ask for "a thorough MARKDOWN report" and parse loosely, or just have downstream agents Read the saved file.
2. Keep schemas ONLY for small/bounded outputs (a verdict {verdict,reason}; a short findings list). Never for exhaustive design specs.
3. NEVER trust a workflow agent's structured RETURN as proof of work — verify the worktree with git/typecheck/test (the impl agents returned junk reports but good code). See [[platform-trading-frontend-epic]] (grep-treats-DataTable.tsx-as-binary too).
4. Recover: re-run only the failed readers as plain-text (resumeFromRunId replays cached successes if opts unchanged; changing opts, e.g. removing schema, re-runs them fresh).
