defmodule GameServer.Hooks do
  @moduledoc """
  Behaviour for application-level hooks / callbacks.

  Implement this behaviour to receive lifecycle events from core flows
  (registration, login, provider linking, deletion) and run custom logic.

  A module implementing this behaviour can be configured with

      config :game_server, :hooks_module, MyApp.HooksImpl

  The default implementation is `GameServer.Hooks.Default` which is a no-op.
  """

  alias GameServer.Accounts.User

  @type hook_result(attrs_or_user) :: {:ok, attrs_or_user} | {:error, term()}

  @callback after_user_register(User.t()) :: any()

  @callback after_user_login(User.t()) :: any()

  # Lobby lifecycle hooks
  @callback before_lobby_create(map()) :: hook_result(map())
  @callback after_lobby_create(term()) :: any()

  @callback before_lobby_join(User.t(), term(), term()) :: hook_result({User.t(), term(), term()})
  @callback after_lobby_join(User.t(), term()) :: any()

  @callback before_lobby_leave(User.t(), term()) :: hook_result({User.t(), term()})
  @callback after_lobby_leave(User.t(), term()) :: any()

  @callback before_lobby_update(term(), map()) :: hook_result(map())
  @callback after_lobby_update(term()) :: any()

  @callback before_lobby_delete(term()) :: hook_result(term())
  @callback after_lobby_delete(term()) :: any()

  @callback before_user_kicked(User.t(), User.t(), term()) ::
              hook_result({User.t(), User.t(), term()})
  @callback after_user_kicked(User.t(), User.t(), term()) :: any()

  @callback after_lobby_host_change(term(), term()) :: any()

  # (friends hooks removed — see config / code changes)

  @doc "Return the configured module that implements the hooks behaviour."
  def module do
    case Application.get_env(:game_server, :hooks_module, GameServer.Hooks.Default) do
      nil -> GameServer.Hooks.Default
      mod -> mod
    end
  end
end

defmodule GameServer.Hooks.Default do
  @moduledoc "Default no-op implementation for GameServer.Hooks"
  @behaviour GameServer.Hooks

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
end

defmodule GameServer.Hooks.LuaInvoker do
  @moduledoc """
  Small helper that can invoke an external Lua script to run hook logic.

  This module is a convenience shim and expects a configured script path
  set via `:game_server, :hooks_lua_script` config. The script will be called
  with the hook name and JSON payload on STDIN and should emit JSON on STDOUT.

  This is intentionally minimal - you can replace it with a more robust
  bridge (erlport, escript, NIF, etc.) in production.
  """

  @behaviour GameServer.Hooks

  defp run_lua(hook, payload) do
    script = Application.get_env(:game_server, :hooks_lua_script)

    if is_binary(script) and File.exists?(script) do
      json = Jason.encode!(payload)

      case System.cmd("lua", [script, Atom.to_string(hook)], input: json, stderr_to_stdout: true) do
        {out, 0} ->
          case Jason.decode(out) do
            {:ok, %{"result" => "ok", "data" => data}} -> {:ok, data}
            {:ok, %{"result" => "error", "reason" => r}} -> {:error, r}
            _ -> {:error, :invalid_lua_response}
          end

        {out, _} ->
          {:error, {:lua_failed, out}}
      end
    else
      {:ok, payload}
    end
  end

  @impl true
  def after_user_register(user), do: run_lua(:after_user_register, Map.from_struct(user))

  @impl true
  def after_user_login(user), do: run_lua(:after_user_login, Map.from_struct(user))

  # Lobbies
  @impl true
  def before_lobby_create(attrs), do: run_lua(:before_lobby_create, attrs)

  @impl true
  def after_lobby_create(_lobby), do: :ok

  @impl true
  def before_lobby_join(user, lobby, opts),
    do: run_lua(:before_lobby_join, %{user: Map.from_struct(user), lobby: lobby, opts: opts})

  @impl true
  def after_lobby_join(_user, _lobby), do: :ok

  @impl true
  def before_lobby_leave(user, lobby),
    do: run_lua(:before_lobby_leave, %{user: Map.from_struct(user), lobby: lobby})

  @impl true
  def after_lobby_leave(_user, _lobby), do: :ok

  @impl true
  def before_lobby_update(lobby, attrs),
    do: run_lua(:before_lobby_update, %{lobby: lobby, attrs: attrs})

  @impl true
  def after_lobby_update(_lobby), do: :ok

  @impl true
  def before_lobby_delete(lobby), do: run_lua(:before_lobby_delete, lobby)

  @impl true
  def after_lobby_delete(_lobby), do: :ok

  @impl true
  def before_user_kicked(host, target, lobby),
    do:
      run_lua(:before_user_kicked, %{
        host: Map.from_struct(host),
        target: Map.from_struct(target),
        lobby: lobby
      })

  @impl true
  def after_user_kicked(_host, _target, _lobby), do: :ok

  @impl true
  def after_lobby_host_change(_lobby, _new_host_id), do: :ok

  # friends hooks removed
end
