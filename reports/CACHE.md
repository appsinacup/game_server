# Cache Correctness & Consistency Audit — gamend

Scope: Nebulex v3 usage across `GameServer.Cache` (+ `Cache.Sync`, `Cache.L1`,
`Cache.L2.*`, `Cache.Stats`) and every context using `@decorate` /
`GameServer.Cache.*`. Findings only — no code was changed.

## Summary

The cache layer is generally well-built. Read-through `cacheable` keys and
their invalidations line up; version-counter keys are bumped on the mutations
that matter; the recently-fixed Nebulex-3 return-shape class of bugs appears
fully cleaned up (`Cache.get!/1` used for raw values, `Cache.fetch/1`'s
`{:ok, v}` handled in `cached/3`, decorators handle unwrapping). Keys are
UUID-clean — no cache key still depends on integer ids (only some
`@type`/`@spec`/doc annotations and a variable name remain stale).

The real weaknesses are consistency on **multi-node deploys**:

1. Only `GameServer.Cache.invalidate/1` broadcasts (PubSub → `Cache.Sync`).
   Every **version-counter cache** is bumped with `GameServer.Cache.incr/3`,
   which is **not** broadcast. On other nodes those counters (and their
   version-keyed entries) reconcile only via TTL — narrower than the CHANGELOG's
   "cross-instance cache invalidation" claim.
2. The auth-gating user-struct cache uses a **fixed key** (not version-keyed)
   and the credential-revocation path relies on read-through + `invalidate`,
   which has a re-population race that can keep a revoked user cached for the
   full 60s TTL.

### Severity counts

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High     | 2 |
| Medium   | 3 |
| Low      | 4 |

## High

### Credential revocation can be masked for up to 60s by a read-through re-cache race

- **Location**: `apps/game_server_core/lib/game_server/accounts.ex:1735-1748`
  (`update_user_and_delete_all_tokens/1`, called by `revoke_all_tokens/1`,
  `update_user_password/2`); read path
  `apps/game_server_web/lib/game_server_web/auth/guardian.ex:41-59`;
  cache config `accounts.ex:411-416` (`get_user/1`, fixed key
  `{:accounts, :user, id}`, `ttl: 60_000`).
- **Issue**: JWT revocation works by bumping `token_version` and calling
  `invalidate_user_cache/1` (a delete + broadcast). But `get_user/1` is a
  **read-through `cacheable`** on a *fixed* key. Under load the auth path calls
  `get_user/1` on nearly every request; if such a call reads the pre-revocation
  row from the DB and then lands its `Cache.put` *after* the revocation's
  `invalidate` delete, the stale user (old `token_version`) is re-cached for the
  full TTL. `resource_from_claims/1` compares `claims["tv"] == user.token_version`
  against that cached struct, so a revoked access/refresh token keeps validating.
  The codebase already recognises this exact hazard for lobby joins and mitigates
  it with a post-commit re-warm (`Accounts.cache_user/1`,
  `accounts.ex:436-442`; see comment `lobbies.ex:496-517`), but the
  security-critical revocation path does **not** re-warm.
- **Impact**: Single-node and multi-node. "Log out everywhere" / password change
  can leave old JWTs accepted for up to 60s (the invalidate delete is defeated by
  the racing put, so only the TTL saves you). The module's own docstring
  (`accounts.ex:30-33`) markets invalidation as immediate with the TTL as a
  fallback for *missed broadcasts*; this race turns the worst case into the
  common case on a hot auth endpoint.
- **Fix**: On the revocation path, re-warm the canonical key with the fresh
  struct (as `cache_user/1` does) instead of only deleting, or make `get_user/1`
  version-keyed (like groups/lobbies) so a `token_version` bump changes the key
  and no stale put can be read. Lower `@user_cache_ttl_ms` if a 60s worst case is
  unacceptable for revocation.
- **Confidence**: Medium-High (race window is narrow per-request but the auth
  path is the hottest `get_user/1` caller; the mitigation used elsewhere is
  absent here).

### Version-counter invalidations are not broadcast — cross-node reads stale up to TTL, contradicting the "cross-instance cache invalidation" claim

