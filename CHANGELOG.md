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

- [fixed] Duplicate KV entry creation falsely reported success; KV caches never hit after Nebulex 3.
- [fixed] Search filters escape `LIKE` wildcards consistently.

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
