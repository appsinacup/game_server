# Chat moderation — word filter, report queue, mute

Design spec for the Phase 1 **Chat moderation** item in
[ROADMAP.md](../../ROADMAP.md). Format and rigor mirror the Phase 0 sections.

Goal: give hosts the three moderation primitives every chat needs — a **word
filter** that runs before a message is stored, a **report queue** players feed
and moderators work, and **mutes** that silence an abuser without banning their
IP. All three are server-authoritative and plug into the chat pipeline that
already exists.

## Why (chat exists; moderation doesn't)

`GameServer.Chat` already carries lobby/group/friend messages with a
`before_chat_message/2` **pipeline hook** and an `after_chat_message/1` hook, and
persists to `chat_messages`. What's missing is any way to stop abuse: today a
plugin *could* hand-roll a filter in `before_chat_message`, but there's no
built-in blocklist, no player-facing report path, and no mute. This item ships
all three as core, enforced in the same pre-persist pipeline so nothing
unmoderated ever hits the database or PubSub.

## The enforcement point — `before_chat_message`

The filter and mute checks run inside the existing `before_chat_message/2`
pipeline (which already returns `{:ok, attrs} | {:error, reason}`), so a rejected
message is never inserted and never broadcast. Core runs its checks first, then
delegates to any plugin hook — a plugin can still veto further but cannot see a
message core already blocked. **Never inside a transaction/lock** (CONTRIBUTING
§Hooks): the checks are pure reads (ETS mute lookup, in-memory word scan) with no
write, so they add no contention.

## 1. Word filter

- **Blocklist** stored in a `chat_filter_words` table (admin-managed) — `word`
  (unique, normalized), `severity` (`"block"` | `"mask"` | `"flag"`),
  `match_mode` (`"exact"` | `"substring"`), timestamps. Loaded into an ETS set at
  boot and kept fresh via PubSub on edit (the `IpBans` hot-path pattern:
  durable table = source of truth, ETS = hot path, PubSub = cluster sync).
- **Normalization** before matching: lower-case, collapse repeated chars
  (`heeeello`→`helo`), strip zero-width/diacritics, map common leetspeak
  (`@→a`, `3→e`, `1→i`). Kept in `GameServer.Chat.Moderation.Normalizer` so the
  admin "test this phrase" tool and the runtime path share one implementation.
- **Actions** by severity: `block` rejects (`{:error, :blocked_content}`);
  `mask` replaces the hit with `***` and lets the (masked) message through;
  `flag` stores it verbatim but sets `metadata["flagged"] = true` and auto-files
  a report for the queue.
- Config caps in `GameServer.Limits`: `max_chat_filter_words`,
  `max_chat_filter_word_len`.

## 2. Report queue

- **`chat_reports`** table: `reporter_id`, `message_id`
  (`references(:chat_messages, on_delete: :nilify_all)` — keep the report if the
  message is deleted), a denormalized `reported_user_id` + `content_snapshot`
  (so the queue survives message deletion), `reason` (string), `status`
  (`"open"` | `"reviewing"` | `"actioned"` | `"dismissed"`), `resolved_by`,
  `resolution_note`, timestamps.
- **Indexes:** partial `index([:status], where: "status = 'open'")` for the
  queue sweep + dashboard counter; `index([:reported_user_id])` for "history for
  this user"; `unique_index([:reporter_id, :message_id])` so a player can't
  spam-report one message.
- **Endpoint** `POST /chat/messages/:id/report {reason}` — auth'd, rate-limited
  via `max_chat_reports_per_user_per_day` (`GameServer.Limits`, same rolling-24h
  pattern as `max_chat_messages_per_day`). Auto-flag from the word filter files a
  report with `reporter_id = nil` (system).
- **Context:** `Chat.report_message/3`, `Chat.list_reports/2` + `count_reports/1`
  (paginated, filter by status/user), `Chat.resolve_report/3` (admin: set status
  + note, optionally mute/delete in one call).

## 3. Mute

- **`chat_mutes`** table: `user_id`, `scope` (`"global"` | `"lobby"` |
  `"group"`), `scope_ref_id` (null for global), `expires_at` (null = permanent),
  `reason`, `muted_by`, timestamps. `unique_index([:user_id, :scope, :scope_ref_id])`;
  partial `index([:user_id], where: "expires_at IS NULL OR expires_at > now()")`
  is not portable, so index `[:user_id]` and filter expiry in the query.
- **Hot path:** an ETS mirror keyed by `user_id` (loaded at boot, PubSub-synced),
  checked in `before_chat_message` — a muted sender (matching scope) is rejected
  with `{:error, :muted}` before persist. Mirrors `IpBans` exactly.
