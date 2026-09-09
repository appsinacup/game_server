# `Gamend.Analytics`
[🔗](https://github.com/appsinacup/gamend/blob/v1.0.7/lib/gamend/analytics.ex#L1)

The one place aggregate numbers come from. Four families:

* **Activity & retention** — DAU / WAU / MAU, new users per day, strict
  D1 / D7 / D30 cohort retention, payer conversion. Derived from
  `user_activity_days` (one row per user per UTC day seen, written by
  `record_activity/2` from the `last_seen_at` touches in `Gamend.Accounts`),
  `users.inserted_at` for cohorts and `purchases` for payers.
* **Snapshot** — `snapshot/0`: every context's live counters (players,
  lobbies, parties, quests, signaling, matchmaking, tournaments) composed
  once and cached, so the public stats page, the admin index and the
  `/api/v1/stats` endpoint show the same numbers instead of each calling
  six modules.
* **Economy flow** — `economy_flow/2`: coins granted and spent per day per
  ledger `reason`, straight from `ledger_entries`.
* **Daily counters** — `count/3` + `counts/2`: named per-day counters for
  events that have no table of their own (a level finished, a start blocked
  by empty hearts). The game picks the keys; the engine sums them.

Days are UTC, like every other period boundary on the server. "D7" means
*seen on the 7th day after the registration day*, not "seen at any point in
the first week" — the classic strict definition, so numbers compare with
the ones stores and ad networks report.

Reads are cheap enough for a dashboard on a small database; the composed
views (`snapshot/0`, `dashboard_stats/0`) cache for a minute or a few.
Nothing here is exposed to players except through the operator-gated
public stats page.

# `rate`

```elixir
@type rate() :: float() | nil
```

# `active_users`

```elixir
@spec active_users(Date.t(), Date.t()) :: non_neg_integer()
```

Distinct users seen on any day in `from..to` (inclusive, UTC dates).

# `count`

```elixir
@spec count(String.t(), pos_integer(), DateTime.t()) :: :ok
```

Adds `n` to the counter `key` for the UTC day of `now`. One atomic
upsert-increment; safe to call from hot paths that already write (a level
end, a purchase), not from paths that otherwise only read.

Keys are dotted, game-owned strings up to 128 chars;
put a dimension after a colon (`"level.started.lang:ja"`) so `counts/2`
can pull a whole family by prefix. Never raises; a bad key is dropped.

# `count_totals`

```elixir
@spec count_totals(String.t(), pos_integer(), Date.t()) :: [{String.t(), integer()}]
```

Totals of `counts/3` per key over the window, largest first.

# `counts`

```elixir
@spec counts(String.t(), pos_integer(), Date.t()) :: %{
  required(String.t()) =&gt; %{required(Date.t()) =&gt; integer()}
}
```

Per-day values of one counter or a prefix family over the last `days` days
ending on `today`, as `%{key => %{Date => count}}`. `key` may end in `*` to
match a prefix (`"level.started.lang:*"`).

# `daily_series`

```elixir
@spec daily_series(pos_integer(), Date.t()) :: [map()]
```

One row per UTC day for the last `days` days ending on `today`, oldest
first: `%{day, active, new_users, d1, d7, d30}`. A retention rate is `nil`
when the cohort is empty or the horizon day has not happened yet.

# `dashboard_stats`

```elixir
@spec dashboard_stats() :: map()
```

`summary/0` cached for a few minutes, for the admin index.

# `dau`

```elixir
@spec dau(Date.t()) :: non_neg_integer()
```

Daily active users on `day` (default: today, UTC).

# `economy_flow`

```elixir
@spec economy_flow(pos_integer(), keyword()) :: [map()]
```

Currency granted and spent per UTC day per ledger `reason` over the last
`days` days: `[%{day, currency, reason, granted, spent, entries}]`, newest
first. `granted`/`spent` are positive integers (spent is the absolute
value of negative deltas). Options: `:currency` to filter.

# `economy_totals`

```elixir
@spec economy_totals(pos_integer(), keyword()) :: [map()]
```

`economy_flow/2` collapsed over the window: one row per `{currency,
reason}` with `granted`, `spent`, `net`, sorted by absolute net.

# `mau`

```elixir
@spec mau(Date.t()) :: non_neg_integer()
```

Monthly active users: distinct users seen in the 30 days ending on `day`.

# `new_users`

```elixir
@spec new_users(Date.t(), Date.t()) :: non_neg_integer()
```

Accounts created on any UTC day in `from..to` (inclusive).

# `payers_since`

```elixir
@spec payers_since(Date.t()) :: non_neg_integer()
```

Distinct users with a completed purchase since `from` (UTC date, inclusive).

# `record_activity`

```elixir
@spec record_activity(Ecto.UUID.t(), DateTime.t()) :: :ok
```

Records that `user_id` was seen on the UTC day of `now`. Idempotent; the
common case (already recorded today) is a single cache read. Never raises —
a missing user (deleted mid-request) is a silent no-op, like the
`last_seen_at` touch this rides along with.

# `snapshot`

```elixir
@spec snapshot() :: map()
```

Every context's live counters in one map, cached for a minute:

    %{
      players: %{players_online, players_total, players_offline, players_in_lobbies, players_in_parties},
      activity: %{dau, wau, mau, new_users_1d, new_users_7d, new_users_30d},
      lobbies: %{lobbies_total, by_state, spectators},
      parties: %{parties_active, players_in_parties},
      quests: %{quests_total, completed, claimed},
      signaling: %{rooms_enabled, rooms_active, peers_connected},
      matchmaking: %{queued, queues},
      tournaments: %{tournaments, entries, matches}
    }

Everything in it is safe to show publicly (the stats page is opt-in via
`:public_stats`); `matchmaking` is the already-public subset. Consumers
read this rather than calling the contexts, so the same number cannot
drift between two pages.

# `summary`

```elixir
@spec summary(Date.t()) :: map()
```

Headline numbers as of `today`: DAU / WAU / MAU, stickiness (DAU ÷ MAU),
new users in the last 7 and 30 days, D1 / D7 / D30 pooled over every cohort
of the last 60 days that is old enough to have reached
the horizon, and payer conversion (distinct users with a completed purchase
in the last 30 days ÷ MAU).

# `wau`

```elixir
@spec wau(Date.t()) :: non_neg_integer()
```

Weekly active users: distinct users seen in the 7 days ending on `day`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
