defmodule GameServer.Cache do
  @moduledoc ~S"""
  In-memory cache backed by Nebulex (2-level near-cache topology).

  Plugins can use this to cache expensive computations (e.g. API calls,
  PDF generation, data transformations) so that repeated hook calls return
  instantly from cache.

  ## Quick start — `cached/3`

  The simplest way to cache a hook function. Checks the cache first; on miss,
  runs the function, stores the result, and returns it:

      defmodule GameServer.Modules.MyPlugin do
        use GameServer.Hooks

        def generate_cheatsheet(lang) do
          GameServer.Cache.cached({:my_plugin, :cheatsheet, lang}, ttl: :timer.minutes(30), fn ->
            do_expensive_pdf_generation(lang)
          end)
        end
      end

  Equivalent to:

      case GameServer.Cache.get(key) do
        nil ->
          result = fun.()
          GameServer.Cache.put(key, result, opts)
          result

        cached ->
          cached
      end

  ## Manual get/put

  For more control (conditional caching, partial updates, etc.):

      def my_hook(lang) do
        cache_key = {:my_plugin, :data, lang}

        case GameServer.Cache.get(cache_key) do
          nil ->
            result = expensive_work(lang)
            GameServer.Cache.put(cache_key, result, ttl: :timer.minutes(10))
            {:ok, result}

          cached ->
            {:ok, cached}
        end
      end

  ## Cache keys

  Use namespaced tuples to avoid collisions with other plugins and the server:

      {:my_plugin, :resource_type, resource_id}

  ## Options

  - **`:ttl`** — time-to-live in milliseconds. After this time the entry is
    automatically evicted. If omitted, the entry lives until explicitly deleted
    or the cache is full (LRU eviction).

  ## Version-based invalidation

  For data that changes (e.g. leaderboard entries, user profiles), embed a
  version counter in the cache key. When data changes, increment the version
  so the next read produces a cache miss:

      defp my_version(entity_id) do
        GameServer.Cache.get({:my_plugin, :version, entity_id}) || 1
      end

      defp invalidate(entity_id) do
        GameServer.Cache.incr({:my_plugin, :version, entity_id}, 1, default: 1)
      end

      def get_data(entity_id) do
        vsn = my_version(entity_id)
        cache_key = {:my_plugin, :data, vsn, entity_id}

        case GameServer.Cache.get(cache_key) do
          nil ->
            data = fetch_from_db(entity_id)
            GameServer.Cache.put(cache_key, data, ttl: :timer.minutes(5))
            {:ok, data}

          cached ->
            {:ok, cached}
        end
      end

  **Note:** This is an SDK stub. The actual implementation uses Nebulex on
  the GameServer.
  """

  @doc """
  Cache-through helper: returns the cached value for `key`, or computes and
  caches the result of `fun`.

  This is the recommended way to add caching to hook functions. It combines
  `get` + `put` in a single call:

      GameServer.Cache.cached({:my_plugin, :data, id}, ttl: :timer.minutes(10), fn ->
        expensive_computation(id)
      end)

  ## Options

  - `:ttl` — time-to-live in milliseconds
  """
  @spec cached(term(), keyword(), (-> term())) :: term()
  def cached(_key, _opts \\ [], _fun) do
    stub!("cached/3")
  end

  @doc "Get a cached value by key. Returns `nil` on cache miss."
  @spec get(term()) :: term() | nil
  def get(_key) do
    stub!("get/1")
  end

  @doc """
  Store a value in the cache.

  ## Options

  - `:ttl` — time-to-live in milliseconds (e.g. `ttl: :timer.minutes(10)`)
  """
  @spec put(term(), term(), keyword()) :: term()
  def put(_key, _value, _opts \\ []) do
    stub!("put/3")
  end

  @doc "Delete a cache entry by key."
  @spec delete(term()) :: :ok
  def delete(_key) do
    stub!("delete/1")
  end

  @doc "Check whether a key exists in the cache."
  @spec has_key?(term()) :: boolean()
  def has_key?(_key) do
    stub!("has_key?/1")
  end

  @doc """
  Atomically increment a numeric counter.

  Returns the new value. Creates the counter with the `:default` value if it
  doesn't exist.

  ## Options

  - `:default` — initial value if key doesn't exist (default: `0`)
  """
  @spec incr(term(), integer(), keyword()) :: integer()
  def incr(_key, _amount \\ 1, _opts \\ []) do
    stub!("incr/3")
  end

  defp stub!(fun) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder -> nil
      _ -> raise "GameServer.Cache.#{fun} is a stub - only available at runtime on GameServer"
    end
  end
end
