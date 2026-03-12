defmodule GameServer.Modules.ExampleHook do
  @moduledoc """
  Example hooks implementation shipped as an OTP plugin.

  This is intentionally kept out of the default plugins directory so it does not
  affect test runs or production deployments.

  To try it locally:

      export GAME_SERVER_PLUGINS_DIR=modules/plugins_examples

  Then restart the server and use the Admin Config page to reload plugins.
  """

  @behaviour GameServer.Hooks
  require Logger

  alias GameServer.Accounts
  alias GameServer.Hooks
  alias GameServer.KV
  alias GameServer.Lock


  @impl true
  def after_startup do
    Logger.info("[ExampleHook] after_startup called")

    [
      %{
        hook: "custom_hello",
        meta: %{
          description: "Example dynamic hook that returns hello",
          args: [%{name: "name", type: "string"}],
          example_args: ["Dragos"]
        }
      }
    ]
  end

  @impl true
  def before_stop, do: :ok

  @impl true
  def after_user_register(_user), do: :ok

  @impl true
  def after_user_login(_user), do: :ok

  @impl true
  def before_lobby_create(attrs) do
    {:ok, attrs}
  end

  @impl true
  def after_lobby_create(_lobby), do: :ok

  @impl true
  def before_lobby_join(user, lobby, opts), do: {:ok, {user, lobby, opts}}

  @impl true
  def after_lobby_join(_user, _lobby), do: :ok

  @impl true
  def before_lobby_leave(user, lobby), do: {:ok, {user, lobby}}

  @impl true
  def after_lobby_leave(_user, _lobby), do: :ok

  @impl true
  def before_lobby_update(_lobby, attrs), do: {:ok, attrs}

  @impl true
  def after_lobby_update(_lobby), do: :ok

  @impl true
  def before_lobby_delete(lobby), do: {:ok, lobby}

  @impl true
  def after_lobby_delete(_lobby), do: :ok

  @impl true
  def before_user_kicked(host, target, lobby), do: {:ok, {host, target, lobby}}

  @impl true
  def after_user_kicked(_host, _target, _lobby), do: :ok

  @impl true
  def before_kv_get(_key, _opts), do: :public

  @impl true
  def after_lobby_host_change(_lobby, _new_host_id), do: :ok

  @impl true
  def after_user_updated(_user), do: :ok

  @impl true
  def before_group_create(_user, attrs), do: {:ok, attrs}

  @impl true
  def after_group_create(_group), do: :ok

  @impl true
  def before_group_join(user, group, opts), do: {:ok, {user, group, opts}}

  @impl true
  def before_group_update(_group, attrs), do: {:ok, attrs}

  @impl true
  def after_group_update(_group), do: :ok

  @impl true
  def after_group_join(_user_id, _group), do: :ok

  @impl true
  def after_group_leave(_user_id, _group_id), do: :ok

  @impl true
  def after_group_delete(_group), do: :ok

  @impl true
  def after_group_kick(_admin_id, _target_id, _group_id), do: :ok

  @impl true
  def before_party_create(_user, attrs), do: {:ok, attrs}

  @impl true
  def after_party_create(_party), do: :ok

  @impl true
  def before_party_update(_party, attrs), do: {:ok, attrs}

  @impl true
  def after_party_update(_party), do: :ok

  @impl true
  def after_party_join(_user, _party), do: :ok

  @impl true
  def after_party_leave(_user, _party_id), do: :ok

  @impl true
  def after_party_kick(_target, _leader, _party), do: :ok

  @impl true
  def after_party_disband(_party), do: :ok

  @impl true
  def on_custom_hook("custom_hello", [name]) when is_binary(name), do: "hello #{name}"

  def on_custom_hook("custom_hello", _args), do: "hello"

  @impl true
  def on_custom_hook(_hook, _args), do: {:error, :not_implemented}

  @doc "Say hi to a user"
  def hello(name) when is_binary(name) do
    # Exercise an external dependency so the bundle task can prove it ships deps.
    Bunt.ANSI.format(["Hello1, ", name, "!"], false)
  end

  @doc "Return an updated metadata map for the current caller"
  def set_current_user_meta(key, value) when is_binary(key) do
    do_set_user_meta(Hooks.caller_user(), key, value)
  end

  defp do_set_user_meta(user, key, value) do
    meta = user.metadata || %{}
    meta = Map.put(meta, key, value)
    {:ok, updated_user} = Accounts.update_user(user, %{metadata: meta})
    updated_user
  end

  # ── Benchmark RPCs ──────────────────────────────────────────────────

  @doc "Benchmark: instant return, no I/O. Measures pure RPC overhead."
  def bench_noop, do: :ok

  @doc "Benchmark: read a KV entry from the database."
  def bench_kv_read(key) when is_binary(key) do
    case KV.get(key) do
      {:ok, entry} -> entry.value
      _ -> nil
    end
  end

  @doc "Benchmark: read from ETS (in-memory). Measures RPC + ETS overhead."
  def bench_memory_read(key) when is_binary(key) do
    case :ets.lookup(:game_server_bench, key) do
      [{^key, val}] -> val
      [] -> nil
    end
  rescue
    ArgumentError -> nil
  end

  @doc "Benchmark: write to KV inside an advisory lock."
  def bench_kv_write_locked(key) when is_binary(key) do
    resource_id = :erlang.phash2(key)

    _result =
      Lock.serialize("bench", resource_id, fn ->
        ts = System.system_time(:millisecond)
        KV.put(key, %{"ts" => ts, "writer" => "bench"})
      end)

    :ok
  end

  @doc "Benchmark: ensure the ETS table + seed key exist, then read a KV entry."
  def bench_setup(key) when is_binary(key) do
    # Create ETS table for memory benchmarks (idempotent)
    try do
      :ets.new(:game_server_bench, [:named_table, :public, :set])
    rescue
      ArgumentError -> :already_exists
    end

    :ets.insert(:game_server_bench, {key, %{"seeded" => true}})

    # Seed a KV entry for DB read benchmarks
    KV.put(key, %{"seeded" => true})
    :ok
  end
end
