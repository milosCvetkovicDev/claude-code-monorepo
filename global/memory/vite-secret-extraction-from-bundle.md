---
name: Read live VITE_* env secret values from the deployed legacy-web bundle
description: GitHub Actions environment secrets are write-only via API; for VITE_* values you can extract the current value from the deployed Vite bundle since they are baked into static JS at build time
type: reference
originSessionId: 00000000-0000-0000-0000-000000000066
---
GitHub Actions environment secrets cannot be read back via API — `gh secret list` only shows existence and update timestamp, not values. This creates a chicken-and-egg problem when planning edits to a list-valued secret such as `VITE_<FEATURE>_ALLOWED_USER_IDS` (e.g. "drop one entry without nuking the others"): you need the current list to compute the new list.

For `VITE_*` env vars specifically, this is solvable because Vite bakes them into the static JS bundle at build time. The deployed bundle is publicly readable (it's served to every browser).

## Recipe

```bash
# Find the SWA hostname (prod)
az staticwebapp list -g prod-acme-rg --query '[].defaultHostname' -o tsv
# → acme-legacy-web-prod.azurestaticapps.net

# Pull the current main JS bundle and grep for the secret value
SWA_URL="https://acme-legacy-web-prod.azurestaticapps.net"
BUNDLE=$(curl -s "$SWA_URL/" | grep -oE 'assets/[a-zA-Z0-9_-]+\.js' | sort -u | head -1)
curl -s "$SWA_URL/$BUNDLE" -o /tmp/bundle.js

# Extract any baked-in CSV-of-GUIDs (typical shape for *_USER_IDS lists)
grep -oE '"[a-f0-9-]{36}(,[a-f0-9-]{36})*"' /tmp/bundle.js | head -20

# Or extract any baked-in connection string / arbitrary string secret
grep -oE 'InstrumentationKey=[a-f0-9-]+' /tmp/bundle.js
grep -oE 'IngestionEndpoint=[^"]+' /tmp/bundle.js
```

Cross-reference resulting GUIDs against the prod DB to identify users — the names in any related memory file may be stale.

## Caveats

- Only works for `VITE_*` (build-time injected). Runtime secrets accessed via `process.env` server-side won't be in the bundle — use Key Vault for those.
- Bundle filename rotates each deploy (cache-bust hash). Always read the current `index.html` for the active filename.
- The same is true for any build-time-baked SPA framework — Next.js `NEXT_PUBLIC_*`, CRA `REACT_APP_*`, Vue `VUE_APP_*`. Same technique applies.
- This is not a "secret-leaking" trick — these values are already public by virtue of being shipped to browsers. The technique just makes them easier to enumerate from your terminal.

## Why this saves time

Before learning this: ask the user "what's the current value?", they have to look it up in their notes/Key Vault/old PRs, paste it back. Slow and error-prone.

After: extract directly, compute the diff, set the new value. One round trip.