- **Location**: `GameServer.Cache.invalidate/1` is the only broadcaster
  (`cache.ex:51-62`; `cache/sync.ex:27-34`). Non-broadcast `incr` bumps:
  `leaderboards.ex:52-65`, `groups/shared.ex:28-35,43-58`, `lobbies.ex:77-81`,
  `parties.ex:94-96`, `groups/invites.ex` (via Shared),
  `achievements.ex:45-49`, `friends.ex:49-66`, `chat.ex:47-51`,
  `notifications.ex:81-85`, `kv.ex:131-174`, and the accounts stats counter
  `accounts.ex:39-46`. CHANGELOG claim: line 18 ("cross-instance cache
  invalidation").
- **Issue**: All list/count/entity caches in those contexts are invalidated by
  incrementing a version counter that is itself stored in the cache and read via
  `Cache.get!/1`. `incr` writes only through the local node's levels (and shared
  L2 if configured); it is never published on the invalidation topic. On another
  node, the version counter sits in that node's L1 (populated on first read, and
  version keys carry **no TTL** — they persist until the 12h generational GC), so
  the node keeps computing the *old* version key. Data entries under the old key
  do expire on their own TTL, so serving is bounded — but the version-key
  "immediate invalidation" only ever benefits the writing node. With the default
  `CACHE_MODE=single` (`config/host_runtime.exs:105`) there is no shared L2 at
  all, so counters diverge per node entirely.
- **Impact**: Multi-node only. A score submit, group/lobby edit, friend/chat/
  notification change, or KV write on node A is invisible to node B's cached
  list/count until node B's *data* TTL elapses: ~10s for leaderboard records,
  ~60s for leaderboards / KV lists / groups / notifications / achievements, etc.
  Bounded and mostly game/social data (not auth), but the CHANGELOG oversells it
  as cross-instance invalidation; in reality only user structs, user tokens,
  OAuth sessions, and single-key KV entries get cross-instance eviction.
- **Fix**: Either broadcast version bumps (add an `incr`-and-broadcast helper, or
  have `Cache.Sync` also apply `incr` events), or document that version-keyed
  caches converge via TTL across nodes and size TTLs accordingly. Give version
  keys an explicit long TTL if unbounded L1 residency is a concern.
- **Confidence**: High.

## Medium

### `touch_last_seen_by_id/1` uses local-only `Cache.delete` instead of `Cache.invalidate`

- **Location**: `apps/game_server_core/lib/game_server/accounts.ex:342-350`.
- **Issue**: Every other user-row mutation in this module uses
  `invalidate_user_cache/1` (`Cache.invalidate` → cross-node broadcast, plus
  index keys). This hot login-path function instead calls
  `GameServer.Cache.delete({:accounts, :user, user_id})`, which clears only the
  local node's levels and does not broadcast. It sets `is_online: true` and
  `last_seen_at`, so on other nodes the cached struct keeps `is_online`/
  `last_seen_at` stale until the 60s TTL. (The `{:accounts, :user_by, …}` index
  keys resolve through a keyref to the primary, so omitting them is
  self-correcting locally, but not on other nodes where the primary was never
  deleted.)
- **Impact**: Multi-node presence wrongness (a user shows offline / stale
  last-seen to lookups served by other nodes) for up to 60s; inconsistent with
  the rest of the module. Single-node: fine.
- **Fix**: Use `invalidate_user_cache_by_id/1` (or `Cache.invalidate`) here for
  consistency with all other user mutations.
- **Confidence**: High.

### KV list/count caches are the only invalidation for cross-scope reads and rely on non-broadcast, async version bumps

- **Location**: `apps/game_server_core/lib/game_server/kv.ex:131-174`
  (`invalidate_entries_cache/2`, wrapped in `GameServer.Async.run`),
  read sites `kv.ex:323-365` (`list_entries`), `kv.ex:374-404` (`count_entries`).
