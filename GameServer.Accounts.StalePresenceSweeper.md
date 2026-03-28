# `GameServer.Accounts.StalePresenceSweeper`

Periodically sweeps users whose `is_online` flag is `true` but whose
`last_seen_at` timestamp is older than a configurable threshold.

This is a safety net for node crashes or ungraceful disconnects where the
`UserChannel.terminate/2` callback never fires. Without this, users would
remain marked as online indefinitely.

## Configuration

    config :game_server_core, GameServer.Accounts.StalePresenceSweeper,
      interval_ms: 120_000,       # how often to run the sweep (default 2 min)
      stale_threshold_s: 300,     # mark offline if last_seen > 5 min ago
      enabled: true               # set false to disable the sweep entirely

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `config`

```elixir
@spec config() :: keyword()
```

Returns the current configuration used by the sweeper.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
