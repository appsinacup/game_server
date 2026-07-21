# `GameServer.Retention`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/retention.ex#L1)

Periodically prunes old rows from unbounded tables.

Retention is configured per table in days via env vars (see
`config/host_runtime.exs`); `0` or unset keeps data forever:

- `RETENTION_CHAT_DAYS` — `chat_messages` older than N days
- `RETENTION_NOTIFICATIONS_DAYS` — `notifications` older than N days
- `RETENTION_PAYMENT_EVENTS_DAYS` — payment provider webhook events older
  than N days (purchases/entitlements are never pruned)
- `RETENTION_LOBBY_SNAPSHOTS_DAYS` — lobby snapshots, events and their
  content blobs. Unlike the others this defaults to 30 rather than "keep
  forever": snapshots hold user metadata, and the window is what bounds that
  exposure. Runs flagged anomalous keep
  `RETENTION_LOBBY_SNAPSHOTS_FLAGGED_DAYS` instead (default 90).

Expired IP bans and OAuth sessions older than a day are always removed
(independent of the env vars above). Deletes are idempotent, so running on
several instances at once is harmless.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `prune_all`

```elixir
@spec prune_all() :: %{required(atom()) =&gt; non_neg_integer()}
```

Runs all configured pruning steps once. Returns a map of deleted row
counts per table.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
