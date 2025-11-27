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
  require Logger

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

  @doc """
  Register a module from a source file at runtime. We capture any
  compiler output (warnings or compile-time prints) and record a
  timestamp and status (ok, ok_with_warnings, error) in application
  environment so the admin UI can display diagnostics.
  """
  def register_file(path) when is_binary(path) do
    require Logger

    Logger.info("Hooks.register_file: attempting to compile #{path}")

    if File.exists?(path) do
      {compile_result, output} = compile_file_and_capture_output(path)

      case compile_result do
        {:compile_exception, reason} ->
          now = DateTime.utc_now() |> DateTime.to_iso8601()
          Application.put_env(:game_server, :hooks_last_compiled_at, now)
          Application.put_env(:game_server, :hooks_last_compile_status, {:error, reason})

          Logger.error(
            "Hooks.register_file: compile exception for #{inspect(path)}: #{inspect(reason)}"
          )

          {:error, {:compile_error, reason}}

        modules when is_list(modules) ->
          handle_compiled_modules(modules, output, path)
      end
    else
      now = DateTime.utc_now() |> DateTime.to_iso8601()
      Application.put_env(:game_server, :hooks_last_compiled_at, now)
      Application.put_env(:game_server, :hooks_last_compile_status, {:error, :enoent})
      Logger.error("Hooks.register_file: file not found: #{path} (time=#{now})")
      {:error, :enoent}
    end
  end

  defp compile_file_and_capture_output(path) do
    {:ok, io} = StringIO.open("")
    old_gl = Process.group_leader()
    Process.group_leader(self(), io)

    result =
      try do
        Code.compile_file(path)
      rescue
        e -> {:compile_exception, Exception.format(:error, e, __STACKTRACE__)}
      after
        # restore group leader even when exceptions occur
        Process.group_leader(self(), old_gl)
      end

    {_, output} = StringIO.contents(io)
    {result, output}
  end

  defp handle_compiled_modules(modules, output, path) do
    case modules do
      [{mod, _bin} | _] -> process_compiled_module(mod, output)
      [] -> handle_no_module(path)
    end
  end

  defp process_compiled_module(mod, output) do
    warnings = if String.contains?(output, "warning:"), do: String.trim(output), else: nil
    now = timestamp()

    case Code.ensure_compiled(mod) do
      {:module, _} -> register_module_if_valid(mod, warnings, now)
      {:error, _} = err -> err
    end
  end

  defp register_module_if_valid(mod, warnings, now) do
    if function_exported?(mod, :after_user_register, 1) do
      Application.put_env(:game_server, :hooks_module, mod)
      status = if(warnings, do: {:ok_with_warnings, mod, warnings}, else: {:ok, mod})
      Application.put_env(:game_server, :hooks_last_compiled_at, now)
      Application.put_env(:game_server, :hooks_last_compile_status, status)

      Logger.info("Hooks.register_file: registered hooks module #{inspect(mod)} at #{now}")

      {:ok, mod}
    else
      Application.put_env(:game_server, :hooks_last_compiled_at, now)

      Application.put_env(:game_server, :hooks_last_compile_status, {:error, :invalid_hooks_impl})

      Logger.error(
        "Hooks.register_file: compiled module #{inspect(mod)} does not implement expected callback (registered_at=#{now})"
      )

      {:error, :invalid_hooks_impl}
    end
  end

  defp handle_no_module(path) do
    now = timestamp()
    Application.put_env(:game_server, :hooks_last_compiled_at, now)

    Application.put_env(
      :game_server,
      :hooks_last_compile_status,
      {:error, :no_module_in_file}
    )

    Logger.error("Hooks.register_file: no module defined in #{path} (time=#{now})")
    {:error, :no_module_in_file}
  end

  defp timestamp, do: DateTime.utc_now() |> DateTime.to_iso8601()
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

# friends hooks removed
