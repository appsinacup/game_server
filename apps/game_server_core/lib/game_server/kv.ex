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

  defp entries_cache_version(:all) do
    GameServer.Cache.get({:kv, :entries_version, :all}) || 1
  end

  defp entries_cache_version(user_id) when is_integer(user_id) do
    GameServer.Cache.get({:kv, :entries_version, user_id}) || 1
  end

  defp invalidate_entries_cache(nil) do
    _ = GameServer.Cache.incr({:kv, :entries_version, :all}, 1, default: 1)
    :ok
  end

  defp invalidate_entries_cache(user_id) when is_integer(user_id) do
    _ = GameServer.Cache.incr({:kv, :entries_version, :all}, 1, default: 1)
    _ = GameServer.Cache.incr({:kv, :entries_version, user_id}, 1, default: 1)
    :ok
  end

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
          _ = invalidate_entries_cache(user_id)
          {:ok, entry}

        {:error, %Ecto.Changeset{} = insert_changeset} ->
          if unique_constraint_error?(insert_changeset) do
            case update_existing(key, user_id, value, metadata) do
              {:ok, entry} ->
                _ = cache_put(key, user_id, entry)
                _ = invalidate_entries_cache(user_id)
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
        cond do
          Map.get(e, :type) == :foreign_key ->
            {:error, Ecto.Changeset.add_error(changeset, :user_id, "does not exist")}

          Map.get(e, :type) in [:unique, :unique_constraint] ->
            case update_existing(key, user_id, value, metadata) do
              {:ok, entry} ->
                _ = cache_put(key, user_id, entry)
                _ = invalidate_entries_cache(user_id)
                {:ok, entry}

              other ->
                other
            end

          true ->
            reraise(e, __STACKTRACE__)
        end
    end
  end

  @spec delete(String.t(), keyword()) :: :ok
  def delete(key, opts \\ []) when is_binary(key) and is_list(opts) do
    user_id = Keyword.get(opts, :user_id)
    _ = GameServer.Cache.delete(cache_key(key, user_id))
    _ = Repo.delete_all(entry_query(key, user_id))
    _ = invalidate_entries_cache(user_id)
    :ok
  end

  @spec list_entries(keyword()) :: [Entry.t()]
  def list_entries(opts \\ []) when is_list(opts) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 50)
    user_id = Keyword.get(opts, :user_id)
    key_filter = normalize_key_filter(Keyword.get(opts, :key))

    version =
      if is_integer(user_id),
        do: entries_cache_version(user_id),
        else: entries_cache_version(:all)

    cache_key = {:kv, :list_entries, version, user_id, key_filter, page, page_size}

    case GameServer.Cache.get(cache_key) do
      entries when is_list(entries) ->
        entries

      _ ->
        query =
          from(e in Entry,
            order_by: [desc: e.updated_at, desc: e.id]
          )
          |> maybe_filter_user(user_id)
          |> maybe_filter_key(key_filter)

        entries =
          Repo.all(
            from(e in query,
              offset: ^((page - 1) * page_size),
              limit: ^page_size
            )
          )

        _ = GameServer.Cache.put(cache_key, entries, ttl: @kv_cache_ttl_ms)
        entries
    end
  end

  @spec count_entries(keyword()) :: non_neg_integer()
  def count_entries(opts \\ []) when is_list(opts) do
    user_id = Keyword.get(opts, :user_id)
    key_filter = normalize_key_filter(Keyword.get(opts, :key))

    version =
      if is_integer(user_id),
        do: entries_cache_version(user_id),
        else: entries_cache_version(:all)

    cache_key = {:kv, :count_entries, version, user_id, key_filter}

    case GameServer.Cache.get(cache_key) do
      count when is_integer(count) ->
        count

      _ ->
        count =
          Entry
          |> maybe_filter_user(user_id)
          |> maybe_filter_key(key_filter)
          |> Repo.aggregate(:count)

        _ = GameServer.Cache.put(cache_key, count, ttl: @kv_cache_ttl_ms)
        count
    end
  end

  @spec get_entry(pos_integer()) :: Entry.t() | nil
  def get_entry(id) when is_integer(id) and id > 0 do
    Repo.get(Entry, id)
  end

  @spec create_entry(map()) :: {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def create_entry(attrs) when is_map(attrs) do
    changeset = Entry.changeset(%Entry{}, attrs)

    try do
      case Repo.insert(changeset) do
        {:ok, entry} ->
          _ = cache_put(entry.key, entry.user_id, entry)
          _ = invalidate_entries_cache(entry.user_id)
          {:ok, entry}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:error, changeset}
      end
    rescue
      e in Ecto.ConstraintError ->
        cond do
          Map.get(e, :type) == :foreign_key ->
            {:error, Ecto.Changeset.add_error(changeset, :user_id, "does not exist")}

          Map.get(e, :type) in [:unique, :unique_constraint] ->
            {:error, Ecto.Changeset.add_error(changeset, :key, "has already been taken")}

          true ->
            reraise(e, __STACKTRACE__)
        end
    end
  end

  @spec update_entry(pos_integer(), map()) ::
          {:ok, Entry.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def update_entry(id, attrs) when is_integer(id) and id > 0 and is_map(attrs) do
    case Repo.get(Entry, id) do
      nil ->
        {:error, :not_found}

      %Entry{} = entry ->
        old_cache_key = cache_key(entry.key, entry.user_id)

        changeset = Entry.changeset(entry, attrs)

        try do
          case Repo.update(changeset) do
            {:ok, updated} ->
              if cache_key(updated.key, updated.user_id) != old_cache_key do
                _ = GameServer.Cache.delete(old_cache_key)
              end

              _ = cache_put(updated.key, updated.user_id, updated)
              _ = invalidate_entries_cache(entry.user_id)
              _ = invalidate_entries_cache(updated.user_id)
              {:ok, updated}

            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, changeset}
          end
        rescue
          e in Ecto.ConstraintError ->
            cond do
              Map.get(e, :type) == :foreign_key ->
                {:error, Ecto.Changeset.add_error(changeset, :user_id, "does not exist")}

              Map.get(e, :type) in [:unique, :unique_constraint] ->
                {:error, Ecto.Changeset.add_error(changeset, :key, "has already been taken")}

              true ->
                reraise(e, __STACKTRACE__)
            end
        end
    end
  end

  @spec delete_entry(pos_integer()) :: :ok
  def delete_entry(id) when is_integer(id) and id > 0 do
    case Repo.get(Entry, id) do
      nil ->
        :ok

      %Entry{} = entry ->
        _ = GameServer.Cache.delete(cache_key(entry.key, entry.user_id))
        _ = Repo.delete(entry)
        _ = invalidate_entries_cache(entry.user_id)
        :ok
    end
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

  defp maybe_filter_user(query, nil), do: query
  defp maybe_filter_user(query, user_id), do: from(e in query, where: e.user_id == ^user_id)

  defp maybe_filter_key(query, nil), do: query

  defp maybe_filter_key(query, key_filter) when is_binary(key_filter) do
    from(e in query,
      where: like(fragment("lower(?)", e.key), ^"%#{key_filter}%")
    )
  end

  defp normalize_key_filter(nil), do: nil

  defp normalize_key_filter(key_filter) when is_binary(key_filter) do
    key_filter = String.trim(key_filter)
    if key_filter == "", do: nil, else: String.downcase(key_filter)
  end

  defp unique_constraint_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_field, {_msg, meta}} -> meta[:constraint] == :unique end)
  end
end
