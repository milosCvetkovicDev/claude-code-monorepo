# Upstream provenance

The `/pm:*` command set in this directory, the companion scripts in `global/scripts/pm/`,
and six of the rules in `global/rules/` derive from
**[automazeio/ccpm](https://github.com/automazeio/ccpm)** (MIT, Copyright (c) 2025 Ran Aroussi).
The upstream license is preserved here as `LICENSE`.

Commands added on top of the upstream set (not from CCPM):

- `arch-create` — architecture pass with independent judge agents
- `tests-generate` — RED acceptance tests that become the verifiable stop condition
- `readiness-check` — an independent checker gate before epic sync
- `prod-verify` — verification against real production evidence
- `epic-start-worktree` — parallel execution in isolated git worktrees
- `milestone-init`, `test-reference-update`

CCPM also expects the `gh` extension
**[yahsan2/gh-sub-issue](https://github.com/yahsan2/gh-sub-issue)** for real parent/child
issue links; `scripts/pm/init.sh` installs it.
