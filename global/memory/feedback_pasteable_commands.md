---
name: feedback_pasteable_commands
description: "When handing the user commands to run, make them fully paste-able — no placeholders to edit."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000030
---

When generating commands for the user to execute, make them **fully copy-paste-able with zero placeholders** they have to fill in (no `<rg-name>`, `<subscription>`, `<path>`, etc.).

**Why:** the user runs them verbatim; a `<placeholder>` makes the shell error (`no such file or directory`, redirect parse) and wastes a round-trip. They told me directly: "when you generate commands make it pasteble, not i need to change it."

**How to apply:** resolve every value first (look up the real resource group / subscription id / zone / path via `az`, `kubectl`, `git`, etc.), then bake the concrete values into the command. If a value genuinely can't be determined, say so explicitly and give the one lookup command to find it — don't leave a placeholder inside the action command. Related: [[platform-frontend-same-origin-deploy]].
