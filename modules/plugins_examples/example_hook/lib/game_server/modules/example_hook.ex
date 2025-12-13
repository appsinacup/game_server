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

  @impl true
  def after_startup do
    :ok
  end

  @impl true
  def before_stop, do: :ok

  @impl true
  def after_user_register(_user), do: :ok

  @impl true
  def after_user_login(_user), do: :ok

  @impl true
  def before_lobby_create(attrs), do: {:ok, attrs}

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
  def after_lobby_host_change(_lobby, _new_host_id), do: :ok

  @doc "Say hi to a user"
  def hello(name) when is_binary(name) do
    # Exercise an external dependency so the bundle task can prove it ships deps.
    Bunt.ANSI.format(["Hello, ", name, "!"], false)
  end

  @doc "Return an updated metadata map for the current caller"
  def set_current_user_meta(key, value) when is_binary(key) do
    caller = Process.get(:game_server_hook_caller)

    meta =
      case caller do
        %{metadata: m} when is_map(m) -> m
        _ -> %{}
      end

    # This example intentionally does NOT write to the database.
    # In a real hook you can call server context modules to persist changes.
    {:ok, Map.put(meta, key, value)}
  end
end
