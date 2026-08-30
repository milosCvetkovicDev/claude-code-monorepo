---
name: feedback_lighten_decision_load_on_infra
description: "On dense infra/activation decision dumps the decision-load and jargon density get too high — lead plain-language, make the calls, offer a park-it off-ramp."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00000000-0000-0000-0000-000000000011
---

2026-06-04, during CNPG per-BC data-tier **activation planning**: after an 11-expert board + a stack of P0 "decider calls" (schema/role reconciliation, backups, Pooler sizing, NetworkPolicy, P3), the operator asked for a recommendation on every item rather than a menu, and chose **"go with your recommendations."**

**Why:** the activation work got very deep (CNPG Poolers, RLS/SET LOCAL, WAL/Barman backups, schema/role layout). Presenting each as a decider-call buried the signal. The operator drove the whole epic end-to-end — the problem was decision-LOAD + jargon density on activation minutiae, not the material itself.

**How to apply:** For deeply technical infra/activation decisions —
- Lead with a **plain-language one-paragraph reframe** (what this even is) and an explicit **"nothing is urgent / nothing is deployed"** reassurance.
- **Make the recommendation for each** item; only escalate the few that need genuine human judgment (cost, risk tolerance, who's available/staffing). Don't hand over an expert-framed menu.
- Always offer a low-pressure **"park it"** off-ramp.
- Keep responses **short** when the decision-load is high; no walls of jargon.

Contrast: in hands-on engineering/PM work the operator is very directive — this lesson is specific to dense infra-activation decision dumps. Related: [[finance-stakeholder-communication]] (Current→Expected, max 3 options, number the impact). See [[platform-cnpg-data-tier-poc-gated]].
