---
name: verification-before-completion
description: 'Require concrete evidence before claiming a task is complete. Project-level enhancements to the base verification skill from superpowers plugin.'
---

# Verification Before Completion — Project Enhancements

This file extends the base verification skill from the superpowers plugin. See the plugin version for the core verification workflow.

## Anti-Rationalization Table

| If you're thinking...              | Remember...                                                                                          |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------- |
| "It looks right to me"             | Your eyes are not a test suite. Show concrete evidence: test output, API response, build log.        |
| "The tests pass so we're done"     | Passing tests are necessary but not sufficient. Check: manual verification, edge cases, performance. |
| "I checked it locally"             | Local != production. Verify in the target environment or with production-like data.                  |
| "The PR is small so it's low risk" | Small PRs can have outsized impact. A one-line auth change can expose all user data.                 |

## Evidence Requirements

Every completion claim must include concrete artifacts:

| Claim | Required Evidence |
| ------------------- | ------------------------------------------------------------------------------- |
| "Tests pass"        | Paste actual test runner output showing green results |
| "Build succeeds"    | Paste build output with zero errors |
| "Feature works"     | Screenshot, API response body, or terminal output showing the feature in action |
| "No regressions"    | Full test suite output (not just affected tests)                                |
| "Performance is OK" | Benchmark numbers: before vs after with specific metrics |
| "Security is clean" | gitleaks output and npm audit output |

**"Seems fine" is never acceptable.** If you cannot produce the artifact, the claim is unverified.
