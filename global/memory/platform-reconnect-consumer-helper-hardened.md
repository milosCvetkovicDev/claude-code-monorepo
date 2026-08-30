---
name: platform-reconnect-consumer-helper-hardened
description: setupRabbitConsumerWithReconnect (@acme/event-bus) hardened to notification-service parity; RMQ consumers adopting it MUST capture the handle + implement OnModuleDestroy → stop().
metadata:
  node_type: memory
  type: project
  originSessionId: 00000000-0000-0000-0000-000000000009
---

`setupRabbitConsumerWithReconnect` (`libs/platform/event-bus/src/lib/setup-rabbit-consumer.ts`)
was materially weaker than notification-service's own inline reconnect loop. When
user-service became the FIRST prod adopter (first-admin invite consumer, #1589), the
review found it re-introduced the exact #1589 silent-stop. Hardened in PR #1755
(`cf4c224`) to parity:

- **reset the attempt counter after every successful setup** — the old cumulative
  counter crossed `DEFAULT_MAX_RECONNECT_ATTEMPTS` (100) over a long-lived pod's
  isolated blips and then PERMANENTLY stopped consuming (silent #1589 regression).
- **recovery from `'close'` ONLY; `'error'` is log-only** — amqplib fires error→close
  on a channel exception; both scheduling a reconnect gave two chains → leaked channel
  - double consumer. Plus a `reconnectScheduled` dedup guard.
- **teardown the old channel** (`removeAllListeners` + `close`) before each reconnect
  (no channel/listener leak).
- **returns a `RabbitReconnectHandle { stop() }`**; `stop()` sets `destroyed`, clears
  the timer, tears down the live channel.

**How to apply — any RMQ consumer using this helper MUST:**

1. `this.handle = await setupRabbitConsumerWithReconnect(() => conn.createConfirmChannel(), cfg, handler)`
   (pass a channel FACTORY, not a fixed channel — that's what enables reconnect).
2. `implements OnModuleDestroy` → `async onModuleDestroy() { await this.handle?.stop() }`
   — else the backoff loop keeps opening channels on a closing connection at shutdown (#982).
3. Test with FAKE timers (`vi.useFakeTimers()` + `advanceTimersByTimeAsync`) — the Platform
   sleep-guard lint forbids real-timer `new Promise(setTimeout)` in unit specs.

notification-service keeps its OWN inline loop (3-consumer channel + handlerLock) — it
does NOT use this helper. Related: [[platform-outbox-relay-audit-feed-leaks-secrets]],
[[platform-tenant-provisioning-epic]], [[feedback_platform_auth_user_service_test_flaky]].
