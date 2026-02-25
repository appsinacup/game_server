defmodule GameServer.Repo.AdvisoryLock do
  @moduledoc """
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
  """

  @namespaces %{lobby: 1, group: 2, party: 3}

  @doc """
  Acquire a transaction-scoped advisory lock for the given resource.

  Must be called inside a `Repo.transaction`. On PostgreSQL, blocks until
  the lock is available. On SQLite, returns immediately.
  """
  @spec lock(atom(), integer()) :: :ok
  def lock(namespace, resource_id)
      when is_atom(namespace) and is_integer(resource_id) do
    ns = Map.fetch!(@namespaces, namespace)

    if postgres?() do
      GameServer.Repo.query!("SELECT pg_advisory_xact_lock($1, $2)", [ns, resource_id])
    end

    :ok
  end

  @doc "Returns true if the current Repo adapter is PostgreSQL."
  @spec postgres?() :: boolean()
  def postgres? do
    # Use runtime config lookup to avoid compile-time type comparison warnings
    # when the default adapter is SQLite3.
    GameServer.Repo.config()[:adapter] == Ecto.Adapters.Postgres
  end
end
