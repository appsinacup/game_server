# Database & Data-Integrity Audit — gamend

Scope: every migration in `apps/game_server_core/priv/repo/migrations/` and every
schema/context under `apps/game_server_core/lib/game_server/`. Dual adapter
(SQLite default, Postgres). IDs recently migrated to UUIDv7 `binary_id` via
`GameServer.Repo.init/2` (`migration_primary_key`/`migration_foreign_key`) and the
`GameServer.Schema` macro.

## Summary

The schema is generally well-indexed and the UUID migration is clean: no leftover
`serial`/`AUTOINCREMENT`/integer PKs, all FKs are `binary_id` on both sides, the
polymorphic `chat_ref_id` is correctly typed `:binary_id`. Adapter branching
(citext, JSON functions, table rebuilds, advisory locks) is handled deliberately.

The material findings are: (1) two hot user-presence queries have no supporting
index, (2) the friend-request flow is the one mutation path that does check-then-write
**without** the advisory lock every other capacity/dedup path uses — a real race on
Postgres, (3) a composite leaderboard index is silently dropped by the SQLite
table-rebuild migration, (4) group search filters on an un-indexed expression, and
(5) polymorphic chat rows are orphaned on parent deletion because they have no FK.

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High     | 3 |
| Medium   | 4 |
| Low      | 3 |

---

## High

### Friend-request create is a TOCTOU race without the advisory lock

- **Location** `apps/game_server_core/lib/game_server/friends.ex:218-238` (`create_request/2`); dedup helpers `blocked?/2`, `already_friends?/2`, `same_direction_pending?/2`, `find_pending_reverse/2` at `friends.ex:311-374`; unique index `friendships.ex` migration `20251126000000_create_friendships.exs:14` (`unique_requester_target` on `[:requester_id, :target_id]` only).
- **Issue** `create_request` runs its checks and insert inside `Repo.transaction` but, unlike every other capacity/dedup mutation in the codebase (lobbies `lobbies.ex:530`, groups `groups.ex:666`, parties `parties.ex:265`, group joins `join_requests.ex:183`), it does **not** call `AdvisoryLock.lock/2`. The unique index only covers the same direction `(requester_id, target_id)`. It does not prevent `A→B` and `B→A` rows from both existing.
- **Impact** On Postgres (READ COMMITTED) two concurrent requests in opposite directions both read "no existing row / no pending reverse" and both `INSERT`, producing two reciprocal `pending` friendships instead of the intended single auto-accept. Neither side ever auto-accepts; the pair is stuck with duplicate pending requests, and later `accept` on one leaves the other dangling. Also lets `pending_count` cap (`friends.ex:290`) be exceeded under concurrency. Safe on SQLite only because it serializes writes.
- **Fix** Wrap the body in `AdvisoryLock.lock(:friendship, canonical_pair_id)` where `canonical_pair_id` is the sorted `min(requester,target)<>max(...)` so both directions hash to the same lock, matching the pattern used elsewhere. Alternatively add a unique index on the canonicalized pair.
- **Confidence** High (lock absence and index shape both confirmed).
- **Adapter** Postgres (race); both (missing canonical uniqueness).

### No index for the user online-presence queries (full scans every 2 min)

- **Location** query sites `apps/game_server_core/lib/game_server/accounts/stale_presence_sweeper.ex:91-95` (`is_online == true AND (last_seen_at IS NULL OR last_seen_at < cutoff)`), `accounts.ex:291` (`count(... where is_online == true)`), `accounts.ex:308-313` (recently-active by `last_seen_at`). Columns added in `20260220120000_add_online_status_to_users.exs` with **no index**.
- **Issue** `is_online` and `last_seen_at` are queried on the `users` table (the largest table) but neither is indexed.
- **Impact** `StalePresenceSweeper.do_sweep/1` runs every 2 minutes (`@default_interval_ms 120_000`) and does a full `users` scan; `count_online_users` and the recently-active count also full-scan. Cost grows linearly with total registered users regardless of how few are online.
- **Fix** Add `create index(:users, [:is_online])` (or a partial `where: "is_online = true"` on Postgres, and `create index(:users, [:last_seen_at])` for the recently-active count). A partial index on `is_online = true` is the highest-value option for the sweeper and online count.
- **Confidence** High (confirmed no index on these columns).
- **Adapter** both.

### `leaderboard_records` composite score index is dropped on SQLite

