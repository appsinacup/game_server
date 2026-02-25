# `GameServer.Repo.AdvisoryLock`

Advisory locking for protecting TOCTOU (Time-of-Check-Time-of-Use) patterns.

On PostgreSQL, acquires a transaction-scoped advisory lock via
`pg_advisory_xact_lock(namespace, resource_id)`. The lock is automatically
released when the enclosing `Repo.transaction` commits or rolls back.

On SQLite, this is a no-op — SQLite serializes all writes at the
database level, so advisory locks are unnecessary.

## Usage

Always call within a `Repo.transaction`:

    Repo.transaction(fn ->
      AdvisoryLock.lock(:lobby, lobby.id)
      count = count_members(lobby.id)
      if count >= lobby.max_users, do: Repo.rollback(:full)
      do_join(...)
    end)

## Namespaces

Each resource type uses a distinct integer namespace to avoid collisions:

- `:lobby` → 1
- `:group` → 2
- `:party` → 3

# `lock`

```elixir
@spec lock(atom(), integer()) :: :ok
```

Acquire a transaction-scoped advisory lock for the given resource.

Must be called inside a `Repo.transaction`. On PostgreSQL, blocks until
the lock is available. On SQLite, returns immediately.

# `postgres?`

```elixir
@spec postgres?() :: boolean()
```

Returns true if the current Repo adapter is PostgreSQL.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
