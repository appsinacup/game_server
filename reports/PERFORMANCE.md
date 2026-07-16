# Performance & Concurrency Audit — gamend

Scope: performance and concurrency only. Findings are code-verified with `file:line`
references. No code was changed.

The dominant issue class is **per-subscriber work inside channel `handle_info`**: a single
user action broadcasts to a topic, and every subscribed socket independently repeats a DB
query (or cache lookup) to build its own copy of the payload. Because the number of
subscribers scales with the size of the lobby/party/group, several of these are O(N) DB
queries — and in the lobby case O(N²) rows — per single action. The second theme is
**hot-path serialization through single GenServers / periodic per-socket work** (PluginManager
hook dispatch, per-3-min presence writes, connect-time bulk loads).

## Severity counts

| Severity | Count |
|----------|-------|
| Critical | 1 |
| High     | 3 |
| Medium   | 5 |
| Low      | 3 |

---

## Critical

### Lobby update broadcast runs `get_lobby_members` once per subscribed socket (O(N) queries, O(N²) rows)

- **Location**: `apps/game_server_web/lib/game_server_web/channels/lobby_channel.ex:138-150` and `:163-171`; serializer at `apps/game_server_web/lib/game_server_web/serializers.ex:101-105`; query at `apps/game_server_core/lib/game_server/lobbies.ex:613-619`.
- **Issue**: `handle_info({:lobby_updated, lobby}, socket)` and `{:after_join, lobby}` both call `Serializers.serialize_lobby(lobby, include_members: true)`. `include_members` triggers `Lobbies.get_lobby_members(lobby.id)` — a `Repo.all` over the `users` table — plus `Enum.map(&User.serialize_brief/1)`. `handle_info` runs **inside every socket process subscribed to `lobby:<id>`**. The broadcast source (`lobbies.ex:836` `broadcast_lobby(updated.id, {:lobby_updated, updated})`) sends the same struct to all members, so each of the N member sockets independently issues its own `get_lobby_members` query, each returning N rows.
- **Impact**: For a lobby of N members, one lobby update = **N `get_lobby_members` DB queries returning N rows each = O(N²) rows materialized and serialized per update**. Lobby updates fire on metadata changes, host changes, join/leave-driven re-broadcasts, and any game that writes lobby metadata — i.e. potentially many times per second per active game. This is the primary latency/DoS risk at scale.
- **Fix**: Fetch and serialize the member list **once at the broadcast source** and include it in the broadcast payload, so each `handle_info` only computes its per-socket `PayloadDelta` from the already-materialized list. The delta diffing (which needs per-socket `last_lobby_payload`) can stay in the channel; only the DB read must move out of the per-socket path.
- **Confidence**: High.

---

## High

### Party update broadcast runs `get_party_members` once per subscribed socket

- **Location**: `apps/game_server_web/lib/game_server_web/channels/party_channel.ex:109-121`, `:124-140`, `:218-224`; serializer `apps/game_server_web/lib/game_server_web/serializers.ex:138` (`serialize_party` **always** loads members); query `apps/game_server_core/lib/game_server/parties.ex:212`.
- **Issue**: Same anti-pattern as the lobby case. `serialize_party/2` unconditionally does `party.id |> Parties.get_party_members() |> Enum.map(&User.serialize_brief/1)`. Every `:party_updated` / `:after_join` / (indirectly) `:party_member_joined` handler runs this per socket. `party_channel.ex:124-140` additionally re-fetches the party (`Parties.get_party`) before serializing when it receives a bare `party_id`.
- **Impact**: **N `get_party_members` queries per party update** for an N-member party. Parties are capped smaller than lobbies (`max_size`), so blast radius is lower than the lobby finding, but the multiplier is still per-member-per-update on a realtime path.
- **Fix**: Move member materialization to the broadcast source; pass members in the event. Avoid the extra `get_party` refetch in `:party_updated` when the full struct is already available.
- **Confidence**: High.

### Every hook invocation serializes through the single `PluginManager` GenServer

