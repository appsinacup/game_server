defmodule GameServer.Hooks.PluginManager do
  @moduledoc """
  Loads and manages hook plugins shipped as OTP applications under `modules/plugins/*`.

  Each plugin is expected to be a directory named after the OTP app name (e.g. `polyglot_hook`)
  containing:

      modules/plugins/polyglot_hook/
        ebin/polyglot_hook.app
        ebin/Elixir.GameServer.Modules.PolyglotHook.beam
        deps/*/ebin/*.beam

  The plugin's `.app` env must include the key `:hooks_module`, whose value is either a
  charlist or string module name like `'Elixir.GameServer.Modules.PolyglotHook'`.

  This manager is intentionally dependency-free: it only adds `ebin` directories to the code
  path and uses `Application.load/1` + `Application.ensure_all_started/1`.
  """

  use GenServer

  require Logger

  alias GameServer.Hooks.DynamicRpcs

  @type plugin_name :: String.t()
  @type plugin_app :: atom()

  @default_plugins_dir Path.expand("modules/plugins")

  @timeout_ms 5_000

  defmodule Plugin do
    @moduledoc """
    A loaded plugin descriptor.

    This is a runtime struct used by `GameServer.Hooks.PluginManager` to report which
    plugins were discovered and whether they successfully loaded and started.
    """

    @type t :: %__MODULE__{
            name: String.t(),
            app: atom(),
            vsn: String.t() | nil,
            hooks_module: module() | nil,
            status: :ok | {:error, term()},
            loaded_at: DateTime.t() | nil,
            ebin_paths: [String.t()],
            modules: [module()]
          }

    defstruct name: nil,
              app: nil,
              vsn: nil,
              hooks_module: nil,
              status: {:error, :not_loaded},
              loaded_at: nil,
              ebin_paths: [],
              modules: []
  end

  # Public API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec list() :: [Plugin.t()]
  def list do
    case GenServer.whereis(__MODULE__) do
      nil -> []
      _pid -> GenServer.call(__MODULE__, :list)
    end
  end

  @spec lookup(plugin_name()) :: {:ok, Plugin.t()} | {:error, term()}
  def lookup(name) when is_binary(name) do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :not_running}
      _pid -> GenServer.call(__MODULE__, {:lookup, name})
    end
  end

  @spec hook_modules() :: [{plugin_name(), module()}]
  def hook_modules do
    list()
    |> Enum.flat_map(fn
      %Plugin{name: name, hooks_module: mod, status: :ok} when is_atom(mod) -> [{name, mod}]
      _ -> []
    end)
  end

  @spec reload() :: [Plugin.t()]
  def reload do
    GenServer.call(__MODULE__, :reload, @timeout_ms)
  end

  @spec reload_and_after_startup() :: %{plugins: [Plugin.t()], after_startup: map()}
  def reload_and_after_startup do
    GenServer.call(__MODULE__, :reload_and_after_startup, @timeout_ms)
  end

  @spec call_rpc(plugin_name(), String.t(), list(), keyword()) :: {:ok, any()} | {:error, term()}
  def call_rpc(plugin, fn_name, args, opts \\ [])
      when is_binary(plugin) and is_binary(fn_name) and is_list(args) and is_list(opts) do
    case lookup(plugin) do
      {:ok, %Plugin{status: :ok, hooks_module: mod}} when is_atom(mod) ->
        timeout = Keyword.get(opts, :timeout_ms, @timeout_ms)

        case resolve_function_atom(mod, fn_name, length(args)) do
          {:ok, fun_atom} ->
            safe_apply_with_caller(mod, fun_atom, args, opts, timeout)

          {:error, :not_implemented} ->
            call_dynamic_rpc(plugin, mod, fn_name, args, opts, timeout)

          {:error, _} = err ->
            err

          other ->
            {:error, other}
        end

      {:ok, %Plugin{status: {:error, reason}}} ->
        {:error, reason}

      {:ok, %Plugin{hooks_module: nil}} ->
        {:error, :missing_hooks_module}

      {:error, _} = err ->
        err

      other ->
        {:error, other}
    end
  end

  @spec plugins_dir() :: String.t()
  def plugins_dir do
    System.get_env("GAME_SERVER_PLUGINS_DIR") || @default_plugins_dir
  end

  # GenServer

  @impl true
  def init(_opts) do
    # Load plugins on boot.
    plugins = do_reload(%{})

    # Best-effort after_startup fan-out at boot.
    _ = do_after_startup(plugins)

    {:ok, plugins}
  end

  @impl true
  def handle_call(:list, _from, state), do: {:reply, state_to_list(state), state}

  def handle_call({:lookup, name}, _from, state) do
    case Map.fetch(state, name) do
      {:ok, plugin} -> {:reply, {:ok, plugin}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:reload, _from, state) do
    state = do_reload(state)

    # Best-effort: run after_startup for newly loaded plugins after a reload.
    _ = do_after_startup(state)

    {:reply, state_to_list(state), state}
  end

  def handle_call(:reload_and_after_startup, _from, state) do
    state = do_reload(state)
    results = do_after_startup(state)
    {:reply, %{plugins: state_to_list(state), after_startup: results}, state}
  end

  # Internals

  defp state_to_list(state) when is_map(state) do
    state
    |> Map.values()
    |> Enum.sort_by(& &1.name)
  end

  defp do_reload(prev_state) when is_map(prev_state) do
    # Dynamic RPC exports are derived from the currently loaded plugins.
    # Rebuild the registry on each reload.
    _ = DynamicRpcs.reset_all()

    # Stop/unload previous apps and purge their modules first.
    prev_state
    |> Map.values()
    |> Enum.each(&stop_unload_plugin/1)

    # Load current plugin dirs.
    load_plugins_from_disk()
  end

  defp stop_unload_plugin(%Plugin{app: app, hooks_module: hooks_mod} = plugin)
       when is_atom(app) do
    # Allow hooks module to run cleanup before stop/unload.
    _ = safe_call_before_stop(plugin)

    case Application.stop(app) do
      :ok -> :ok
      {:error, {:not_started, _}} -> :ok
      {:error, :not_started} -> :ok
      other -> Logger.warning("plugin stop failed app=#{inspect(app)}: #{inspect(other)}")
    end

    # Purge modules so reloading picks up new beams.
    purge_modules(plugin.modules)

    case Application.unload(app) do
      :ok -> :ok
      {:error, {:not_loaded, _}} -> :ok
      {:error, :not_loaded} -> :ok
      other -> Logger.warning("plugin unload failed app=#{inspect(app)}: #{inspect(other)}")
    end

    # Also purge the hooks module explicitly.
    purge_modules([hooks_mod])

    # Remove plugin code paths so reloads don't grow the path list.
    Enum.each(plugin.ebin_paths, fn p ->
      _ = Code.delete_path(p)
    end)
  end

  defp stop_unload_plugin(_), do: :ok

  defp purge_modules(mods) when is_list(mods) do
    Enum.each(mods, fn
      mod when is_atom(mod) ->
        _ = :code.purge(mod)
        _ = :code.delete(mod)

      _ ->
        :ok
    end)
  end

  defp load_plugins_from_disk do
    dir = plugins_dir()

    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.map(&Path.join(dir, &1))
      |> Enum.filter(&File.dir?/1)
      |> Enum.map(&Path.basename/1)
      |> Enum.sort()
      |> Enum.reduce(%{}, fn plugin_name, acc ->
        plugin = load_plugin(dir, plugin_name)
        Map.put(acc, plugin_name, plugin)
      end)
    else
      %{}
    end
  end

  defp load_plugin(root, plugin_name) do
    app = String.to_atom(plugin_name)

    plugin_dir = Path.join(root, plugin_name)

    ebin_paths =
      [Path.join(plugin_dir, "ebin")] ++
        (Path.wildcard(Path.join(plugin_dir, "deps/*/ebin")) || [])

    Enum.each(ebin_paths, fn p ->
      if File.dir?(p) do
        # Ensure we don't accumulate duplicate paths across reloads.
        _ = Code.delete_path(p)
        Code.append_path(p)
      end
    end)

    now = DateTime.utc_now()

    plugin = %Plugin{name: plugin_name, app: app, ebin_paths: ebin_paths, loaded_at: now}

    with :ok <- safe_load_app(app),
         {:ok, vsn} <- app_vsn(app),
         {:ok, modules} <- app_modules(app),
         {:ok, hooks_mod} <- app_hooks_module(app),
         :ok <- safe_ensure_started(app) do
      Logger.info(
        "plugin=#{plugin_name} loaded vsn=#{inspect(vsn)} hooks_module=#{inspect(hooks_mod)} modules=#{length(modules)}"
      )

      %Plugin{plugin | vsn: vsn, modules: modules, hooks_module: hooks_mod, status: :ok}
    else
      {:error, reason} ->
        %Plugin{plugin | status: {:error, reason}}

      other ->
        %Plugin{plugin | status: {:error, other}}
    end
  end

  defp safe_load_app(app) do
    case Application.load(app) do
      :ok -> :ok
      {:error, {:already_loaded, _}} -> :ok
      {:error, :already_loaded} -> :ok
      {:error, reason} -> {:error, {:load_failed, reason}}
    end
  end

  defp safe_ensure_started(app) do
    case Application.ensure_all_started(app) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:start_failed, reason}}
    end
  end

  defp app_vsn(app) do
    case :application.get_key(app, :vsn) do
      {:ok, vsn} when is_list(vsn) -> {:ok, List.to_string(vsn)}
      {:ok, vsn} when is_binary(vsn) -> {:ok, vsn}
      {:ok, other} -> {:ok, to_string(other)}
      :undefined -> {:ok, nil}
      other -> {:error, {:vsn_failed, other}}
    end
  end

  defp app_modules(app) do
    case :application.get_key(app, :modules) do
      {:ok, mods} when is_list(mods) -> {:ok, mods}
      :undefined -> {:ok, []}
      other -> {:error, {:modules_failed, other}}
    end
  end

  defp app_hooks_module(app) do
    case Application.get_env(app, :hooks_module) do
      nil ->
        {:error, :missing_hooks_module}

      mod when is_atom(mod) ->
        {:ok, mod}

      mod when is_binary(mod) ->
        {:ok, String.to_atom(mod)}

      mod when is_list(mod) ->
        # charlist
        {:ok, String.to_atom(to_string(mod))}

      other ->
        {:error, {:invalid_hooks_module, other}}
    end
  end

  defp resolve_function_atom(mod, fn_name, arity) when is_atom(mod) and is_binary(fn_name) do
    mod.__info__(:functions)
    |> Enum.find_value({:error, :not_implemented}, fn {name, a} ->
      if a == arity and Atom.to_string(name) == fn_name do
        {:ok, name}
      else
        false
      end
    end)
    |> case do
      false -> {:error, :not_implemented}
      other -> other
    end
  end

  defp safe_apply_with_caller(mod, fun, args, opts, timeout)
       when is_atom(mod) and is_atom(fun) and is_list(args) and is_list(opts) do
    task =
      Task.async(fn ->
        if caller = Keyword.get(opts, :caller) do
          Process.put(:game_server_hook_caller, caller)
        end

        try do
          apply(mod, fun, args)
        rescue
          e in FunctionClauseError -> {:error, {:function_clause, Exception.message(e)}}
          e -> {:error, {:exception, Exception.message(e)}}
        catch
          kind, reason -> {:error, {kind, reason}}
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, res}} -> {:ok, res}
      {:ok, {:error, err}} -> {:error, err}
      {:ok, res} -> {:ok, res}
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, {:exit, reason}}
    end
  end

  defp do_after_startup(state) when is_map(state) do
    state
    |> Map.values()
    |> Enum.reduce(%{}, fn
      %Plugin{name: name, hooks_module: mod, status: :ok}, acc ->
        res =
          case Code.ensure_loaded(mod) do
            {:module, _} ->
              if function_exported?(mod, :after_startup, 0) do
                safe_apply(mod, :after_startup, [])
              else
                :not_exported
              end

            other ->
              Logger.error(
                "plugin=#{name} failed to load module=#{inspect(mod)}: #{inspect(other)}"
              )

              {:error, {:module_not_loaded, other}}
          end

        _ =
          case res do
            {:ok, exports} when is_list(exports) ->
              DynamicRpcs.register_exports(name, exports)

            {:ok, _other} ->
              :ok

            _ ->
              :ok
          end

        Map.put(acc, name, res)

      %Plugin{name: name, status: {:error, reason}}, acc ->
        Map.put(acc, name, {:skipped, reason})

      %Plugin{name: name}, acc ->
        Map.put(acc, name, :skipped)
    end)
  end

  defp call_dynamic_rpc(plugin, mod, fn_name, args, opts, timeout)
       when is_binary(plugin) and is_atom(mod) and is_binary(fn_name) and is_list(args) and
              is_list(opts) and is_integer(timeout) do
    if DynamicRpcs.allowed?(plugin, fn_name) do
      cond do
        function_exported?(mod, :on_custom_hook, 2) ->
          safe_apply_with_caller(mod, :on_custom_hook, [fn_name, args], opts, timeout)

        function_exported?(mod, :rpc, 2) ->
          safe_apply_with_caller(mod, :rpc, [fn_name, args], opts, timeout)

        function_exported?(mod, :rpc, 3) ->
          safe_apply_with_caller(
            mod,
            :rpc,
            [fn_name, args, Keyword.get(opts, :caller)],
            opts,
            timeout
          )

        true ->
          {:error, :not_implemented}
      end
    else
      {:error, :not_implemented}
    end
  end

  defp safe_call_before_stop(%Plugin{hooks_module: mod, status: :ok, name: name})
       when is_atom(mod) do
    case Code.ensure_loaded(mod) do
      {:module, _} ->
        if function_exported?(mod, :before_stop, 0) do
          safe_apply(mod, :before_stop, [])
        else
          Logger.debug("plugin #{name} has no before_stop/0")
          :not_exported
        end

      other ->
        Logger.error(
          "plugin=#{name} failed to load before_stop module=#{inspect(mod)}: #{inspect(other)}"
        )

        {:error, {:module_not_loaded, other}}
    end
  end

  defp safe_call_before_stop(_), do: :ok

  defp safe_apply(mod, fun, args) when is_atom(mod) and is_atom(fun) and is_list(args) do
    task =
      Task.async(fn ->
        try do
          apply(mod, fun, args)
        rescue
          e in FunctionClauseError -> {:error, {:function_clause, Exception.message(e)}}
          e -> {:error, {:exception, Exception.message(e)}}
        catch
          kind, reason -> {:error, {kind, reason}}
        end
      end)

    case Task.yield(task, @timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:error, _} = err} -> err
      {:ok, res} -> {:ok, res}
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, {:exit, reason}}
    end
  end
end