- **Location** `20260315120000_add_label_to_leaderboard_records.exs:20-45` (SQLite `else` branch rebuilds the table and re-creates only `unique_index [:leaderboard_id, :user_id]` and `index [:leaderboard_id, :score]`); the missing index was created in `20251214171000_add_leaderboards_query_indexes.exs:12` as `index [:leaderboard_id, :score, :updated_at]`. Query that wants it: `leaderboards.ex:912-924` (order by score then `updated_at` tiebreaker).
- **Issue** The SQLite `DROP TABLE leaderboard_records` + rename rebuilds indexes from scratch but omits the 3-column `(leaderboard_id, score, updated_at)` index. On Postgres the `ALTER` path preserves it; on SQLite it is permanently lost after this migration.
- **Impact** Leaderboard ranking queries on SQLite fall back to the 2-column `(leaderboard_id, score)` index and must sort on `updated_at` within equal scores. Modest for small boards, but it is a silent divergence between adapters and a lost index the team explicitly added.
- **Fix** In the SQLite branch of the `up`, also `create index(:leaderboard_records, [:leaderboard_id, :score, :updated_at])` after the rename. (A follow-up idempotent migration with `create_if_not_exists` is the safest remediation now that the rebuild has shipped.)
- **Confidence** High (index list in the rebuild is explicit and omits it).
- **Adapter** SQLite.

---

## Medium

### Group title search filters on an un-indexed `lower(title)` expression

- **Location** `apps/game_server_core/lib/game_server/groups.ex:1111-1112` (`fragment("lower(?) LIKE ? ESCAPE '\\'", g.title, ^prefix)`). `groups` has only `unique_index [:title]` (plain) from `20260223213820_drop_groups_name_column.exs:9`; there is no `lower(title)` expression index, unlike users (`20251214144500_add_prefix_search_indexes.exs:5` `lower(display_name)`) and lobbies (`:6` `lower(title)`).
- **Issue** Group search lowercases the column, so the plain `unique_index(:groups, [:title])` cannot serve it; every group search is a full scan.
- **Impact** Full `groups` scan per search request. Parallel to the users/lobbies search which were given expression indexes.
- **Fix** `create index(:groups, ["lower(title)"])` to match the other two search paths.
- **Confidence** High (index absence confirmed).
- **Adapter** both.

### Polymorphic `chat_ref_id` / read-cursor rows are orphaned on parent deletion

