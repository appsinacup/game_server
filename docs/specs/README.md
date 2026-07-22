# Design specs

Per-item design specs for the planned phases in [../../ROADMAP.md](../../ROADMAP.md).
Each follows the Phase 0 house format: goal, why, concrete architecture grounded
in the existing codebase, and the full CONTRIBUTING checklist it must satisfy.

Phase 0 (background jobs, object storage) is specced inline in the ROADMAP; it
has shipped.

## Phase 1

- [push.md](push.md) — **Push: server delivery + token storage.** `push_tokens`
  table + `GameServer.Push` fan-out on the Oban `push` queue. FCM + APNs-direct
  behind one behaviour, routed per token, **no push library**.
- [push-godot-client.md](push-godot-client.md) — **Push: Godot client.** The
  client half — Android (FCM plugin) then iOS (native APNs plugin) behind one
  `GamendPush.gd` API; registers against the server's `/me/push-tokens`.
- [chat-moderation.md](chat-moderation.md) — **Chat moderation.** Word filter +
  report queue + mute, enforced in the existing `before_chat_message` pipeline.

## Phase 2

- [economy-inventory.md](economy-inventory.md) — **Economy / inventory.** Generic
  currencies, atomic wallet, append-only idempotent ledger, inventory —
  reintroduces the removed `wallet_ledger` decoupled from payments.
- [cloud-saves.md](cloud-saves.md) — **Cloud saves.** Versioned save-slots on
  Object storage with lock-free optimistic conflict detection.
- [skill-matchmaking.md](skill-matchmaking.md) — **Skill matchmaking.** Rating +
  wait-widening skill bands in the existing pure matcher, with the override hook
  intact.

## Phase 3

- [quests-progression.md](quests-progression.md) — **Quests / progression.** One
  event-driven engine; achievements fold in as a quest kind; rewards pay into the
  economy exactly-once.
- [webhooks-remote-config.md](webhooks-remote-config.md) — **Webhooks + remote
  config.** Signed, retried outbound webhooks on the Oban `webhooks` queue;
  client-read-only live remote config.
- [event-tracking.md](event-tracking.md) — **Event-tracking API.** Batched,
  enriched, auto-pruned `events` capture in Postgres — the base a later
  ClickHouse/PostHog sink swaps into.

## Not specced (parked by the roadmap)

- **ClickHouse / PostHog analytics** ("Later") — gated behind volume; the
  event-tracking schema is kept portable so it's a sink swap. No spec until the
  capture layer proves it's needed.
- **Unity / Unreal SDKs** ("Defer") — the realtime layer is hand-written per SDK
  (the real cost); revisit on demonstrated demand.
