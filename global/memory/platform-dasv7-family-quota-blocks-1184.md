---
name: platform-dasv7-family-quota-blocks-1184
description: dev-platform Dasv7 family vCPU quota (10) blocks
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000016
---

dev-platform AKS = `development-acme-aks`, RG `development-acme-rg`, **uksouth**, sub
**Microsoft Azure Sponsorship** (`00000000-0000-0000-0000-000000000002`).

**2026-06-10 quota raise (user-authorized, for #1184/[[platform-dev-stabilization-epic]] AD-3):**

- ✅ **Total Regional vCPUs (`cores`) 20 → 30** — `az quota update` self-service, auto-approved.
- ❌ **Standard Dasv7 Family (`StandardDasv7Family`) 10 → 20/30** — both declined with
  `QuotaNotAvailableForResource`. Hard policy/capacity block on the Sponsorship sub, NOT a
  size issue. Dadsv7 also 10, same block. DASv5 family = **0** (grandfathered 8 vCPU in use;
  deleted D4as_v5 pool is unrecreatable). Syntax verified good (identical pattern raised `cores`).
- ❌ **`az support … tickets create`** (Compute-VM cores classification
  `00000000-0000-0000-0000-000000000074` under quota service
  `00000000-0000-0000-0000-000000000075`) → `InvalidSupportPlan`: sub is on the **Free** plan,
  Support API enforces a paid plan. The **Portal** Quotas blade special-cases _quota_ requests
  to skip the plan requirement → it's the ONLY working route. **Both CLI paths exhausted — do
  not retry via `az`.** Tracking issue: **#1224**.

**Why this blocks #1184** (`infra/environments/development-platform/main.tf:225-233`): both system
and user pools pivot to **Standard_D4as_v7** at min=max=2 → 4 nodes × 4 vCPU = **16 vCPU, all
Dasv7 family**. Steady-state 16 **> family cap 10**, so the ratified end-state cannot be applied
until Dasv7 family quota ≥ 16 (≥ 20 for surge="1" rolling-op headroom). Regional cores=30 is now
ample; the **family cap is the sole remaining blocker**.

**Resolution options (user decision):**

1. **Portal Quotas blade → "Request increase" on Standard Dasv7 Family → 20** (uksouth). Often
   auto-approves in minutes for small bumps; the one step I cannot do via CLI. ⚠️ tension with the
   "no Azure support tickets" rule — a Quotas-blade request files a `Microsoft.Support/quota`
   ticket under the hood; flagged for the user, not unilaterally decided.
2. Mixed-family interim: keep system on grandfathered D4as_v5 (8 vCPU, family-limit 0 but extant),
   user pool → D4as_v7 (8 vCPU, fits Dasv7=10). Deviates from ratified "both pools v7"; fragile
   (DASv5 unrecreatable if deleted).
3. Park #1184 apply until Dasv7 quota lands (recommended — PR #1220 stays draft; no cluster touch).

**2026-06-11 — Azure DECLINED (soft):** the Portal/support request (#1224, handled by the assigned MS engineer)
came back **"backlogged, no ETA — reviewed again when additional capacity becomes available."** On a
uksouth Sponsorship sub this is a capacity refusal, treat as a NO. Reply options offered: (1)
bi-monthly status, (2) update-only-when-fulfilled, (3) archive — **recommended (1)** to hold queue
position at zero cost.

**2026-06-14 — alt-family pivot IS viable (CORRECTS the 06-11 "no escape" claim):** fresh
`az vm list-usage -l uksouth` shows the family landscape CHANGED — **dozens of GA families now carry a
10-vCPU cap** (Dasv4, Ddsv7, Dsv7, Dadsv7, Easv7, Fasv7, Ddsv6, Dsv6, EBSv5/EBDSv5, NC=12…),
**Total Regional = 10/30 (20 free)**, **Dasv7 = 8 free** (2 used by arcpool D2as_v7), **DASv5 = limit 0**
(8 grandfathered, cannot grow). So the HA floor can be built WITHOUT the rejected Dasv7 raise by
spreading pools across ≥2 ten-cap families inside the 20-vCPU regional headroom. The 06-11 "EVERY
non-grandfathered family = limit 0" conclusion is STALE — always verify live before relying on it.

**#1184 RE-SCOPE SHIPPED to PR #1220 (2026-06-14, draft) — E-SERIES, NOT D4.** Two 5-expert panels
corrected the design twice: (1) D2 (8 GiB) FAILS aggregate-memory failover (live user node = **2,885m /
9,820 MiB**; a D2 has ~6.5 GiB allocatable) → use **memory-optimized E-series (2 vCPU / 16 GiB)** at the
SAME 10-cap vCPU footprint; (2) the family cap is vCPU-denominated so E2 RAM is "free". **Final design**
(node-level HA, non-zonal): system **2× Standard_E2as_v6** (Eav6 0/10), user **4× Standard_E2ads_v6**
(Eadv6 0/10), arc unchanged. 4-node user pool survives drain-1 (3 survivors: 4,410m / 33,141 MiB vs
projected ~3,500m / ~11,200 MiB; CPU margin tight ~910m). **AD-3b posture:** 4+1 surge = exactly 10/10
Eadv6 (zero margin) → BOTH `automatic_upgrade_channel="none"` AND `node_os_upgrade_channel="None"`
(the 2nd surge path AD-3 missed); operator-scheduled upgrades + 14-day patch SLA. User pool `vm_size`
is unconditionally ForceNew (no `temporary_name_for_rotation` on node_pool resource) → **blue/green
mandatory** (temp E2ds_v6 user2 pool; rollback only before the TF apply — DASv5 limit=0 unrecreatable).

**ADR = standalone [[]] `docs/adr/0055-platform-dev-aks-node-pool-ha-topology.md`** (NOT a 0043 amendment —
0043 is vendor-selection; v1 panel hallucinated a collision, v2 found the REAL one: main holds 0049–0052,
chore/platform-identity 0053–0054 → **0055** is first free). Supersedes epic **AD-3** + ADR-0043 Amendment 2.

**Shipped on `feat/platform-stab-1184-d4as-v7-node-pool-pivot` (commit `be910366`):** TF module (both
channel vars + lifecycle ignore_changes=[upgrade_settings], `default_node_pool[0].…` form validates) +
dev override + cordon-drain drill (SKU-agnostic, S6→Eadv6 cap max_count≤4, no `--force`) + capacity helm
test rename + ADR-0055 + README + infra-arch forward-ref. **Verified:** `terraform validate` ✓, drill
7/7 ✓, helm-unittest 3/3 ✓. PR #1220 retitled "E-series multi-family HA floor", DRAFT.

**Branch-split GOTCHA:** epic governance files (`architecture.md` AD-3/AD-3b, epic.md, 1184.md, PRD,
stabilization HTMLs) are NOT on the #1184 branch — they live only on `chore/platform-microservices-databases`
→ AD-3/AD-3b rewrite is a SEPARATE chore-branch PM update. The `0043-amendment` Superseded-by note +
README 0049–0054 reconcile are **rebase-time** tasks (#1184 branch is 28 behind main). Issue #1184 title
still says D4as_v7.

**Apply is operator-run/gated** (var wall + blue/green). **Support reply: Option 1 (bi-monthly, keep
SR `<SUPPORT-REQUEST-ID>` warm)** — non-blocking; revert to managed channels if the Eadv6 cap is ever raised.
Real prod fix still = Platform's own future prod sub, per [[no-platform-to-prod]].
