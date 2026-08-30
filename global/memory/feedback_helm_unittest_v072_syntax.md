---
name: feedback-helm-unittest-v072-syntax
description: Gotchas in helm-unittest v0.7.2 syntax — assertions that LOOK correct but error or trivially pass. Discovered 2026-05-20 in PR
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000008
---

helm-unittest v0.7.2 (the version pinned in `charts/platform-base/` and `charts/arc/tests/`) has 4 syntax constraints that produce silent-pass or invocation-error failures. **Why:** the syntax errors don't fail loudly — some configurations make assertions trivially-true regardless of template content, defeating the whole point of unit tests. Caught by `kubernetes-expert` agent reviewing PR #858 helm-unittest stubs (commits `53f23977` / `17671bd2`).

**How to apply:**

1. **`.length` is NOT a valid path segment.** To count list items, use the `lengthEqual` matcher:
   ```yaml
   # WRONG — produces invocation error at runtime
   - equal: { path: spec.groups[0].rules.length, value: 7 }
   # RIGHT
   - lengthEqual: { path: spec.groups[0].rules, count: 7 }
   ```

2. **`documentSelector.value` must be a SCALAR** (not a list). Drop the selector if only one document is rendered:
   ```yaml
   # WRONG — schema rejection at runtime
   documentSelector:
     path: spec.policyTypes
     value: [Ingress, Egress]
   # RIGHT — use a scalar field or drop the selector
   documentSelector:
     path: kind
     value: NetworkPolicy
   ```

3. **`[*]` wildcards are NOT supported in `documentSelector.path` or in `contains`/`equal` path expressions.** Use a concrete index:
   ```yaml
   # WRONG — matches nothing or errors
   - contains: { path: spec.endpoints[*].port, content: metrics }
   # RIGHT
   - equal: { path: spec.endpoints[0].port, value: metrics }
   ```

4. **`matchRegex path: $` is NOT valid** — there is no `$` root-document path. Anchor to a specific field, or assert against the rendered document via `matchSnapshot`:
   ```yaml
   # WRONG — runtime error
   - matchRegex: { path: $, pattern: "github.com" }
   # RIGHT — anchor to a real field
   - matchRegex: { path: spec.egress, pattern: "github.com" }
   ```

5. **`notExists` + `documentSelector` matching zero documents is VACUOUSLY TRUE.** To assert "no document of kind X exists", use `hasDocuments: count: 0` with a filter:
   ```yaml
   # WRONG — passes when chart emits zero docs (silent false-pass)
   - notExists:
       path: spec.source.repoURL
       documentSelector: { path: kind, value: Application }
   # RIGHT
   - hasDocuments:
       count: 0
       filter: { kind: Application }
   ```

6. **`notExists` on paths that don't exist on the target Kind is VACUOUSLY TRUE.** Example: asserting `notExists path: spec.template.spec.tolerations` on a `ServiceAccount` (which has no `spec.template`) is meaningless. Either pick a real path on the Kind, or use `notMatchRegex` against a parent path that the field could appear under.

When reviewing or writing helm-unittest YAML, run through this checklist. The 5-reviewer board on PR #858 caught 5 of these errors across 7 of the 15 stubs.

Related: [[feedback_cross_poc_red_scaffolds_break_prs]] (other RED-scaffold silent-pass class).
