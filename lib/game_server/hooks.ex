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

  @callback before_user_register(map()) :: hook_result(map())
  @callback after_user_register(User.t()) :: any()

  @callback before_user_login(User.t()) :: hook_result(User.t())
  @callback after_user_login(User.t()) :: any()

  @callback before_account_link(User.t(), atom(), map()) :: hook_result({User.t(), map()})
  @callback after_account_link(User.t()) :: any()

  @callback before_user_delete(User.t()) :: hook_result(User.t())
  @callback after_user_delete(User.t()) :: any()

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
  def before_user_register(attrs), do: {:ok, attrs}

  @impl true
  def after_user_register(_user), do: :ok

  @impl true
  def before_user_login(user), do: {:ok, user}

  @impl true
  def after_user_login(_user), do: :ok

  @impl true
  def before_account_link(user, _provider, attrs), do: {:ok, {user, attrs}}

  @impl true
  def after_account_link(_user), do: :ok

  @impl true
  def before_user_delete(user), do: {:ok, user}

  @impl true
  def after_user_delete(_user), do: :ok
end

defmodule GameServer.Hooks.LuaInvoker do
  @moduledoc """
  Small helper that can invoke an external Lua script to run hook logic.

  This module is a convenience shim and expects a configured script path
  set via `:game_server, :hooks_lua_script` config. The script will be called
  with the hook name and JSON payload on STDIN and should emit JSON on STDOUT.

  This is intentionally minimal — you can replace it with a more robust
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

        {out, _} -> {:error, {:lua_failed, out}}
      end
    else
      {:ok, payload}
    end
  end

  @impl true
  def before_user_register(attrs), do: run_lua(:before_user_register, attrs)

  @impl true
  def after_user_register(_user), do: :ok

  @impl true
  def before_user_login(user), do: run_lua(:before_user_login, Map.from_struct(user))

  @impl true
  def after_user_login(_user), do: :ok

  @impl true
  def before_account_link(user, provider, attrs), do: run_lua(:before_account_link, %{user: Map.from_struct(user), provider: provider, attrs: attrs})

  @impl true
  def after_account_link(_user), do: :ok

  @impl true
  def before_user_delete(user), do: run_lua(:before_user_delete, Map.from_struct(user))

  @impl true
  def after_user_delete(_user), do: :ok
end