- **Location**: dispatch `apps/game_server_core/lib/game_server/hooks.ex:283` (`lifecycle_modules()`) → `:395` (`PluginManager.hook_modules()`) → `apps/game_server_core/lib/game_server/hooks/plugin_manager.ex:87-88` (`list()`) → `:70-76` (`GenServer.call(__MODULE__, :list)`).
- **Issue**: `Hooks.internal_call/3` is invoked on many hot paths (e.g. `:before_kv_get` on every KV read in `user_channel.ex:579`, `:after_user_online`/`:after_user_offline` on every presence transition, `before_lobby_join`, `before_chat_message`, etc.). Each call resolves the plugin module list via `PluginManager.list/0`, which is a **`GenServer.call` to a single named process**. All hook-gated traffic across all connections therefore funnels through one process's mailbox. `handle_call(:reload, ...)` (`plugin_manager.ex:179`) runs `do_reload` + `do_after_startup` **in the same process**, so a plugin reload blocks every in-flight hook lookup up to `@timeout_ms`.
- **Impact**: On a KV-heavy game, **one `GenServer.call` round-trip (plus cross-process copy of the plugin list) per KV read/write and per presence event**, serialized system-wide. Becomes a throughput ceiling and a head-of-line-blocking point during reloads.
- **Fix**: Publish the plugin/hook-module list into a read-optimized store the callers can read lock-free — `:persistent_term` or a `:protected` ETS table updated by the GenServer on reload — so `hook_modules/0`/`list/0` become direct reads instead of `GenServer.call`. Keep `reload` on the GenServer.
- **Confidence**: High.

### User-channel join does two `page_size: 1000` bulk loads and a per-notification push loop

- **Location**: `apps/game_server_web/lib/game_server_web/channels/user_channel.ex:508-514` (`push_existing_notifications`) and `:516-527` (`push_initial_friend_update`), both driven from `handle_info({:after_join, ...})` at `:301-304`.
- **Issue**: On every user connect, `Notifications.list_notifications(user_id, page: 1, page_size: 1000)` loads up to 1000 rows and then `Enum.each` pushes **one WebSocket frame per notification** (up to 1000 individual pushes). Immediately after, `Friends.list_friends_with_friendship(page: 1, page_size: 1000)` loads up to 1000 friendships **with `preload: [:requester, :target]`** and serializes all of them.
- **Impact**: Connect-time cost scales with a user's total notification and friend counts (bounded only at 1000). A user with hundreds of notifications generates hundreds of separate socket sends on connect; reconnect storms multiply this across users. This is on the connection hot path, not a background job.
- **Fix**: Cap the initial notification window to a small recent page and let clients paginate; batch the initial notifications into a single framed payload instead of one push per row (mirroring the batched `friend_updated` payload). Lower the friend page size or stream in pages.
- **Confidence**: High.

---

## Medium

### Per-socket `Accounts.get_user` on every presence/member event across lobby, party, and group channels

- **Location**: `lobby_channel.ex:107,193,209`; `party_channel.ex:84,172,188`; `group_channel.ex:189`; plus `Serializers.display_name/1` (`serializers.ex:16-21`) used at `lobby_channel.ex:122,131,156`.
- **Issue**: `:user_joined`, `:member_online`/`:member_offline`, and `:member_updated` handlers call `Accounts.get_user(user_id)` (or `display_name/1`, which calls `get_user`) **inside each subscribed socket**. `get_user/1` is Nebulex-`cacheable` (`accounts.ex:411-416`, 60s TTL), so most hits are cache reads — but it is still **N cache round-trips per presence event** for an N-member room, and each becomes a DB read on cache miss (see the touch-driven cache busting below).
- **Impact**: 1 cache lookup per member per presence event; degrades to 1 DB query per member per event whenever the cache entry was just invalidated. A single member toggling online in an N-member lobby fans out to N `get_user` calls.
- **Fix**: Include the minimal serialized user payload (`display_name`, `id`, online flag) in the broadcast event itself so subscribers never look the user up. This also removes the cache dependency on the hot path.
- **Confidence**: High.

### Periodic presence refresh writes the DB and busts the user cache every 3 min per socket

