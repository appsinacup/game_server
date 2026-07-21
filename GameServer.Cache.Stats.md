# `GameServer.Cache.Stats`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/cache/stats.ex#L1)

Lightweight in-memory counters for cache effectiveness and overload signals,
aggregated from telemetry events:

- `[:game_server, :cache, :command, :stop]` — cache reads (`:fetch`), keyed
  by the first element of the cache key tuple (`:accounts`, `:kv`, …),
  classified as hit or miss.
- `[:game_server, :rate_limit, :deny]` — rate-limiter denials by scope.
- `[:game_server, :async, :overload]` — async tasks run inline because the
  task supervisor was at capacity.

Counters live in a public ETS table written via `:ets.update_counter` from
the telemetry handler (caller process), so the hot path never crosses a
process boundary. `snapshot/0` powers the admin dashboard panel; the same
events feed Prometheus via `GameServerWeb.PromEx.CachePlugin`.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `reset`

```elixir
@spec reset() :: :ok
```

Resets all counters (admin dashboard action).

# `snapshot`

```elixir
@spec snapshot() :: map()
```

Returns aggregated counters:

    %{
      cache: [%{prefix: :accounts, hits: 10, misses: 2, hit_rate: 0.83}, ...],
      rate_limit_denies: %{"auth" => 3, ...},
      async_overloads: 0
    }

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