- **Location** `20260226120000_create_chat_messages.exs` — `chat_messages.chat_ref_id :binary_id` (no FK) and `chat_read_cursors.chat_ref_id :binary_id` (no FK). Deletion paths: groups `groups.ex handle_user_deletion` / group delete, lobby delete, and user delete (`accounts.ex:1695`). Friend-DM messages store the *other* user in `chat_ref_id`.
- **Issue** Because `chat_ref_id` is polymorphic it has no foreign key, so no cascade fires when the referenced group, lobby, or user is deleted. `chat_messages.sender_id` cascades (sender's own messages go), but messages/cursors keyed by `chat_ref_id` do not. Group- and lobby-scoped chat history and read cursors survive their parent; friend DMs *sent to* a deleted user survive (the deleted user's own sent messages are removed via `sender_id` cascade, leaving a half-conversation).
- **Impact** Unbounded orphan accumulation in `chat_messages`/`chat_read_cursors` for deleted groups/lobbies/users; only mitigated by `Retention` age-based pruning **if** `RETENTION_CHAT_DAYS` is configured (`retention.ex:74`), which is off by default (`0` keeps forever).
- **Fix** Add explicit cleanup of `chat_messages`/`chat_read_cursors` by `(chat_type, chat_ref_id)` in the group/lobby/user deletion paths (cannot be a DB FK given the polymorphic column). Document that retention is the only backstop.
- **Confidence** High (no FK on the column; deletion paths don't clean it).
- **Adapter** both.

### Prefix-`LIKE` expression indexes may not be used under default Postgres collation

- **Location** search sites `accounts.ex:128`, `accounts.ex:171`, `lobbies.ex:360`, `groups.ex:1112`; indexes `20251214144500_add_prefix_search_indexes.exs` (`lower(display_name)`, `lower(title)`).
- **Issue** All use `lower(col) LIKE 'prefix%'`. On Postgres a plain b-tree index (even an expression index) is only used for `LIKE 'x%'` when the index uses `text_pattern_ops`/`varchar_pattern_ops` or the DB is in the `C` locale. The current indexes are plain, so on a default-collation Postgres these prefix searches may still seq-scan. On SQLite, the default `LIKE` is case-insensitive and won't use the expression index either unless `case_sensitive_like` is on (the `lower()` on both sides is what makes results correct, not what makes the index usable).
- **Impact** The intended index acceleration for user/lobby/group prefix search may not materialize on Postgres; effectively the searches are seq scans in production. Speculative on exact planner behavior; worth an `EXPLAIN` check.
- **Fix** On Postgres, create the expression indexes with `text_pattern_ops`, e.g. `execute("CREATE INDEX ... ON users (lower(display_name) text_pattern_ops)")` in the Postgres branch; verify with `EXPLAIN`.
- **Confidence** Medium (depends on deployed collation; behavior is planner-dependent).
- **Adapter** Postgres primarily (SQLite prefix-LIKE index use is also collation-dependent).

### `notifications` list filter+sort has no single covering index

- **Location** indexes in `20260222120000_create_notifications.exs:13-15` (`[:recipient_id]`, `[:recipient_id, :inserted_at]`) and `20260301101746_add_read_to_notifications.exs:10` (`[:recipient_id, :read]`). Typical listing filters `recipient_id` + `read` and orders by `inserted_at`.
- **Issue** A query that filters `recipient_id AND read` and orders by `inserted_at` cannot satisfy both filter and sort from one index — the planner picks `(recipient_id, read)` then sorts, or `(recipient_id, inserted_at)` then filters.
- **Impact** Extra sort/filter step on the notifications list; minor unless a user has many notifications.
- **Fix** If unread-then-newest is the hot path, add `index(:notifications, [:recipient_id, :read, :inserted_at])`.
- **Confidence** Medium (depends on exact list query shape).
- **Adapter** both.

---

## Low

### `notifications.metadata` is nullable but the upsert assumes a JSON value

- **Location** `20260222120000_create_notifications.exs:9` (`add :metadata, :map, default: %{}` — no `null: false`); upsert `notifications.ex:522-540` (`jsonb_set(?, '{message_count}', ...)` on Postgres).
- **Issue** Unlike most other `:map` columns in the schema, notifications `metadata` allows NULL. `jsonb_set(NULL, ...)` returns NULL, silently discarding the `message_count` increment for any row whose metadata is NULL.
- **Impact** Chat-notification message counts can silently reset to NULL rather than incrementing. Low likelihood since inserts default to `%{}`, but the constraint gap is real.
- **Fix** Add `null: false` (backfill NULL→`'{}'` first) or `COALESCE(?, '{}'::jsonb)` in the fragment.
- **Confidence** Medium.
- **Adapter** Postgres (fragment); both for the constraint gap.

### `oauth_sessions` has no retention/cleanup and no status index

- **Location** `20251124120000_create_oauth_sessions.exs` (only `unique_index [:session_id]`); not referenced in `retention.ex:56-62`.
- **Issue** OAuth session rows are never pruned and only indexed by `session_id`. Completed/expired sessions accumulate forever.
- **Impact** Slow unbounded growth of a transient table. Low.
- **Fix** Add an age-based prune step in `Retention.prune_all/0` (mirrors chat/notifications) keyed on `inserted_at`.
- **Confidence** High (no cleanup path exists).
- **Adapter** both.

### `returning: true` upsert on SQLite depends on a recent SQLite version

- **Location** `notifications.ex:459` (`returning: true` in `Repo.insert`), also relied on implicitly by RETURNING-based inserts.
- **Issue** `RETURNING` requires SQLite ≥ 3.35. `ecto_sqlite3` supports it, but a pinned older `exqlite`/system SQLite would fail at runtime.
- **Impact** Environment-dependent; only bites on an old SQLite build. Low.
- **Fix** Document/pin the minimum SQLite version, or drop `returning: true` and re-fetch (as the leaderboard/KV paths already do).
- **Confidence** Low (version-dependent).
- **Adapter** SQLite.

---

## Verified clean (no finding)

- **UUID migration integrity**: no `serial`/`bigserial`/`AUTOINCREMENT`; the one raw-SQL rebuild (`20260315120000`) uses `TEXT` PK/FKs consistent with `binary_id`. FKs are `binary_id` on both sides throughout. `chat_ref_id`/`schedule_locks.id` explicitly typed.
- **Constraint-name matches**: every `unique_constraint/2` name matches its migration index name — `chat_read_cursors_user_type_ref`, `group_invites_recipient_id_group_id_index`, `party_invites_sender_id_recipient_id_index`, `kv_entries_unique_*`, `entitlements_user_id_key_index`, `purchases_unique_provider_transaction`, `unique_requester_target`, `notifications_sender_id_recipient_id_title_index`, `parties_leader_id_index`. No silent-failure mismatches found.
- **Advisory-lock coverage**: lobby join/kick/host-transfer, group join/leave/join-request, party join/create/leave, and the KV read-modify-write RPC path all wrap check-then-write in `Repo.transaction` + `AdvisoryLock.lock`. SQLite no-op path is safe (writes serialized). Friends is the sole exception (see High).
- **`on_conflict` correctness**: KV partial-unique targets include the matching `WHERE` predicate (`kv.ex:277-291`) so partial-index inference works on both adapters; leaderboard/notification/chat-cursor/group-notification conflict targets match their unique indexes; adapter-specific JSON functions branched correctly (`notifications.ex:522`).
- **FK cascade map (relational tables)**: user deletion cascades cleanly through tokens, friendships, leaderboard_records, notifications, group_members/join_requests/invites, party_invites, kv_entries, user_achievements, entitlements, and (as leader) parties; purchases nilify to preserve financial history. The gap is only the FK-less polymorphic chat tables (see Medium).
- **Retention job**: age-based deletes use `inserted_at` (indexed on notifications; chat_messages has `(chat_type, chat_ref_id, inserted_at)` but no standalone `inserted_at` index — acceptable given retention runs every 6h off-peak, not a hot path). No long transaction; single `delete_all` per table.