- **Issue**: Beyond the multi-node `incr` limitation (High #2), the KV version
  bumps run inside `GameServer.Async.run`, so even on the **same node** the
  version increment can land *after* a write returns. A read issued immediately
  after `put/4`/`delete/2` on the same node can still see the pre-bump version
  and serve a stale `list_entries`/`count_entries` snapshot until the 60s data
  TTL. (Single-key `get/2` is fine — it uses `cache_put`/`invalidate` with a
  broadcast, `kv.ex:305,549,590-606`.)
- **Impact**: Stale admin/browse listings and counts right after a mutation;
  also feeds `check_kv_entries_limit/1` (see Low below). Bounded by 60s.
- **Fix**: Provide a synchronous bump variant for the same-request-then-read
  pattern (as groups does with `invalidate_invite_cache_sync/1`), and/or broadcast
  the bump per High #2.
- **Confidence**: Medium.

### Global achievements version counter has no user/scope partitioning

- **Location**: `apps/game_server_core/lib/game_server/achievements.ex:41-49`,
  keys at `achievements.ex:210-211,307-308,315-316`.
- **Issue**: A single global `{:achievements, :version}` counter gates
  `list_all`, `count_all`, and `count_public`. Any achievement mutation bumps it,
  invalidating all three globally — correct, but combined with High #2 the global
  counter is stale on other nodes and every achievements list/count read there is
  served from the old version until the 60s TTL. Because it is global (not
  per-entity), the staleness applies to all consumers simultaneously.
- **Impact**: Multi-node: newly created/edited achievements missing from listings
  for up to 60s across other nodes. Bounded.
- **Fix**: Covered by broadcasting version bumps (High #2). No key-shape change
  needed.
- **Confidence**: Medium.

## Low

### `delete_user_session_token/1` does not evict the id-keyed token cache

- **Location**: `apps/game_server_core/lib/game_server/accounts.ex:1569-1573`
  vs cache at `accounts.ex:1577-1584` (`get_user_token/1`, `ttl: 60_000`) and the
  proper eviction in `delete_user_token/1` (`accounts.ex:1596-1606`) /
  `revoke_all_user_sessions/1` (`accounts.ex:1635-1652`).
- **Issue**: Logout deletes the session token by its token bytes but never
  invalidates `{:accounts, :user_token, id}`. The cached `UserToken` lingers up to
  60s. `get_user_token/1` is not on the session-verification path
  (`get_user_by_session_token/1` hits the DB directly, `accounts.ex:1450-1454`),
  so this only surfaces in the admin sessions/users LiveViews that call
  `get_user_token!/1`.
- **Impact**: Admin UI may show an already-deleted session for up to 60s. No auth
  impact.
- **Fix**: Look up the token id (or `revoke`-style delete) and `Cache.invalidate`
  it in `delete_user_session_token/1`.
- **Confidence**: High.

### OAuth session read caches `nil` (negative caching) for 30s

- **Location**: `apps/game_server_core/lib/game_server/oauth_sessions.ex:40-46`
  (`get_session_cached/1`, no `:match`).
- **Issue**: Missing sessions are cached as `nil` for 30s. `create_session/1` and
  `update_session/2` `invalidate` cross-node (`oauth_sessions.ex:12-15,27,61`), so
  a normal create-then-read converges; but a read that beats the create and caches
  `nil`, on a node that also misses the invalidate broadcast, would report the
  session missing for up to 30s.
- **Impact**: Rare OAuth callback flakiness on multi-node. Bounded 30s.
- **Fix**: Add `match: &(&1 != nil)` so misses aren't cached (consistent with the
  `cache_match` pattern used for users/groups/lobbies).
- **Confidence**: Medium.

### KV per-user entry-limit check reads a cached, possibly stale count

- **Location**: `apps/game_server_core/lib/game_server/kv.ex:431-440`
  (`check_kv_entries_limit/1` → cached `count_entries(user_id: …)`).
- **Issue**: The quota gate reads the version-counter-cached count. Because bumps
  are async (Medium above) and non-broadcast (High #2), rapid sequential creates
  or concurrent creates across nodes can each read a stale low count and admit
  more than `max_kv_entries_per_user`.
- **Impact**: Soft quota can be exceeded by a small margin. Not a correctness/
  security boundary.
- **Fix**: Enforce the cap with a DB-side count or constraint on the write path
  rather than a cached read.
- **Confidence**: Medium.

### `CACHE_ENABLED` is honored only in prod; stale integer typespecs/docs post-UUID

- **Location**: `config/host_runtime.exs:102-103,189-190` (`bypass_mode:
  not cache_enabled` is set only under `config_env() == :prod`). Stale
  annotations: `kv.ex:46-52,65-72` (`pos_integer()` for `user_id`/`lobby_id`/ids),
  `kv.ex:410` (`get_entry(pos_integer())`), `leaderboards.ex:1049-1052`
  (`delete_user_record` doc/spec says integer id),
  `user_controller.ex:145-146` (variable named `int_id` holding a UUID string).
- **Issue**: (a) `CACHE_ENABLED=false` disables the cache correctly and uniformly
  in prod — `bypass_mode` routes through the single `GameServer.Cache` module so
  both decorators and manual `get!/put/incr/invalidate` are bypassed — but the env
  var is not read in dev/test, so toggling it there is a silent no-op. (b) No cache
  *key* depends on integer ids (they pass through the id value, now UUID strings),
  so these are documentation/typespec drift, not runtime cache bugs.
- **Impact**: Minor operator confusion (dev toggle) and misleading specs/docs.
- **Fix**: Read `CACHE_ENABLED` outside the prod-only block if a dev toggle is
  desired; refresh the `pos_integer()`/integer annotations and the `int_id`
  name to reflect UUID strings.
- **Confidence**: High.
