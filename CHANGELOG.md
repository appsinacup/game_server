# July 2026

- [breaking] **All ids are UUIDv7 strings** — regenerate SDKs, start fresh database. Host repos: migrations now default to `binary_id` (set by `GameServer.Repo.init/2`), so your own schemas must `use GameServer.Schema` instead of `use Ecto.Schema`, and code comparing/parsing ids as integers (`is_integer(user_id)`, `Integer.parse`, `-1` sentinels) must switch to strings (`""` = absent).
- [breaking] Pre-existing JWTs rejected; clients must log in again.
- [breaking] Context APIs take one input shape (id or struct).

- [added] **JWT revocation** via `token_version` claim.
- [added] **Persistent IP bans**, shared across instances.
- [added] **Redis rate-limit backend** for multi-instance deployments.
- [added] **Data retention**: periodic pruning via `RETENTION_*` env vars.
- [added] **Public listing flags** disable browse endpoints and pages.
- [added] **Anti-abuse limits**: daily chat quota, per-user socket cap.
- [added] **New plugin hooks**: `after_score_submitted`; veto-able `before_*` for group delete/kick and party join/kick.
- [breaking] `before_lobby_leave` hook removed — leaving is always allowed (`after_lobby_leave` remains).
- [added] **Observability**: cache, rate-limit, and overload metrics (dashboard + Prometheus).

- [changed] **Dev setup**: `.env` drives config (incl. DB adapter) at compile time; `mix setup` fixed; shared `db.*`/`host.*` tasks ship from `game_server_core` (delete local copies).
- [changed] **Reliability**: cross-instance cache invalidation, bounded async side effects, presence events once per session, boot works without a reachable database.

- [security] **Apple IAP receipts now verify the full x5c chain** to a pinned Apple Root CA - G3 (`priv/certs/apple_root_ca_g3.pem`) — forged/self-signed receipts are rejected. Verification fails closed if the pinned root is absent.
- [breaking][security] **OAuth auto-linking requires a verified provider email.** A provider login whose id is new but whose email matches an existing account only links when the provider asserts `email_verified` (Facebook, which exposes no such claim, never auto-links). Otherwise the login is rejected with guidance to link from account settings while authenticated. Prevents account takeover.
- [security] **Hook RPC hardened uniformly**: reserved lifecycle-hook names and oversized argument payloads are now rejected inside `PluginManager.call_rpc`, so the HTTP, user-channel, and WebRTC DataChannel entry points all enforce them (the DataChannel path previously bypassed both).
- [security] **Google Play RTDN webhook fails closed in production** when `GOOGLE_PLAY_RTDN_TOKEN` is unset (was unauthenticated). Dev/test unchanged.
- [security] **Password change over the API requires the current password** for accounts that have one (OAuth/device accounts may still set an initial password).
- [security] **`/metrics` requires the bearer token for all non-loopback scrapes when `METRICS_AUTH_TOKEN` is set** (private/Docker IPs no longer bypass it); token comparison is constant-time.
- [security] OAuth registration changesets no longer cast `:is_admin` (mass-assignment hardening); the `refresh` endpoint now uses the strict auth rate-limit bucket.

- [fixed] Duplicate KV entry creation falsely reported success; KV caches never hit after Nebulex 3.
- [fixed] Search filters escape `LIKE` wildcards consistently.
- [fixed] Cross-instance cache invalidation now also covers version-counter caches (leaderboards, groups, lobbies, parties, friends, chat, notifications, achievements, KV lists); revocation re-warms the user cache to close a race that could keep a revoked JWT valid until TTL.

- [perf] **Lobby/party update broadcasts no longer re-query members per subscriber** — members are materialized once at the source (was O(N) queries / O(N²) rows per update).
- [perf] **Plugin hook-module lookups are lock-free** (`:persistent_term` snapshot refreshed on reload) instead of a `GenServer.call` per hook — removes a system-wide serialization point and reload head-of-line blocking on hot paths (e.g. `before_kv_get`).
- [perf] **User-channel connect replays only the 50 most recent notifications** (was up to 1000, one frame each); older ones load via the REST API.
- [perf] **Disconnect offline-check is O(sockets-for-this-user)** via a per-user registry key (was O(all connected user channels)); the presence heartbeat updates the cached user in place instead of busting it every few minutes.
- [perf] **List queries never run an unbounded `Repo.all`** — `list_lobbies`/`list_groups` cap at a hard max page size; the lobby-list channel prunes its per-socket delta cache on lobby deletion.

- [db] **New migration adds missing indexes**: partial `users(last_seen_at) WHERE is_online` (Postgres) / `users(is_online, last_seen_at)` (SQLite) + `users(last_seen_at)` for the presence sweeper and online counts; re-adds the `leaderboard_records(leaderboard_id, score, updated_at)` index dropped by the SQLite table rebuild; `groups(lower(title))` for group search; `notifications(recipient_id, read, inserted_at)`.
- [db] **Friend-request creation now takes an advisory lock on the canonical (direction-independent) pair** — fixes a Postgres TOCTOU race where concurrent A→B and B→A requests could both insert reciprocal pending rows.
- [db] **User deletion cleans up friend DMs sent to the deleted user** (the polymorphic `chat_ref_id` has no FK), preventing orphaned half-conversations; OAuth sessions older than a day are now pruned by the retention job; the chat-notification upsert `COALESCE`s NULL metadata so the message-count increment isn't lost.

# April 2026

- [changed] Root host app restructure.
- [added] Browser theme color, sitemap.xml, robots.txt.
- [added] **Native HTTPS**
- [added] **Account Activation** beta mode.
- [added] Translations: Spanish, French, Romanian.
- [added] Roadmap page.
- [added] Security: RealIp, IP bans, OAuth CSRF, rate limiting, WebRTC - limits, security headers.
- [added] **OPENAPI_ENABLED** feature gate.

# March 2026

- [changed] Make Leaderboards accept label instead of user_id.
- [added] Initial version of **Achievements**.
- [added] Initial version of **Rate Limiting**.
- [changed] Self-hosted Inter font and eliminated all inline scripts.
- [added] Initial version of **WebSocket** updates.
- [added] Initial version of **WebRTC** updates.
- [changed] Admin interface with realtime connections view.

# Feb 2026

- [added] Initial version of **CHANGELOG** and **Blog**.
- [added] Initial version of **Groups**.
- [added] Initial version of **Parties**.
- [added] Initial version of **Notifications**.
- [added] Initial version of **Chat**.