- **Sweep:** a supervised periodic worker deletes expired mutes (like
  `IpBans.delete_expired/0`), added to the host supervision tree **and** the
  starter repo's tree (CONTRIBUTING §Functionality).
- **Context:** `Chat.mute_user/4`, `Chat.unmute_user/2`, `Chat.muted?/2`,
  `Chat.list_mutes/1` + `count_mutes/1`.

## Hooks (all six places, per CONTRIBUTING §Hooks)

Enforcement reuses the existing `before_chat_message`. Two **new observation**
callbacks so plugins can react (auto-escalate, notify moderators, tally strikes):

- **`after_chat_message_reported(report)`**
- **`after_user_muted(mute)`**

Each in all six places: `@callback` + `@optional_callbacks` in `GameServer.Hooks`,
`internal_hooks()` (RPC-blocked), no-op in `Hooks.Default`, SDK mirror
(`@callback`, `@optional_callbacks`, `__using__` default, **and `defoverridable`**),
Server-scripting docs. Both are fire-and-forget after commit (deferred, never in
the insert transaction).

## Limits (`GameServer.Limits`, auto `LIMIT_*`, listed in `@limit_categories`)

`max_chat_filter_words`, `max_chat_filter_word_len`, `max_report_reason` (len),
`max_chat_reports_per_user_per_day`, `max_mute_reason` (len).

## Web / API

- `POST /chat/messages/:id/report {reason}` — player reports (rate-limited).
- Muting and filter-word editing are **server-authoritative** → **no public
  endpoint**; admin API + admin UI only (a plugin mutes via `Chat.mute_user/4`).
- Routes in `router/shared.ex`. Report submission returns 204/202; the message
  content snapshot is taken server-side.

## Admin

- `admin_live/chat_reports.ex` — the queue (paginated, filter by status/user,
  shows names + content snapshot), with one-click **dismiss / delete message /
  mute user** actions that resolve the report atomically.
- `admin_live/chat_mutes.ex` — active mutes, add/remove, scope + expiry.
- `admin_live/chat_filter.ex` — blocklist CRUD + a "test a phrase" box using the
  shared `Normalizer`.
- `/admin` stat card (open reports, active mutes) + routes + nav links +
  `admin_pages_render_test` entries.
- Admin API controllers under `controllers/api/v1/admin/` with **parity** for
  every action above.

## "Update everywhere" — file list

- **CHANGELOG** `[added]` Chat moderation (filter, reports, mute).
- **.env.example** — the new `LIMIT_*` caps.
- **host_public_docs/** — Chat docs page gains a Moderation section; Data Schema
  page gains `chat_filter_words`, `chat_reports`, `chat_mutes`.
- **api_spec.ex** — feature list + the report endpoint.
- **SDK** — regenerated `Chat`/admin stubs; struct stubs for the new schemas;
  hooks mirrored.
- **runtime_introspection.ex** — moderation counts (open reports, active mutes,
  filter size).
- **i18n** — extract/merge + translate 30 locales; clear fuzzies.
- **mix demo.seed** — seed filter words, a few open reports, and a sample mute.

## Deferred / rejected

- **ML / third-party toxicity classifiers: defer.** Ship the deterministic word
  filter first; the `before_chat_message` hook already lets a plugin call out to
  Perspective API etc. without core taking that dependency.
- **Shadow-muting (message visible only to sender): defer.** Adds per-recipient
  delivery filtering to the broadcast path; the `flag` severity + report queue
  cover the same need for v1.
- **Strike/auto-escalation policy: defer.** `after_chat_message_reported` +
  `after_user_muted` give a plugin everything needed to implement strikes
  without baking one policy into core.

## Definition of done (CONTRIBUTING)

- [ ] Migrations for `chat_filter_words` / `chat_reports` / `chat_mutes` apply on
      SQLite **and** `DATABASE_ADAPTER=postgres`; indexes as above.
- [ ] Filter + mute enforced in `before_chat_message` (nothing unmoderated
      persists/broadcasts); expired-mute sweep supervised in both trees.
- [ ] Paginated `list_*`/`count_*`; `Limits` caps in changesets; report
      rate-limit enforced.
- [ ] Hooks `after_chat_message_reported` / `after_user_muted` in all six places,
      RPC-blocked, SDK-mirrored.
- [ ] Admin pages (reports/mutes/filter) + `/admin` card + routes + nav +
      `admin_pages_render_test`; admin API parity.
- [ ] Docs, `.env.example`, CHANGELOG, `api_spec.ex`; i18n across 30 locales.
- [ ] Tests: context + controller (report) + admin + LiveView, both adapters;
      boot and actually block a word, file+resolve a report, mute+reject a sender.
- [ ] `mix format`, `mix credo --strict`, full `mix test` green; `mix gen.sdk`
      clean; example plugin compiles warning-free.
