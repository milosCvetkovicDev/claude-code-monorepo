---
name: erp-oauth-token-reauth
description: "Diagnose + fix recurring prod P1 erp-token-failure-alert (dead ERP OAuth refresh-token family / invalid_grant) via manual re-auth, and how to verify it durably"
metadata:
  node_type: memory
  type: reference
  originSessionId: 00000000-0000-0000-0000-000000000070
---

Recurring P1 `prod-acme-erp-token-failure-alert` (+ `-recovery-failure-alert`) = the prod ERP OAuth **refresh-token family is dead**: `POST id.erp.example/oauth/token` → 403 `invalid_grant "Unknown or invalid refresh token"`. ERP single-uses/rotates refresh tokens; once the stored token desyncs the whole family is dead → needs a **manual re-auth** (no self-service route). Auto-recovery logs `ERP_TOKEN_RECOVERY_FAILURE … requires_manual_reauth:true` and gives up.

**Re-auth is a manual, out-of-band flow.** A small local OAuth helper app (SvelteKit) opens the provider login; the registered redirect lands on a page that 404s, **but the URL carries `?code=…`** → paste that full URL back into the helper → it exchanges the code, AES-encrypts the result and INSERTs a fresh `Active` row. The deployed copy of the helper is dead, so it runs locally against production configuration supplied through local env (never committed). A human drives the provider login; **the auto-mode classifier blocks the agent from writing to prod directly**, which is the right shape for this: the one step that mints a long-lived credential stays with a person.

**Running it locally needs a temporary prod DB firewall rule** for your public IP (`curl api.ipify.org`), e.g. `az postgres flexible-server firewall-rule create --name <server> -g <rg> --rule-name temp-… --start-ip-address <ip> --end-ip-address <ip>` — and a matching `firewall-rule delete … --yes` the moment you are done. Opening it is the easy half; the discipline is closing it.

**`erp_token` schema:** GLOBAL per-`environmentName` (NO trading-company column), quoted camelCase columns, id=SERIAL, status ∈ Active/Refreshed/Rejected/Invalid, **INSERT-per-rotation** (id increments each refresh), NO `updatedAt`. ERP issues **8-hour** access tokens; cron (`CronJobsService`, every 30 min) refreshes within 60 min of expiry via `refreshWithLock` (pg advisory lock). The helper's crypto-js AES passphrase key **matches** backend `ERP_TOKEN_ENCRYPTION_KEY` (verified: a freshly re-authed row decrypted and rotated cleanly).

**VERIFY re-auth via the DB, NOT App Insights.** Traces are adaptively SAMPLED (overnight lifecycle logs vanish) and `"No ERP token to refresh or recover"` is AMBIGUOUS (healthy Active token >60 min from expiry vs genuinely no token). Ground truth: `SELECT id,status,"createdAt","accessTokenExpiryDate",now() FROM erp_token WHERE "environmentName"='production' ORDER BY id DESC LIMIT 8;` → latest row **Active + future expiry = healthy**; `Invalid` = decrypt/key mismatch; only-old/`Rejected` = still down.

**Worked example:** an entire family went dead `invalid_grant` mid-afternoon with **no deploy that day** — which rules out a slot swap and leaves provider-side revocation or an unlogged container recycle mid-rotation. The manual re-auth HELD: the new token rotated cleanly through the overnight refresh cycles, and that overnight rotation — not the successful exchange — is the evidence that the fix took. Durable fixes (NOT yet done): slot-guard cron startup (`apps/legacy-api/src/server.ts:265` starts cron on ANY slot), atomic rotate-then-persist + unique-Active partial index, dedupe double-logging (console.error + trackTrace → severityLevel 3 & 2), and collapse the 2 crit alerts × 2 action groups × push+email notification storm. See [[erp-sync]], [[deployment-gotchas]].
