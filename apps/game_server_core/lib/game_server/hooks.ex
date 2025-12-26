defmodule GameServer.Hooks do
  @moduledoc """
  Behaviour for application-level hooks / callbacks.

  Implement this behaviour to receive lifecycle events from core flows
  (registration, login, provider linking, deletion) and run custom logic.

  A module implementing this behaviour can be configured with

      config :game_server, :hooks_module, MyApp.HooksImpl

  The default implementation is a no-op.
  """

  alias GameServer.Accounts.User
  alias GameServer.Hooks.Default, as: Default
  alias GameServer.Hooks.PluginManager
  require Logger

  @type hook_result(attrs_or_user) :: {:ok, attrs_or_user} | {:error, term()}

  @typedoc """
  Options passed to hooks that accept an options map/keyword list.

  Common keys include `:user_id` (pos_integer) and other domain-specific
  options. Hooks may accept either a map or keyword list for convenience.
  """
  @type kv_opts :: map() | keyword()

  @callback after_startup() :: any()

  @callback before_stop() :: any()

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

  @doc """
  Called before a KV `get/2` is performed. Implementations should return
  `:public` if the key may be read publicly, or `:private` to restrict access.

  Receives the `key` and an `opts` map/keyword (see `t:kv_opts/0`). Return
  either the bare atom (e.g. `:public`) or `{:ok, :public}`; return `{:error, reason}`
  to block the read.
  """
  @callback before_kv_get(String.t(), kv_opts()) :: hook_result(:public | :private)

  @callback after_lobby_host_change(term(), term()) :: any()

  @doc "Return the configured module that implements the hooks behaviour."
  def module do
    case Application.get_env(:game_server_core, :hooks_module, Default) do
      nil -> Default
      mod -> mod
    end
  end

  @doc """
  Call an arbitrary function exported by the configured hooks module.

  This is a safe wrapper that checks function existence, enforces an allow-list
  if configured and runs the call inside a short Task with a configurable
  timeout to avoid long-running user code.

  Returns {:ok, result} | {:error, reason}
  """
  def call(name, args \\ [], opts \\ [])
      when is_list(args) and (is_atom(name) or is_binary(name)) do
    name = if is_binary(name), do: String.to_atom(name), else: name
    mod = module()
    # If caller passed as an id or a simple map with id, resolve it here in the
    # current process so the spawned task doesn't need to hit the DB (tests use
    # Ecto sandbox ownership rules). If resolution fails, leave caller as-is.
    opts = resolve_caller(opts)
    arity = length(args)

    # Disallow calling internal lifecycle callbacks or scheduled job callbacks
    # via the public `call/3` API.
    # Domain code should use `internal_call/3` for lifecycle callbacks.
    scheduled = GameServer.Schedule.registered_callbacks()

    cond do
      name in internal_hooks() ->
        {:error, :disallowed}

      MapSet.member?(scheduled, name) ->
        {:error, :disallowed}

      # private functions (defp) are not exported and will be handled by
      # function_exported?/3 => fall through to :not_implemented

      not function_exported?(mod, name, arity) ->
        {:error, :not_implemented}

      true ->
        timeout =
          Keyword.get(
            opts,
            :timeout_ms,
            Application.get_env(:game_server_core, :hooks_call_timeout, 5_000)
          )

        task =
          Task.async(fn ->
            # Make caller context available inside the task via process dictionary.
            if caller = Keyword.get(opts, :caller) do
              Process.put(:game_server_hook_caller, caller)
            end

            try do
              apply(mod, name, args)
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
  end

  @doc "Call an internal lifecycle callback. When a callback is missing this
  returns a sensible default (eg. {:ok, attrs} for before callbacks) so
  domain code doesn't need to handle missing hooks specially in most cases."
  def internal_call(name, args \\ [], opts \\ [])
      when is_list(args) and (is_atom(name) or is_binary(name)) do
    name = if is_binary(name), do: String.to_atom(name), else: name
    # resolve caller before spawning a task in case the caller was provided as
    # a simple id (avoids sandbox issues for spawned tasks in tests)
    opts = resolve_caller(opts)

    mods = lifecycle_modules()

    timeout =
      Keyword.get(
        opts,
        :timeout_ms,
        Application.get_env(:game_server_core, :hooks_call_timeout, 5_000)
      )

    arity = length(args)

    if lifecycle_pipeline_hook?(name, arity) do
      run_before_pipeline(mods, name, args, opts, timeout)
    else
      run_fanout(mods, name, args, opts, timeout)
    end
  end

  @doc """
  Invoke a dynamic hook function by name.

  This is used by `GameServer.Schedule` to call scheduled job callbacks.
  Unlike `internal_call/3`, this is designed for user-defined functions
  that are not part of the core lifecycle callbacks.

  Returns `:ok` on success, `{:error, reason}` on failure or if the
  function doesn't exist.
  """
  def invoke(name, args \\ []) when is_atom(name) and is_list(args) do
    mod = module()
    arity = length(args)

    if function_exported?(mod, name, arity) do
      try do
        case apply(mod, name, args) do
          :ok -> :ok
          {:ok, _} = ok -> ok
          {:error, _} = err -> err
          other -> {:ok, other}
        end
      rescue
        e -> {:error, {:exception, Exception.message(e)}}
      catch
        kind, reason -> {:error, {kind, reason}}
      end
    else
      {:error, {:not_found, {mod, name, arity}}}
    end
  end

  defp internal_hooks do
    # set of callback names considered internal/lifecycle hooks and not
    # callable through the public `call/3` interface.
    MapSet.new([
      :after_startup,
      :before_stop,
      :after_user_register,
      :after_user_login,
      :before_lobby_create,
      :after_lobby_create,
      :before_lobby_join,
      :after_lobby_join,
      :before_lobby_leave,
      :after_lobby_leave,
      :before_lobby_update,
      :after_lobby_update,
      :before_lobby_delete,
      :after_lobby_delete,
      :before_user_kicked,
      :after_user_kicked,
      :after_lobby_host_change,
      :before_kv_get
    ])
  end

  defp lifecycle_modules do
    base = module()

    plugin_mods =
      case PluginManager.hook_modules() do
        list when is_list(list) -> Enum.map(list, fn {_name, mod} -> mod end)
        _ -> []
      end

    [base | plugin_mods]
    |> Enum.uniq()
  end

  defp lifecycle_pipeline_hook?(name, arity) when is_atom(name) and is_integer(arity) do
    # Pipeline-style hooks transform their inputs. These are the "before_*" hooks
    # used by domain flows.
    name in [
      :before_lobby_create,
      :before_lobby_join,
      :before_lobby_leave,
      :before_lobby_update,
      :before_lobby_delete,
      :before_user_kicked
    ] and arity > 0
  end

  defp run_before_pipeline(mods, name, args, opts, timeout) do
    arity = length(args)

    if Enum.any?(mods, &function_exported?(&1, name, arity)) do
      mods
      |> Enum.reduce_while(args, fn mod, current_args ->
        pipeline_step(mod, name, current_args, opts, timeout, arity)
      end)
      |> case do
        {:error, reason} -> {:error, reason}
        final_args -> {:ok, finalize_pipeline_value(name, final_args)}
      end
    else
      defaults_for_missing_callback(name, args)
    end
  end

  defp pipeline_step(mod, name, current_args, opts, timeout, arity)
       when is_atom(mod) and is_atom(name) and is_list(current_args) and is_list(opts) and
              is_integer(timeout) and is_integer(arity) do
    if function_exported?(mod, name, arity) do
      mod
      |> safe_apply_raw(name, current_args, opts, timeout)
      |> handle_pipeline_apply_result(name, current_args)
    else
      {:cont, current_args}
    end
  end

  defp handle_pipeline_apply_result({:ok, {:error, reason}}, _name, _current_args),
    do: {:halt, {:error, reason}}

  defp handle_pipeline_apply_result({:error, reason}, _name, _current_args),
    do: {:halt, {:error, reason}}

  defp handle_pipeline_apply_result({:ok, {:ok, new}}, name, current_args) do
    case normalize_pipeline_args(name, new, current_args) do
      {:ok, new_args} -> {:cont, new_args}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp handle_pipeline_apply_result({:ok, new}, name, current_args) do
    # For convenience, allow before_* hooks to return a raw value and treat it
    # like {:ok, value}.
    handle_pipeline_apply_result({:ok, {:ok, new}}, name, current_args)
  end

  defp normalize_pipeline_args(:before_lobby_update, value, current_args)
       when is_list(current_args) and length(current_args) == 2 do
    case value do
      tuple when is_tuple(tuple) and tuple_size(tuple) == 2 -> {:ok, Tuple.to_list(tuple)}
      attrs -> {:ok, [Enum.at(current_args, 0), attrs]}
    end
  end

  defp normalize_pipeline_args(_name, value, current_args) when is_list(current_args) do
    arity = length(current_args)

    cond do
      is_tuple(value) and tuple_size(value) == arity ->
        {:ok, Tuple.to_list(value)}

      arity == 1 ->
        {:ok, [value]}

      true ->
        {:error, {:invalid_arity, arity}}
    end
  end

  defp finalize_pipeline_value(:before_lobby_update, args)
       when is_list(args) and length(args) == 2 do
    Enum.at(args, 1)
  end

  defp finalize_pipeline_value(name, args) when is_atom(name) and is_list(args) do
    case args do
      [single] ->
        single

      many
      when name in [:before_lobby_join, :before_lobby_leave, :before_user_kicked] ->
        List.to_tuple(many)

      _other ->
        List.to_tuple(args)
    end
  end

  defp run_fanout(mods, name, args, opts, timeout) do
    arity = length(args)

    if Enum.any?(mods, &function_exported?(&1, name, arity)) do
      mods
      |> Enum.reduce(nil, fn mod, first_res ->
        fanout_first_result(mod, name, args, opts, timeout, arity, first_res)
      end)
      |> case do
        {:ok, {:ok, res}} -> {:ok, res}
        {:ok, {:error, err}} -> {:error, err}
        {:ok, res} -> {:ok, res}
        {:error, reason} -> {:error, reason}
        nil -> defaults_for_missing_callback(name, args)
      end
    else
      defaults_for_missing_callback(name, args)
    end
  end

  defp fanout_first_result(mod, name, args, opts, timeout, arity, first_res)
       when is_atom(mod) and is_atom(name) and is_list(args) and is_list(opts) and
              is_integer(timeout) and is_integer(arity) do
    cond do
      not is_nil(first_res) ->
        first_res

      function_exported?(mod, name, arity) ->
        safe_apply_raw(mod, name, args, opts, timeout)

      true ->
        nil
    end
  end

  defp safe_apply_raw(mod, name, args, opts, timeout)
       when is_atom(mod) and is_atom(name) and is_list(args) and is_list(opts) do
    task =
      Task.async(fn ->
        if caller = Keyword.get(opts, :caller) do
          Process.put(:game_server_hook_caller, caller)
        end

        try do
          apply(mod, name, args)
        rescue
          e in FunctionClauseError -> {:error, {:function_clause, Exception.message(e)}}
          e -> {:error, {:exception, Exception.message(e)}}
        catch
          kind, reason -> {:error, {kind, reason}}
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, res} -> {:ok, res}
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, {:exit, reason}}
    end
  end

  defp defaults_for_missing_callback(name, args) do
    default_mod = Default
    arity = length(args)

    if function_exported?(default_mod, name, arity) do
      case apply(default_mod, name, args) do
        {:ok, _} = ok -> ok
        {:error, _} = err -> err
        other -> {:ok, other}
      end
    else
      # Extremely defensive fallback in case the Default module ever
      # changes; default to returning first arg when present.
      {:ok, Enum.at(args, 0)}
    end
  end

  # Helper: extract docs-based signatures into a map name -> %{arity => %{signature: sig, doc: doc_text}}
  defp doc_signatures_for(mod) do
    case Code.fetch_docs(mod) do
      {:docs_v1, _, _, _, _, _, docs} ->
        Enum.reduce(docs, %{}, fn
          {{:function, name, arity}, _line, signatures, doc_text, _meta}, acc ->
            sig_text =
              case signatures do
                [] -> nil
                _ -> Enum.map_join(signatures, "\n", &to_string/1)
              end

            # normalize doc_text which Code.fetch_docs may return as an i18n map
            normalized_doc =
              cond do
                is_binary(doc_text) ->
                  doc_text

                is_map(doc_text) ->
                  Map.get(doc_text, "en") || Map.get(doc_text, :en) ||
                    Enum.join(Map.values(doc_text), "\n")

                true ->
                  nil
              end

            Map.update(
              acc,
              name,
              %{arity => %{signature: sig_text, doc: normalized_doc}},
              fn map ->
                Map.put(map, arity, %{signature: sig_text, doc: normalized_doc})
              end
            )

          _, acc ->
            acc
        end)

      _ ->
        %{}
    end
  end

  defp build_signature(ar, name, parsed_signatures, doc_signatures, spec_map) do
    parsed_entry = Map.get(parsed_signatures, {name, ar})

    parsed_sig =
      if is_map(parsed_entry), do: Map.get(parsed_entry, :signature), else: parsed_entry

    doc_entry = Map.get(Map.get(doc_signatures, name, %{}), ar, %{})
    doc_text = Map.get(parsed_entry || %{}, :doc) || Map.get(doc_entry, :doc)

    typespec_sig = Map.get(spec_map, {name, ar})
    chosen_signature = choose_signature(parsed_sig, doc_entry, typespec_sig)
    example_args = example_args_for(chosen_signature)

    %{
      arity: ar,
      signature: chosen_signature,
      doc: doc_text,
      example_args: example_args
    }
  end

  # Helper: build a map of {{name, arity} => typespec_string} for module specs
  defp spec_map_for(mod) do
    case Code.Typespec.fetch_specs(mod) do
      {:ok, specs} when is_list(specs) ->
        Enum.reduce(specs, %{}, fn
          {{name, arity}, spec_list}, acc when is_list(spec_list) and spec_list != [] ->
            spec = hd(spec_list)

            spec_str =
              try do
                Code.Typespec.spec_to_quoted(name, spec) |> Macro.to_string()
              rescue
                _ -> nil
              end

            if is_binary(spec_str), do: Map.put(acc, {name, arity}, spec_str), else: acc

          _, acc ->
            acc
        end)

      _ ->
        %{}
    end
  end

  defp choose_signature(parsed, doc_entry, typespec_sig) do
    # Prefer parsed -> doc signature -> typespec
    parsed || Map.get(doc_entry || %{}, :signature) || typespec_sig
  end

  defp example_args_for(nil), do: nil

  defp example_args_for(chosen_signature) when is_binary(chosen_signature) do
    if String.contains?(chosen_signature, "(") do
      params =
        chosen_signature
        |> String.trim()
        |> String.replace(~r/^\w+\(/, "")
        |> String.replace(~r/\)$/, "")
        |> String.split(",")
        |> Enum.map(&String.trim/1)

      # If params list is a single empty string it means there are no params
      # (e.g. "fn_name()") — treat as zero-arity and produce an empty list.
      params =
        if params == [""] do
          []
        else
          params
        end

      example_list =
        Enum.map(params, fn
          "" ->
            []

          p ->
            cond do
              String.match?(p, ~r/^\w+\d+$/) -> p
              String.match?(p, ~r/name|user|email|id|msg|message|text/i) -> "name"
              String.match?(p, ~r/count|num|index|n|id\b/i) -> 0
              String.match?(p, ~r/bool|flag|active|enabled|true|false/i) -> true
              String.match?(p, ~r/list|items|arr|_list/i) -> []
              String.match?(p, ~r/map|opts|options|attrs|params|meta/i) -> %{}
              true -> "#{p}"
            end
        end)

      json =
        Enum.map_join(example_list, ", ", fn
          val when is_binary(val) -> "\"#{val}\""
          val when is_integer(val) -> to_string(val)
          other -> inspect(other)
        end)

      # If there are no parameters, we should render [] not [[]].
      if example_list == [] do
        "[]"
      else
        "[#{json}]"
      end
    else
      nil
    end
  end

  @doc """
  Return a list of exported functions on the currently registered hooks module.

  The result is a list of maps like: [%{name: "start_game", arities: [2,3]}, ...]
  This is useful for tooling and admin UI to display what RPCs are available.
  """
  def exported_functions(mod \\ module()) when is_atom(mod) do
    case Code.ensure_loaded(mod) do
      {:module, _} ->
        # Exclude functions coming from the default implementation - show only
        # functions uniquely exported by the user-provided hooks module.
        default_names =
          Default.__info__(:functions)
          |> Enum.map(fn {n, _} -> n end)
          |> MapSet.new()

        # Also exclude internal hooks and scheduled callbacks
        internal = internal_hooks()
        scheduled = GameServer.Schedule.registered_callbacks()
        excluded = MapSet.union(default_names, MapSet.union(internal, scheduled))

        # Group functions by name -> arities and then filter out the excluded set
        func_map =
          mod.__info__(:functions)
          |> Enum.group_by(fn {name, _arity} -> name end, fn {_name, arity} -> arity end)
          |> Enum.reject(fn {name, _arities} -> MapSet.member?(excluded, name) end)

        # Extract docs-based signatures from compiled module docs
        doc_signatures = doc_signatures_for(mod)

        # Source-based signature parsing (via HOOKS_FILE_PATH / :hooks_file_path)
        # has been removed. We only use BEAM metadata (docs + typespecs).
        parsed_signatures = %{}

        # Extract typespecs -> signature strings
        spec_map = spec_map_for(mod)

        func_map
        |> Enum.map(fn {name, arities} ->
          sigs =
            Enum.map(
              arities,
              &build_signature(&1, name, parsed_signatures, doc_signatures, spec_map)
            )

          %{name: to_string(name), arities: Enum.sort(arities), signatures: sigs}
        end)

      {:error, _} ->
        []
    end
  end

  defp resolve_caller(opts) when is_list(opts) do
    case Keyword.get(opts, :caller) do
      %User{} = _u ->
        opts

      %{} = _m ->
        # Do not resolve maps with an :id here. Keep map callers untouched so
        # callers who pass a user-like map will receive it verbatim.
        opts

      id when is_integer(id) ->
        try do
          Keyword.put(opts, :caller, GameServer.Accounts.get_user!(id))
        rescue
          Ecto.NoResultsError -> opts
        end

      _ ->
        opts
    end
  end

  defp resolve_caller(other), do: other

  @doc """
  When a hooks function is executed via `call/3` or `internal_call/3`, an
  optional `:caller` can be provided in the options. The caller will be
  injected into the spawned task's process dictionary and is accessible via
  `GameServer.Hooks.caller/0` (the raw value) or `caller_id/0` (the numeric id
  when the value is a user struct or map containing `:id`).
  """
  @spec caller() :: any() | nil
  def caller do
    Process.get(:game_server_hook_caller)
  end

  @spec caller_id() :: integer() | nil
  def caller_id do
    case caller() do
      %User{id: id} when is_integer(id) -> id
      %{} = m when is_map(m) -> Map.get(m, :id) || Map.get(m, "id")
      id when is_integer(id) -> id
      _ -> nil
    end
  end

  @doc "Return the user struct for the current caller when available. This will
  attempt to resolve the caller via GameServer.Accounts.get_user!/1 when the
  caller is an integer id or a map containing an `:id` key. Returns nil when
  no caller or user is found."
  @spec caller_user() :: GameServer.Accounts.User.t() | nil
  def caller_user do
    case caller() do
      %User{} = u ->
        u

      %{} = m ->
        id = Map.get(m, :id) || Map.get(m, "id")

        if is_integer(id) do
          try do
            GameServer.Accounts.get_user!(id)
          rescue
            Ecto.NoResultsError -> nil
          end
        else
          nil
        end

      id when is_integer(id) ->
        try do
          GameServer.Accounts.get_user!(id)
        rescue
          Ecto.NoResultsError -> nil
        end

      _ ->
        nil
    end
  end
end

defmodule GameServer.Hooks.Default do
  @moduledoc "Default no-op implementation for GameServer.Hooks"
  @behaviour GameServer.Hooks

  @impl true
  def after_startup, do: :ok

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

  @impl true
  @doc """
  Default implementation for `before_kv_get/2` — always allow public reads.
  """
  def before_kv_get(_key, _opts), do: :public
end
