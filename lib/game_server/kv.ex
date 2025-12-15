defmodule GameServer.KV do
  @moduledoc """
  Generic key/value storage.

  This is intentionally minimal and un-opinionated.

  If you want namespacing, encode it in `key` (e.g. `"polyglot_pirates:key1"`).
  If you want per-user values, pass `user_id: ...` to `get/2`, `put/4`, and `delete/2`.

  This module uses the app cache (`GameServer.Cache`) as a best-effort read cache.
  Writes update the cache and deletes evict it.
  """

  import Ecto.Query

  alias GameServer.KV.Entry
  alias GameServer.Repo

  @kv_cache_ttl_ms 60_000

  @spec get(String.t(), keyword()) :: {:ok, %{value: map(), metadata: map()}} | :error
  def get(key, opts \\ []) when is_binary(key) and is_list(opts) do
    user_id = Keyword.get(opts, :user_id)

    cached = GameServer.Cache.get(cache_key(key, user_id))

    if is_map(cached) and Map.has_key?(cached, :value) and Map.has_key?(cached, :metadata) do
      {:ok, cached}
    else
      case fetch_entry(key, user_id) do
        nil ->
          :error

        %Entry{value: value, metadata: metadata} ->
          payload = %{value: value, metadata: metadata}
          _ = GameServer.Cache.put(cache_key(key, user_id), payload, ttl: @kv_cache_ttl_ms)
          {:ok, payload}
      end
    end
  end

  @spec put(String.t(), map(), map()) :: {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def put(key, value, metadata \\ %{})
      when is_binary(key) and is_map(value) and is_map(metadata) do
    put(key, value, metadata, [])
  end

  @spec put(String.t(), map(), map(), keyword()) ::
          {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def put(key, value, metadata, opts)
      when is_binary(key) and is_map(value) and is_map(metadata) and is_list(opts) do
    user_id = Keyword.get(opts, :user_id)

    changeset =
      Entry.changeset(%Entry{}, %{key: key, user_id: user_id, value: value, metadata: metadata})

    try do
      case Repo.insert(changeset) do
        {:ok, entry} ->
          _ = cache_put(key, user_id, entry)
          {:ok, entry}

        {:error, %Ecto.Changeset{} = insert_changeset} ->
          if unique_constraint_error?(insert_changeset) do
            case update_existing(key, user_id, value, metadata) do
              {:ok, entry} ->
                _ = cache_put(key, user_id, entry)
                {:ok, entry}

              other ->
                other
            end
          else
            {:error, insert_changeset}
          end
      end
    rescue
      e in Ecto.ConstraintError ->
        if Map.get(e, :type) in [:unique, :unique_constraint] do
          case update_existing(key, user_id, value, metadata) do
            {:ok, entry} ->
              _ = cache_put(key, user_id, entry)
              {:ok, entry}

            other ->
              other
          end
        else
          reraise(e, __STACKTRACE__)
        end
    end
  end

  @spec delete(String.t(), keyword()) :: :ok
  def delete(key, opts \\ []) when is_binary(key) and is_list(opts) do
    user_id = Keyword.get(opts, :user_id)
    _ = GameServer.Cache.delete(cache_key(key, user_id))
    _ = Repo.delete_all(entry_query(key, user_id))
    :ok
  end

  defp cache_key(key, nil), do: {:kv, :global, key}
  defp cache_key(key, user_id), do: {:kv, user_id, key}

  defp cache_put(key, user_id, %Entry{} = entry) do
    GameServer.Cache.put(
      cache_key(key, user_id),
      %{value: entry.value, metadata: entry.metadata},
      ttl: @kv_cache_ttl_ms
    )
  end

  defp update_existing(key, user_id, value, metadata) do
    case fetch_entry(key, user_id) do
      nil ->
        {:error,
         Entry.changeset(%Entry{}, %{key: key, user_id: user_id, value: value, metadata: metadata})}

      %Entry{} = entry ->
        entry
        |> Entry.changeset(%{value: value, metadata: metadata})
        |> Repo.update()
    end
  end

  defp fetch_entry(key, user_id) do
    Repo.one(entry_query(key, user_id))
  end

  defp entry_query(key, nil) do
    from(e in Entry, where: e.key == ^key and is_nil(e.user_id))
  end

  defp entry_query(key, user_id) do
    from(e in Entry, where: e.key == ^key and e.user_id == ^user_id)
  end

  defp unique_constraint_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_field, {_msg, meta}} -> meta[:constraint] == :unique end)
  end
end
