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
  alias GameServer.Hooks.Default, as: Default
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

  # (friends hooks removed - see config / code changes)

  @doc "Return the configured module that implements the hooks behaviour."
  def module do
    case Application.get_env(:game_server, :hooks_module, Default) do
      nil -> Default
      mod -> mod
    end
  end

  # Parse the source file to extract function parameter names for the
  # given module. Returns a map keyed by {name, arity} -> signature string.
  defp parse_signatures_from_file(path, mod) do
    with {:ok, src} <- File.read(path),
         {:ok, quoted} <- Code.string_to_quoted(src) do
      # find the defmodule AST whose module name matches the provided module
      Enum.reduce(find_module_asts(quoted, mod), %{}, fn {_mod_ast, do_block}, acc ->
        {_ast, {acc2, _last_doc}} =
          Macro.prewalk(do_block, {acc, nil}, fn
            # handle definitions with guards (eg. def foo(x) when is_binary(x))
            {:def, _meta, [{:when, _when_meta, [{name, _nmeta, args_ast}, _guard]}, _body]} = node,
            {acc_inner, last_doc} ->
              arity = length(args_ast || [])

              arg_names =
                Enum.map(args_ast || [], fn
                  {a, _, _} when is_atom(a) -> to_string(a)
                  _ -> "_"
                end)

              sig = "#{name}(#{Enum.join(arg_names, ", ")})"
              doc_text = if is_binary(last_doc), do: last_doc, else: nil
              returns_text = returns_from_doc(doc_text)

              {node,
               {Map.put(acc_inner, {name, arity}, %{
                  signature: sig,
                  doc: doc_text,
                  returns: returns_text
                }), nil}}

            {:def, _meta, [{name, _nmeta, args_ast}, _body]} = node, {acc_inner, last_doc} ->
              arity = length(args_ast || [])

              arg_names =
                Enum.map(args_ast || [], fn
                  {a, _, _} when is_atom(a) -> to_string(a)
                  _ -> "_"
                end)

              sig = "#{name}(#{Enum.join(arg_names, ", ")})"
              doc_text = if is_binary(last_doc), do: last_doc, else: nil
              returns_text = returns_from_doc(doc_text)

              {node,
               {Map.put(acc_inner, {name, arity}, %{
                  signature: sig,
                  doc: doc_text,
                  returns: returns_text
                }), nil}}

            {:@, _meta, [{:doc, _doc_meta, [doc_val]}]} = node, {acc_inner, _last_doc} ->
              # capture module attribute @doc which applies to the next def
              doc_text = if is_binary(doc_val), do: doc_val, else: nil
              {node, {acc_inner, doc_text}}

            node, {acc_inner, last_doc} ->
              {node, {acc_inner, last_doc}}
          end)

        acc2
      end)
    else
      _ -> %{}
    end
  end

  defp find_module_asts(ast, mod) do
    mod_name_parts = Module.split(mod)

    results =
      Macro.prewalk(ast, [], fn
        {:defmodule, _meta, [{:__aliases__, _m2, aliases}, do_block]} = node, acc ->
          if Module.split(Module.concat(aliases)) == mod_name_parts do
            {node, [{node, do_block} | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    elem(results, 1)
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

    # Disallow calling internal lifecycle callbacks via the public `call/3`
    # API. Domain code should use `internal_call/3` which knows how to
    # handle optional/missing lifecycle callbacks safely and provide
    # sensible defaults.
    if name in internal_hooks() do
      {:error, :disallowed}
    else
      if function_exported?(mod, name, arity) do
        timeout =
          Keyword.get(
            opts,
            :timeout_ms,
            Application.get_env(:game_server, :hooks_call_timeout, 5_000)
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
      else
        {:error, :not_implemented}
      end
    end
  end

  @doc "Call an internal lifecycle callback. When a callback is missing this
  returns a sensible default (eg. {:ok, attrs} for before callbacks) so
  domain code doesn't need to handle missing hooks specially in most cases."
  def internal_call(name, args \\ [], opts \\ [])
      when is_list(args) and (is_atom(name) or is_binary(name)) do
    name = if is_binary(name), do: String.to_atom(name), else: name
    mod = module()
    # resolve caller before spawning a task in case the caller was provided as
    # a simple id (avoids sandbox issues for spawned tasks in tests)
    opts = resolve_caller(opts)

    timeout =
      Keyword.get(
        opts,
        :timeout_ms,
        Application.get_env(:game_server, :hooks_call_timeout, 5_000)
      )

    arity = length(args)

    if function_exported?(mod, name, arity) do
      task =
        Task.async(fn ->
          # Propagate caller context to lifecycle callbacks as well
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
    else
      defaults_for_missing_callback(name, args)
    end
  end

  defp internal_hooks do
    # set of callback names considered internal/lifecycle hooks and not
    # callable through the public `call/3` interface.
    MapSet.new([
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
      :after_lobby_host_change
    ])
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

  defp parsed_signatures_for(src_path, mod) do
    if is_binary(src_path) and File.exists?(src_path) do
      parse_signatures_from_file(src_path, mod)
    else
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
  def exported_functions do
    mod = module()

    case Code.ensure_loaded(mod) do
      {:module, _} ->
        # Exclude functions coming from the default implementation - show only
        # functions uniquely exported by the user-provided hooks module.
        default_names =
          Default.__info__(:functions)
          |> Enum.map(fn {n, _} -> n end)
          |> MapSet.new()

        # Group functions by name -> arities and then filter out the default set
        func_map =
          mod.__info__(:functions)
          |> Enum.group_by(fn {name, _arity} -> name end, fn {_name, arity} -> arity end)
          |> Enum.reject(fn {name, _arities} -> MapSet.member?(default_names, name) end)

        # Extract docs-based signatures from compiled module docs
        doc_signatures = doc_signatures_for(mod)

        # If available, try to parse function signatures from the source file
        src_path =
          Application.get_env(:game_server, :hooks_file_path) || System.get_env("HOOKS_FILE_PATH")

        parsed_signatures = parsed_signatures_for(src_path, mod)

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

  defp returns_from_doc(t) when is_binary(t) do
    t
    |> String.split("\n")
    |> Enum.find_value(nil, fn line ->
      l = String.trim(line)

      if String.match?(l, ~r/^Returns?:/i),
        do: Regex.replace(~r/^Returns?:\s*/i, l, ""),
        else: nil
    end)
  end

  defp returns_from_doc(_), do: nil

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
