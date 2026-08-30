---
name: systematic-debugging
description: 'Reproduce, isolate, fix, and guard against bugs using systematic debugging. Project-level enhancements to the base debugging skill from superpowers plugin.'
---

# Systematic Debugging — Project Enhancements

This file extends the base debugging skill from the superpowers plugin. See the plugin version for the core reproduce-isolate-fix-guard workflow.

## Anti-Rationalization Table

| If you're thinking...                   | Remember...                                                                                                  |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| "I think I know what the bug is"        | Intuition is a starting point, not a conclusion. Reproduce first, then verify your hypothesis with evidence. |
| "Let me just try a quick fix"           | Shotgun debugging wastes more time than it saves. Isolate the root cause first.                              |
| "It works on my machine"                | Production has different data, config, and concurrency. Reproduce in the closest environment to production.  |
| "The error message tells me everything" | Error messages tell you the symptom, not the cause. Trace the execution path to find where it diverges.      |

## Stop-the-Line Protocol

When a test fails during feature work:

1. **STOP** all feature implementation immediately
2. **Investigate** the failure — is it related to your change or pre-existing?
3. **Fix** the test failure before continuing any other work
4. **Add a regression guard** — write a test that specifically catches this failure mode
5. **Only then** resume feature work

Never push with known test failures. Never skip a failing test with `.skip`.
