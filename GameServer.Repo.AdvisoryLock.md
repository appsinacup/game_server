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

You can also pass an arbitrary string as the namespace. The string is
hashed to a stable 32-bit integer via `:erlang.phash2/2`, so any
string (e.g. `"word_guessed"`, `"my_rpc"`) works without pre-registration.

## Examples

    # Atom namespace (predefined):
    AdvisoryLock.lock(:lobby, lobby_id)

    # String namespace (ad-hoc):
    AdvisoryLock.lock("word_guessed", lobby_id)

# `lock`

```elixir
@spec lock(atom() | String.t(), integer()) :: :ok
```

Acquire a transaction-scoped advisory lock for the given resource.

`namespace` can be a predefined atom (`:lobby`, `:group`, `:party`) or any
arbitrary string. `resource_id` must be a non-negative integer.

Must be called inside a `Repo.transaction`. On PostgreSQL, blocks until
the lock is available. On SQLite, returns immediately.

# `postgres?`

```elixir
@spec postgres?() :: boolean()
```

Returns true if the Repo was compiled with the PostgreSQL adapter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
