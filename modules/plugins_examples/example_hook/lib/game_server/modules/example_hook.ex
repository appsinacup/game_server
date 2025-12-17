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


  @impl true
  def after_startup do
    Logger.info("[ExampleHook] after_startup called")
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
    Bunt.ANSI.format(["Hello1, ", name, "!"], false)
  end

  @doc "Return an updated metadata map for the current caller"
  def set_current_user_meta(key, value) when is_binary(key) do
    do_set_user_meta(Hooks.caller_user(), key, value)
  end

  defp do_set_user_meta(user, key, value) do
    meta = user.metadata || %{}
    meta = Map.put(meta, key, value)

    case Accounts.update_user(user, %{metadata: meta}) do
      {:ok, updated_user} -> updated_user
      {:error, changeset} -> {:error, changeset}
    end
  end
end
