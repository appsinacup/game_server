# Push — server delivery + push-token storage

Design spec for the Phase 1 **Push** item in [ROADMAP.md](../../ROADMAP.md).
Format and rigor mirror the Phase 0 sections: what ships, the concrete
architecture, and the full CONTRIBUTING checklist it must satisfy.

Goal: let the server deliver push notifications to a user's devices, reliably
and provider-agnostically. Two halves ship here:

1. **Push-token storage** — devices register their FCM/APNs token against the
   authenticated user; a user has many devices.
2. **Server delivery** — `GameServer.Push.send_to_user/3` fans a message out to
   those tokens over the durable job queue, retrying transient provider errors
   and pruning tokens the provider reports dead.

The Godot-side client work ("Push — Godot client") is a **separate** Phase 1
item; this item is the server contract it targets.

## Why (rides on Jobs; completes the notification story)

Today `GameServer.Notifications` reaches only *connected* clients — a row is
written and a PubSub event fires, so a user who isn't holding a WebSocket open
never learns anything happened. Push closes that gap: it's the one delivery
channel that works when the app is backgrounded or killed. It's placed right
after Phase 0 because reliable fan-out is exactly what the job queue exists for
— a broadcast to a group/party/all-users must survive restarts and transient
5xx from the provider, which `GameServer.Async` cannot promise.

## Both providers, no push library — why Pigeon isn't needed

We ship **FCM** (Android + Web) **and APNs-direct** (iOS, straight to Apple —
no Google middleman) from the first cut, each behind our own `Provider`
behaviour, and we do it with **zero new dependencies** — no `pigeon`, no `goth`.

A push library's entire job is to bundle the two things a provider needs: an
**HTTP client** (HTTP/2, for APNs) and **JWT auth**. This repo already has both:

| What APNs-direct needs | Already in the tree |
|------------------------|---------------------|
| HTTP/2 client with connection pooling | `req` → `finch` 0.23 → `mint` 1.9 (full HTTP/2). A dedicated Finch pool pinned to `protocols: [:http2]` for `api.push.apple.com` gives the persistent, multiplexed connection APNs wants. |
| ES256 JWT signed with a `.p8` key | `jose` (already a dep — it's what `ueberauth_apple`/`GameServer.Apple` sign Apple secrets with). The APNs auth token is the same ES256 `.p8` JWT, cached ~1h in `GameServer.Cache` exactly like `Apple.client_secret/1` caches its secret. |
| HTTP/1.1 JSON for FCM v1 | `req` (already a dep). |

So Pigeon would only re-wrap machinery we already run, and add its own
supervision tree + bundled HTTP/2 client (Kadabra) on top. `goth` (for the FCM
OAuth token) also wants credentials **at boot**, which fights our hard
requirement that the default `Log` provider boots with **zero** push config;
minting the FCM token lazily on first send keeps that zero-config boot intact.

The only thing we own by hand-rolling is a small APNs response/error mapping and
the Finch HTTP/2 pool config — and Oban already owns retries/backoff, so the
adapter itself stays thin. This matches the house style (payments providers are
hand-written; Apple secrets are signed in-house) and keeps the embedded
single-binary lean.

## Provider model — routed per token, not one global switch

A behaviour `GameServer.Push.Provider`:

```elixir
@callback deliver([Message.t()], keyword()) :: [{:ok, token :: String.t()} | {:invalid, token :: String.t()} | {:error, token :: String.t(), term()}]
@callback configured?() :: boolean()
```

Three adapters ship:

- **`GameServer.Push.Providers.Log`** — the default (dev/test). Logs each
  message instead of calling out, so the whole flow runs with zero credentials
  — the `Storage.Local` of push. Returns `{:ok, token}` for every token.
- **`GameServer.Push.Providers.FCM`** — Firebase Cloud Messaging **HTTP v1**,
  for **Android and Web** (and it can still relay iOS if you'd rather not run
  APNs). `req` POSTs to
  `https://fcm.googleapis.com/v1/projects/<id>/messages:send`; the OAuth2 bearer
  is a service-account JWT (RS256) cached in `GameServer.Cache`, minted like
  `Apple.client_secret/1`. `404 UNREGISTERED` / `400 INVALID_ARGUMENT` → `{:invalid, token}`.
- **`GameServer.Push.Providers.APNs`** — **direct to Apple** for **iOS**.
  `req` over a dedicated HTTP/2 Finch pool POSTs to `api.push.apple.com`
  (`api.sandbox.push.apple.com` in sandbox) at `/3/device/<token>`, with headers
  `apns-topic` (bundle id), `apns-push-type`, `apns-priority`, `apns-expiration`,
  `apns-collapse-id`, and a bearer ES256 JWT (`kid`=APNs key id, `iss`=team id,
  `iat`), reused ~1h from `GameServer.Cache`. `410 Unregistered` /
  `400 BadDeviceToken` → `{:invalid, token}`; other non-200 → transient
  `{:error, token, reason}` for Oban to retry.

**Routing.** Unlike the single-switch Storage adapter, Push routes **per token**
off the `push_tokens.provider` column: `"fcm"` → FCM, `"apns"` → APNs. A
provider whose `configured?/0` is false (no creds) — and the global
`PUSH_ADAPTER=log` override — both fall through to `Log`. So: no config → dev
logs everything; configure only `PUSH_FCM_*` → iOS tokens registered as `fcm`
relay through Google; configure `APNS_*` too → iOS tokens registered as `apns`
go straight to Apple. `send_to_user/3` groups a user's live tokens by resolved
provider and calls each provider's `deliver/2` with its batch.

## Data model — `push_tokens` (both adapters)

Schema `GameServer.Push.PushToken` (`use GameServer.Schema`, UUIDv7), migration
in `apps/game_server_core/priv/repo/migrations/`:

| column | type | notes |
|--------|------|-------|
| `id` | uuid v7 | PK |
| `user_id` | uuid | `references(:users, on_delete: :delete_all)` |
| `token` | string | the FCM registration token or APNs device token |
| `platform` | string | `"android"` \| `"ios"` \| `"web"` |
| `provider` | string | `"fcm"` \| `"apns"` — **drives routing** (see Provider model). Client sets it at registration: iOS-native → `apns`, Firebase → `fcm` |
| `device_id` | string, null | dedupe key so re-registering a device rotates its token in place |
| `disabled_at` | utc_datetime, null | set when the provider reports the token dead — **soft-delete, never hard** (a token can come back) |
| `last_used_at` | utc_datetime, null | bumped on successful send |
| `metadata` | map | `app_version`, `locale`, … (size-capped) |
| timestamps | | |

- **Indexes:** `unique_index(:token)`; `unique_index([:user_id, :device_id], where: "device_id IS NOT NULL")` so a device upserts; partial `index([:user_id], where: "disabled_at IS NULL")` to serve the hot "this user's live devices" sweep and the dashboard counter at once. No `ALTER COLUMN`, no `DISTINCT ON` (CONTRIBUTING §Data model).
- **Caps** in `GameServer.Limits` (auto `LIMIT_*`, enforced in the changeset,
  listed in `@limit_categories`): `max_push_tokens_per_user` (20),
  `max_push_title` (255), `max_push_body` (4000), `max_push_data_size` (4096).

## `GameServer.Push` — the context

Token management (every `list_*` is paginated with a matching `count_*`,
CONTRIBUTING §Functionality):

```elixir
Push.register_token(user_id, %{"token" => ..., "platform" => "ios", "provider" => "apns", "device_id" => ...})
Push.unregister_token(user_id, token)
Push.list_tokens(user_id, page: 1, page_size: 25)   # + count_tokens/1
Push.list_all_tokens(filters, opts)                  # + count_all_tokens/1 (admin)
```

`register_token/2` **upserts** on `(user_id, device_id)` when a `device_id` is
given (rotates the token for that device), else on `token`; defaults `provider`
from the platform / configured default; enforces `max_push_tokens_per_user`;
re-enables a previously-disabled row. Any capacity check is a read-modify-write,
so it holds a `GameServer.Lock` (new advisory-lock namespace `:push_tokens` in
`GameServer.Repo.AdvisoryLock`), per CONTRIBUTING.

Delivery (server-authoritative — **no public send endpoint**, exposed through
hooks/admin only, CONTRIBUTING §Web):

```elixir
Push.send_to_user(user_id, %{title: ..., body: ..., data: %{...}}, opts)
Push.send_to_users([user_id], message, opts)          # reliable fan-out
```

- A `%GameServer.Push.Message{}` struct (`title`, `body`, `data`, `image`,
  `sound`, `badge`, `collapse_key`) is validated against the `Limits` caps
  before anything is enqueued.
- `send_to_user/3` runs the `before_push_send` pipeline (veto/rewrite), resolves
  the user's live tokens, then enqueues **`GameServer.Push.DeliveryWorker`**
  (`use Oban.Worker, queue: :push, max_attempts: 5`) in per-provider token
  batches. The worker calls that batch's provider, bumps `last_used_at` on
  `{:ok, _}`, calls `disable_token/1` on `{:invalid, _}`, returns `{:error, _}`
  on transient failures so Oban retries with backoff, and fires `after_push_sent`.
- Add a **`push`** queue to the Oban config in `host_config.exs`
  (`queues: [..., push: 10]`).

## Hooks (all six places, per CONTRIBUTING §Hooks)

Two callbacks — for each: `@callback` + `@optional_callbacks` in
`GameServer.Hooks`, add to `internal_hooks()` (RPC-blocked), no-op in
`GameServer.Hooks.Default`, mirror in the SDK (`@callback`,
`@optional_callbacks`, `__using__` default, **and `defoverridable`**), and
document on the Server-scripting page.

- **`before_push_send(user_id, message)`** — pipeline hook (add to
  `lifecycle_pipeline_hook?/2` + a `normalize_pipeline_args/3` veto clause).
  Lets a plugin drop a push (per-user opt-out, quiet hours, moderation) or
  rewrite it. **Never dispatched inside a lock/transaction** — resolved before
  the enqueue, results deferred and flushed after commit (`defer/1` pattern).
- **`after_push_sent(user_id, message, results)`** — observe per-token outcome.

Because delivery retries live behind Oban, any hook the worker invokes goes
through `GameServer.Jobs`/`HookWorker`, so it's auto-registered in
`ProtectedCallbacks` and blocked from client RPC (Phase 0 machinery).

## First consumer: `Notifications` → push

Mirrors "avatars are Storage's first consumer." After
`Notifications.upsert_notification/3` (and the chat path) commits and
broadcasts, it calls `Push.send_to_user/3` with the notification's title/content
so an **offline** friend still gets pinged. Kept decoupled and best-effort: the
call no-ops under the `Log` provider and when the recipient has no live tokens,
and it's queued after commit (never inside the insert), so a push failure can't
roll back a notification.

## Config (`host_config.exs` default + `host_runtime.exs` runtime)

```
PUSH_ADAPTER=log                 # optional override: force everything to Log (dev/staging)
                                 # unset → route per token to whichever provider is configured

# FCM (Android/Web, or iOS relay) — enabled when project id + credentials are set
PUSH_FCM_PROJECT_ID=
PUSH_FCM_CREDENTIALS=            # path to, or inline JSON of, the service-account key

# APNs-direct (iOS) — enabled when the .p8 key + ids are set
APNS_KEY_ID=                     # 10-char key id of the APNs .p8 auth key
APNS_TEAM_ID=                    # Apple developer team id
APNS_PRIVATE_KEY=                # the .p8 contents (or a path to it)
APNS_TOPIC=                      # app bundle id, sent as apns-topic
APNS_ENV=production|sandbox      # default production
```

`config :game_server_core, GameServer.Push, adapter: GameServer.Push.Providers.Log`
is the compiled default; `host_runtime.exs` enables FCM and/or APNs from the
vars above, mirroring the `STORAGE_ADAPTER` case block. Each provider's
`configured?/0` reflects whether its vars are present.

## Web / API

- `POST /me/push-tokens` — register `{token, platform, provider?, device_id?}`.
- `GET  /me/push-tokens` — list my devices (paginated `meta` block).
- `DELETE /me/push-tokens/:id` — unregister one.
- Routes in `router/shared.ex` under the authenticated `/me` scope. **No**
  public send route — sending is server-authoritative. Listing is per-user
  (own devices), so no `LIST_*_ENABLED` global gate needed.
- OpenAPI schemas in the controller (`ids` `type: :string, format: :uuid`); SDKs
  regenerate from the spec in CI.

## Admin

- `admin_live/push.ex` — tokens table (names not UUIDs, paginated, filter by
  user/platform/provider, shows disabled), plus a **"send test push to user"**
  form.
- `/admin` stat card (registered devices, split by platform/provider) + route +
  nav link + an entry in `admin_pages_render_test`.
- `controllers/api/v1/admin/push_controller.ex` — parity for every UI action:
  list tokens, delete a token, send a push to a user.

## "Update everywhere we mention features" — concrete file list

- **README.md** — Features: add **Push notifications**.
- **CHANGELOG.md** — `[added]` Push notifications (FCM + APNs) · `[added]`
  Push-token storage.
- **.env.example** — all `PUSH_*` / `PUSH_FCM_*` / `APNS_*` vars +
  `LIMIT_MAX_PUSH_*`.
- **host_public_docs/** (registered in `host_public_docs.ex`): new **Push
  notifications** page (register flow, FCM service-account setup **and** APNs
  `.p8` key setup, sending from a hook); Data Schema page gains `push_tokens`.
- **api_spec.ex** — feature list + push-token endpoints.
- **SDK** — `sdk/lib/game_server/push.ex` + struct stubs
  `sdk/lib/game_server/push/{message,push_token}.ex`, add to `@sdk_modules`,
  `mix gen.sdk`, placeholder rules (`T | nil`, `{:ok, T}`); hooks mirrored.
- **runtime_introspection.ex** — Push section: token counts (total, per
  platform, per provider, disabled) + `push` queue stats.
- **.github/copilot-instructions.md** — mention push in the feature overview.
- **i18n** — `gettext.extract` + `merge`, translate all 30 locales, clear
  fuzzies.
- **mix demo.seed** — seed sample push tokens (under the `Log` provider) so the
  admin page shows devices at volume.

## Deferred / rejected, with reasons

- **A push library (`pigeon` / `goth`): no.** Its value is an HTTP/2 client +
  JWT auth, both of which already exist here (`finch`/`mint` HTTP/2, `jose`
  ES256) — see "Both providers, no push library" above. `goth` additionally
  wants credentials at boot, which breaks the zero-config `Log` default.
- **Rich push (actions / silent / Live Activities) beyond the basic fields:
  defer.** Ship `title`/`body`/`data`/`image`/`sound`/`badge`/`collapse_key`.
  APNs-direct leaves the door open to Live Activities later (it's an
  APNs-native push type), but the client-render side waits for the Godot client
  to demonstrate demand.
- **Per-user notification-preference matrix: defer.** The `before_push_send`
  veto hook already lets a plugin implement opt-out/quiet-hours; a first-class
  preferences table can generalize that later without changing this contract.
- **Certificate-based APNs auth: no.** Token auth (`.p8` ES256) is the modern
  path — one key for all apps, no yearly cert rotation — and it reuses the
  signing the repo already does. `.p12` cert auth adds mTLS plumbing for no gain.

## Definition of done (CONTRIBUTING)

- [ ] `push_tokens` migration applies on SQLite **and** `DATABASE_ADAPTER=postgres`.
- [ ] `GameServer.Push` context: paginated `list_*`/`count_*`, `Limits` caps in
      the changeset, capacity write-modify-write under a `:push_tokens` lock,
      dead-token soft-disable, per-token provider routing.
- [ ] `FCM` + `APNs` + `Log` providers behind the behaviour; `DeliveryWorker` on
      the new `push` Oban queue retries transient, disables invalid, fires
      `after_push_sent`.
- [ ] Hooks `before_push_send` / `after_push_sent` in all six places, RPC-blocked,
      SDK-mirrored; `Notifications` calls `Push.send_to_user/3` after commit.
- [ ] Admin page + `/admin` card + route + nav + `admin_pages_render_test`;
      admin API parity (list / delete / send).
- [ ] Docs pages, `.env.example`, `CHANGELOG`, README, `api_spec.ex`.
- [ ] Tests: context + controller + admin + LiveView, on both adapters. Boot and
      actually register a token and run a delivery job end-to-end (Log provider);
      mock an FCM `404 UNREGISTERED` **and** an APNs `410 Unregistered` to prove
      disable-on-dead; assert the HTTP/2 request shape for both providers.
- [ ] `mix format`, `mix credo --strict`, full `mix test` green; `mix gen.sdk`
      clean; example plugin compiles warning-free.