- **Location**: `user_channel.ex:70` (`@presence_refresh_interval :timer.minutes(3)`), `:316-325` (`:refresh_presence`) → `apps/game_server_core/lib/game_server/accounts.ex:342-350` (`touch_last_seen_by_id`).
- **Issue**: Each user socket re-arms `:refresh_presence` every 3 minutes. `touch_last_seen_by_id/1` does `Repo.update_all(set: [last_seen_at: now, is_online: true])` **and** `GameServer.Cache.delete({:accounts, :user, user_id})`. So every 3 minutes per connected user there is (a) a `users`-table write and (b) a distributed cache invalidation of that user's record — right in the window where lobby/party/group channels are actively reading it via `get_user`.
- **Impact**: **N DB writes + N cache deletes per 3-minute window** for N connected users, plus induced cold `get_user` reads afterward. Write and cache-invalidation amplification that grows linearly with concurrent users; also generates row churn / WAL on the `users` table. Multi-tab users get one timer per tab.
- **Fix**: Update only `last_seen_at` (drop the redundant `is_online: true` re-write when already online) and avoid deleting the cache on a pure heartbeat — update the cached struct's `last_seen_at` in place, or skip caching `last_seen_at` and read it separately. Consider a single per-node sweep of last-seen instead of per-socket timers.
- **Confidence**: High.

### `ConnectionTracker.list_registered(:user_channel)` scanned on every disconnect

- **Location**: `user_channel.ex:483-487` (in `terminate/2`) using `apps/game_server_web/lib/game_server_web/channels/connection_tracker.ex:60-64` (`Registry.lookup`).
- **Issue**: On every user-channel `terminate`, the code calls `list_registered(:user_channel)` — a `Registry.lookup` returning **all** registered user channels — then `Enum.count` filters by `user_id` to decide whether to mark the user offline. This is O(total connected user channels) per disconnect.
- **Impact**: With C concurrent user channels, each disconnect is an O(C) scan + copy; a mass disconnect (deploy, node drain, network blip) is O(C²) aggregate. At 10k connections that is a 10k-entry scan per socket closing.
- **Fix**: Track presence per user with a keyed `Registry` (register under `{:user_channel, user_id}`) so the "any other socket for this user?" check is an O(1)/O(k) `Registry.count/lookup` on that key instead of scanning the whole type.
- **Confidence**: High.

### `list_leaderboard_groups` is N+1 (3 queries per slug)

- **Location**: `apps/game_server_core/lib/game_server/leaderboards.ex:306-308` (`Enum.map(slugs, &build_group_info/1)`) and `:311-347` (`build_group_info` runs `Repo.one` latest + `Repo.one` active + `Repo.aggregate(:count)`).
- **Issue**: After fetching the page of slugs (1 query), each slug triggers 3 more queries. For the default `page_size: 25`, a cache miss is `1 + 25*3 = 76` queries.
- **Impact**: 76 queries per uncached leaderboard-groups list request. Mitigated by the surrounding `cacheable` (`:287-290`), so amortized cost is low, but cold caches / high slug cardinality make it spiky.
- **Fix**: Compute latest/active/season_count in a single grouped query over `slug` (window functions or `group_by slug` with conditional aggregates) instead of per-slug round-trips.
- **Confidence**: High.

### List queries fall back to unbounded `Repo.all` and filter metadata after pagination

- **Location**: `apps/game_server_core/lib/game_server/lobbies.ex:1402-1412` and `apps/game_server_core/lib/game_server/groups.ex:1163-1173` (`paginate/2`); metadata filter `lobbies.ex:199-215` (`filter_by_metadata_in_memory`).
- **Issue**: `paginate/2` applies `limit`/`offset` only when **both** `:page` and `:page_size` are supplied; otherwise it runs `Repo.all(q)` over the whole (filtered) table. Any caller of `list_lobbies/1` or `list_groups/1` that omits pagination loads every matching row. Separately, `filter_by_metadata_in_memory` filters the result set **after** pagination, so metadata-filtered pages return fewer than `page_size` rows and the paired `count_list_lobbies` total is inconsistent with the filtered results.
- **Impact**: Unbounded `Repo.all` on `lobbies`/`groups` for any unpaginated caller — grows with table size. Metadata-filtered pagination is also functionally wrong (short/again inconsistent pages), causing clients to over-fetch.
- **Fix**: Enforce a default+max page size in `paginate/2` (never an unbounded `Repo.all`). Push metadata filtering into the SQL `WHERE` (Postgres JSONB operators) so it composes with `limit`/`offset` and `count`.
- **Confidence**: High.

---

## Low

### Advisory locks are coarse per-lobby and use `phash2` on the UUID

