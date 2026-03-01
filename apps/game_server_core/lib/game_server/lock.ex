defmodule GameServer.Lock do
  @moduledoc """
  Serialized execution using database-level advisory locks.

  Wraps a function in a `Repo.transaction` with an advisory lock so that
  only one process at a time can execute the critical section for a given
  `(namespace, resource_id)` pair.

  This is useful for game RPCs where multiple players may trigger the same
  operation concurrently (e.g. guessing a word, claiming a reward) and the
  logic involves read-modify-write on KV entries or lobby metadata.

  ## How it works

  On **PostgreSQL**, the lock is acquired via `pg_advisory_xact_lock` and is
  automatically released when the transaction commits or rolls back. Other
  callers with the same key block until the lock is available.

  On **SQLite** (dev/test), advisory locks are a no-op because SQLite already
  serializes all writes at the database level.

  ## Multi-node safety

  Because the lock lives in the database, it works correctly across multiple
  application nodes — all nodes share the same Postgres instance, so the lock
  is globally consistent.

  ## Namespace conventions

  The `namespace` argument can be:

  - A **predefined atom**: `:lobby` (1), `:group` (2), `:party` (3)
  - An **arbitrary string**: hashed to a stable integer, e.g. `"word_guessed"`

  The `resource_id` is typically the lobby, group, or user id that scopes
  the lock.

  ## Examples

      # Serialize all "word_guessed" RPCs per lobby
      GameServer.Lock.serialize("word_guessed", lobby_id, fn ->
        {:ok, entry} = GameServer.KV.get("game_state", lobby_id: lobby_id)
        new_val = Map.update(entry.value, "guessed", [word], &[word | &1])
        GameServer.KV.put("game_state", new_val, %{}, lobby_id: lobby_id)
      end)

      # Using a predefined atom namespace
      GameServer.Lock.serialize(:lobby, lobby_id, fn ->
        # exclusive per-lobby operation
      end)

  ## Return value

  Returns `{:ok, result}` where `result` is the return value of the function,
  or `{:error, reason}` if the transaction rolls back.
  """

  alias GameServer.Repo
  alias GameServer.Repo.AdvisoryLock

  @doc """
  Execute `fun` inside a transaction with an advisory lock on `(namespace, resource_id)`.

  Only one process at a time can hold the lock for a given key pair. Other
  callers block until the lock is released (on transaction commit/rollback).

  Returns `{:ok, result}` on success or `{:error, reason}` on rollback.

  ## Parameters

  - `namespace` — atom (`:lobby`, `:group`, `:party`) or any string
  - `resource_id` — integer identifying the specific resource (e.g. lobby id)
  - `fun` — zero-arity function to execute while holding the lock
  """
  @spec serialize(atom() | String.t(), integer(), (-> result)) ::
          {:ok, result} | {:error, term()}
        when result: term()
  def serialize(namespace, resource_id, fun)
      when (is_atom(namespace) or is_binary(namespace)) and is_integer(resource_id) and
             is_function(fun, 0) do
    Repo.transaction(fn ->
      AdvisoryLock.lock(namespace, resource_id)
      fun.()
    end)
  end
end