- **Location**: `apps/game_server_core/lib/game_server/lobbies.ex:530,879` (`AdvisoryLock.lock(:lobby, lobby.id)`), `parties.ex:810,1259,1366`, `groups.ex:666`; hashing `apps/game_server_core/lib/game_server/repo/advisory_lock.ex:73` (`:erlang.phash2(resource_id, 2_147_483_647)`).
- **Issue**: A single `(:lobby, lobby_id)` advisory lock serializes **all** mutating operations on a lobby (join, leave, kick, update) against each other. Independent operations that don't actually conflict still block. Additionally the UUID `resource_id` is hashed to 32 bits via `phash2`; distinct lobbies whose hashes collide will serialize against each other across the whole namespace (collision only adds serialization, never breaks correctness — as documented at `advisory_lock.ex:53-55`).
- **Impact**: Extra serialization on hot lobbies (all membership mutations single-file) and rare cross-lobby serialization on 32-bit hash collisions (birthday-bound: non-negligible only at very large numbers of concurrently-locked lobbies).
- **Fix**: Keep the coarse lock only where the invariant needs it (capacity/host election). If join throughput on large lobbies becomes a problem, scope narrower. Collision risk is acceptable given correctness is preserved; document the trade-off.
- **Confidence**: Medium (coarse-lock impact is workload-dependent).

### `lobbies_channel` accumulates an unbounded `last_lobby_payloads` map per socket

- **Location**: `apps/game_server_web/lib/game_server_web/channels/lobbies_channel.ex:42-53`, `:71-80`.
- **Issue**: Each subscriber to the global `"lobbies"` topic stores the last serialized payload for every lobby it has seen, keyed by lobby id, for delta diffing. Entries are never pruned — not even on `:lobby_deleted` (`:56-60` doesn't touch the map). A long-lived browser on the lobby list grows this map with every lobby ever created during the session.
- **Impact**: Slow per-socket memory growth proportional to distinct lobbies observed over the connection lifetime. Bounded by session length, not catastrophic, but unbounded in principle.
- **Fix**: Drop the entry from `last_lobby_payloads` on `:lobby_deleted`, and/or cap/evict the map.
- **Confidence**: High.

### Presence changes trigger source-side fan-out queries on every transition

- **Location**: `user_channel.ex:648-665` (`broadcast_member_presence` → `Groups.user_group_ids/1` at `groups.ex:102`) and `apps/game_server_core/lib/game_server/accounts.ex:1787-1812` (`broadcast_member_update` → `user_group_ids` + `broadcast_friend_update` → `Friends.friend_ids/1` at `friends.ex:787`).
- **Issue**: Every online/offline transition and every public-data change runs `user_group_ids` (1 query) and, in `broadcast_member_update`, also `friend_ids` (1 query), then issues one PubSub broadcast per group and per friend. The per-subscriber cost is fine (the `friend_updated` `handle_out` at `user_channel.ex:251-273` is delta-only, no DB), but the **source** does 1–2 queries + F+G broadcasts per event.
- **Impact**: 1–2 DB queries and O(friends + groups) PubSub messages per presence/data change. Modest per event, but multiplied by presence churn and by the fact that `set_user_online`/`set_user_offline` fire it on every connect/disconnect.
- **Fix**: Cache `user_group_ids`/`friend_ids` (short TTL) since they change rarely relative to presence toggles; the values are already good cache candidates.
- **Confidence**: Medium.

---

## Notes on things checked and found OK

- `Groups.list` member counts are correctly batched via `Groups.batch_member_counts/1` (`group_controller.ex:854`, `groups.ex:282-290`) — no N+1.
- Chat message listing preloads `:sender` (`chat.ex:440,467,843`) — no N+1 in serialization.
- `Leaderboards.list_records` computes rank by index offset and preloads `:user` (`leaderboards.ex:918-931`) — no per-row rank query.
- `GameServer.Async` has real back-pressure: bounded `Task.Supervisor`, runs inline on `:max_children` with telemetry (`async.ex:26-52`) — not an unbounded-spawn risk.
- The `friend_updated` payload is built once at the source and delta-diffed per subscriber without DB access (`accounts.ex:1821-1834`, `user_channel.ex:251-273`) — this is the correct pattern the lobby/party channels should follow.
