defmodule GameServer.Hooks do
  @moduledoc """
  Behaviour for application-level hooks / callbacks.

  Implement this behaviour to receive lifecycle events from core flows
  (registration, login, provider linking, deletion) and run custom logic.

  A module implementing this behaviour can be configured with

      config :game_server_core, :hooks_module, MyApp.HooksImpl

  The default implementation is a no-op.
  """

  alias GameServer.Accounts.User
  alias GameServer.Achievements.Achievement
  alias GameServer.Chat.Message
  alias GameServer.Groups.Group
  alias GameServer.Hooks.Default, as: Default
  alias GameServer.Hooks.PluginManager
  alias GameServer.Lobbies.Lobby
  alias GameServer.Parties.Party
  alias GameServer.Payments.Entitlement
  alias GameServer.Payments.Purchase
  require Logger

  @type hook_result(attrs_or_user) :: {:ok, attrs_or_user} | {:error, term()}

  @type kv_access ::
          :public
          | :owner_only
          | :lobby_members_only
          | :owner_or_lobby_member
          | :admin_only
          | :server_only

  @type kv_access_result :: kv_access() | {:ok, kv_access()} | {:error, term()}

  @kv_access_levels [
    :public,
    :owner_only,
    :lobby_members_only,
    :owner_or_lobby_member,
    :admin_only,
    :server_only
  ]

  @typedoc """
  Options passed to hooks that accept an options map/keyword list.

  Common keys include `:user_id`, `:lobby_id`, and other domain-specific options.
  Hooks may accept either a map or keyword list for convenience.
  """
  @type kv_opts :: map() | keyword()

  @callback after_startup() :: any()

  @callback before_stop() :: any()

  @doc """
  Called before a new user row is inserted, on every registration path:
  email, device, and all OAuth providers (which register mid-login).

  Receives the tentative user (not yet inserted, `id` is `nil`) and the
  registration attrs (string keys), which already contain the generated
  `"username"`. Return `{:ok, attrs}` — possibly with a different username
  or other changes — or `{:error, reason}` to abort the registration.

  Core re-validates after all hooks ran: format and uniqueness are not
  overridable. A hook-supplied username that is invalid or already taken is
  replaced with a generated one (a plugin bug must never lock a player out
  of login). For strict policy on player-initiated changes — profanity or
  reserved names — use `c:before_user_update/2`, where errors are returned
  to the player:

      def before_user_update(_user, %{"username" => name} = attrs) do
        if MyGame.Profanity.allowed?(name),
          do: {:ok, attrs},
          else: {:error, :invalid_username}
      end

      def before_user_update(_user, attrs), do: {:ok, attrs}
  """
  @callback before_user_register(User.t(), GameServer.Types.user_registration_hook_attrs()) ::
              hook_result(GameServer.Types.user_registration_hook_attrs())

  @callback after_user_register(User.t()) :: any()

  @callback after_user_login(User.t()) :: any()

  @callback before_user_update(User.t(), map()) :: hook_result(map())
  @callback after_user_updated(User.t()) :: any()

  @callback after_user_online(User.t()) :: any()
  @callback after_user_offline(User.t()) :: any()
  @callback after_user_deleted(User.t()) :: any()

  @doc """
  Handle a dynamically-exported RPC function.

  This callback is used for function names that were registered at runtime (eg.
  via a plugin's `after_startup/0` return value) and therefore may not exist as
  exported Elixir functions on the hooks module.

  Receives the function name and the argument list.
  """
  @callback on_custom_hook(String.t(), list()) :: any()

  # Lobby lifecycle hooks
  @callback before_lobby_create(map()) :: hook_result(map())
  @callback after_lobby_create(Lobby.t()) :: any()

  @callback before_lobby_join(User.t(), Lobby.t(), keyword()) ::
              hook_result({User.t(), Lobby.t(), keyword()})
  @callback after_lobby_join(User.t(), Lobby.t()) :: any()

  @callback before_group_create(User.t(), map()) :: hook_result(map())
  @callback after_group_create(Group.t()) :: any()

  @callback before_group_join(User.t(), Group.t(), map()) ::
              hook_result({User.t(), Group.t(), map()})

  @callback before_group_update(Group.t(), map()) :: hook_result(map())
  @callback after_group_update(Group.t()) :: any()

  @callback after_group_join(String.t(), Group.t()) :: any()
  @callback after_group_leave(String.t(), String.t()) :: any()
  @callback after_group_delete(Group.t()) :: any()
  @callback after_group_kick(String.t(), String.t(), String.t()) :: any()

  @callback before_group_delete(Group.t()) :: hook_result(Group.t())
  @callback before_group_kick(String.t(), String.t(), String.t()) ::
              hook_result({String.t(), String.t(), String.t()})

  # Party lifecycle hooks
  @callback before_party_create(User.t(), map()) :: hook_result(map())
  @callback after_party_create(Party.t()) :: any()

  @callback before_party_update(Party.t(), map()) :: hook_result(map())
  @callback after_party_update(Party.t()) :: any()

  @callback after_party_join(User.t(), Party.t()) :: any()
  @callback after_party_leave(User.t(), String.t()) :: any()
  @callback after_party_kick(User.t(), User.t(), Party.t()) :: any()
  @callback after_party_disband(Party.t()) :: any()

  @callback before_party_join(User.t(), Party.t()) :: hook_result({User.t(), Party.t()})
  @callback before_party_kick(User.t(), User.t(), Party.t()) ::
              hook_result({User.t(), User.t(), Party.t()})

  # Achievement lifecycle hooks
  @callback after_achievement_unlocked(String.t(), Achievement.t()) :: any()

  # Leaderboard lifecycle hooks
  @callback after_score_submitted(GameServer.Leaderboards.Record.t()) :: any()

  # Payment lifecycle hooks
  @callback after_purchase_fulfilled(Purchase.t()) :: any()
  @callback after_purchase_revoked(Purchase.t()) :: any()
  @callback after_entitlement_changed(Entitlement.t()) :: any()
  @optional_callbacks after_purchase_fulfilled: 1,
                      after_purchase_revoked: 1,
                      after_entitlement_changed: 1

  @callback before_chat_message(User.t(), map()) :: hook_result(map())
  @callback after_chat_message(Message.t()) :: any()

  @callback after_lobby_leave(User.t(), Lobby.t()) :: any()

  @callback before_lobby_update(Lobby.t(), map()) :: hook_result(map())
  @callback after_lobby_update(Lobby.t()) :: any()

  @callback before_lobby_delete(Lobby.t()) :: hook_result(Lobby.t())
  @callback after_lobby_delete(Lobby.t()) :: any()

  @callback before_user_kicked(User.t(), User.t(), Lobby.t()) ::
              hook_result({User.t(), User.t(), Lobby.t()})
  @callback after_user_kicked(User.t(), User.t(), Lobby.t()) :: any()

  @doc """
  Called before a KV `get/2` is performed. Implementations should return
  one of these client KV API access decisions:

  - `:public` — any authenticated client can read.
  - `:owner_only` — only the caller matching the requested `user_id` can read.
  - `:lobby_members_only` — only callers in the requested `lobby_id` can read.
  - `:owner_or_lobby_member` — caller may match either requested `user_id` or `lobby_id`.
  - `:admin_only` — only admins can read through the client KV API.
  - `:server_only` — no client KV reads.

  Server-side `GameServer.KV.get/2` calls are unaffected.

  Receives the `key` and an `opts` map/keyword (see `t:kv_opts/0`). Return
  either the bare atom (e.g. `:public`) or `{:ok, :public}`; return `{:error, reason}`
  to block the read.
  """
  @callback before_kv_get(String.t(), kv_opts()) :: kv_access_result()

  @callback after_lobby_host_change(Lobby.t(), String.t()) :: any()

  @doc "Return the configured module that implements the hooks behaviour."
  def module do
    # Primary config lives under :game_server_core.
    # We also support :game_server as a backward-compatible fallback because
    # older docs and apps may have set it there.
    case Application.get_env(:game_server_core, :hooks_module) ||
           Application.get_env(:game_server, :hooks_module) do
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
    name =
      if is_binary(name) do
        try do
          String.to_existing_atom(name)
        rescue
          ArgumentError -> nil
        end
      else
        name
      end

    if is_nil(name) do
      {:error, :not_implemented}
    else
      do_call(name, args, opts)
    end
  end

  defp do_call(name, args, opts) do
    mod = module()
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

      # private functions (defp) are not exported and will fall through to
      # :not_implemented.

      not exports_function?(mod, name, arity) ->
        {:error, :not_implemented}

      true ->
        timeout =
          Keyword.get(
            opts,
            :timeout_ms,
            Application.get_env(:game_server_core, :hooks_call_timeout, 60_000)
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
    name = if is_binary(name), do: String.to_existing_atom(name), else: name
    # resolve caller before spawning a task in case the caller was provided as
    # a simple id (avoids sandbox issues for spawned tasks in tests)
    opts = resolve_caller(opts)

    mods = lifecycle_modules()

    timeout =
      Keyword.get(
        opts,
        :timeout_ms,
        Application.get_env(:game_server_core, :hooks_call_timeout, 60_000)
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

    if exports_function?(mod, name, arity) do
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

  @doc "Returns the set of internal lifecycle hook names that are not callable\n  through the public RPC interface."
  @spec internal_hooks() :: MapSet.t(atom())
  def internal_hooks do
    MapSet.new([
      :after_startup,
      :before_stop,
      :before_user_register,
      :after_user_register,
      :after_user_login,
      :after_user_updated,
      :after_user_online,
      :after_user_offline,
      :after_user_deleted,
      :before_user_update,
      :before_lobby_create,
      :after_lobby_create,
      :before_group_create,
      :after_group_create,
      :before_lobby_join,
      :after_lobby_join,
      :before_group_join,
      :before_group_update,
      :after_group_update,
      :after_group_join,
      :after_group_leave,
      :after_group_delete,
      :after_group_kick,
      :before_group_delete,
      :before_group_kick,
      :before_party_create,
      :after_party_create,
      :before_party_update,
      :after_party_update,
      :after_party_join,
      :after_party_leave,
      :after_party_kick,
      :after_party_disband,
      :before_party_join,
      :before_party_kick,
      :before_chat_message,
      :after_chat_message,
      :after_lobby_leave,
      :before_lobby_update,
      :after_lobby_update,
      :before_lobby_delete,
      :after_lobby_delete,
      :before_user_kicked,
      :after_user_kicked,
      :after_lobby_host_change,
      :after_achievement_unlocked,
      :after_score_submitted,
      :after_purchase_fulfilled,
      :after_purchase_revoked,
      :after_entitlement_changed,
      :on_custom_hook,
      :before_kv_get
    ])
  end

  defp lifecycle_modules do
    base = module()

    plugin_mods =
      Enum.map(PluginManager.hook_modules(), fn {_name, mod} -> mod end)

    [base | plugin_mods]
    |> Enum.uniq()
  end

  defp lifecycle_pipeline_hook?(name, arity) when is_atom(name) and is_integer(arity) do
    # Pipeline-style hooks transform their inputs. These are the "before_*" hooks
    # used by domain flows.
    name in [
      :before_user_register,
      :before_user_update,
      :before_lobby_create,
      :before_group_create,
      :before_lobby_join,
      :before_group_join,
      :before_group_update,
      :before_party_create,
      :before_party_update,
      :before_chat_message,
      :before_lobby_update,
      :before_lobby_delete,
      :before_user_kicked,
      :before_group_delete,
      :before_group_kick,
      :before_party_join,
      :before_party_kick
    ] and arity > 0
  end

  # Ensure all plain-map arguments passed to before_* hooks have string keys.
  # Structs (User, Group, etc.) are left untouched.
  defp normalize_hook_args(args) when is_list(args) do
    Enum.map(args, fn
      %_{} = struct -> struct
      m when is_map(m) -> stringify_keys(m)
      other -> other
    end)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp run_before_pipeline(mods, name, args, opts, timeout) do
    arity = length(args)
    args = normalize_hook_args(args)

    if Enum.any?(mods, &exports_function?(&1, name, arity)) do
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
    if exports_function?(mod, name, arity) do
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
      {:ok, new_args} -> {:cont, normalize_hook_args(new_args)}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp handle_pipeline_apply_result({:ok, new}, name, current_args) do
    # For convenience, allow before_* hooks to return a raw value and treat it
    # like {:ok, value}.
    handle_pipeline_apply_result({:ok, {:ok, new}}, name, current_args)
  end

  defp normalize_pipeline_args(:before_group_create, value, current_args)
       when is_list(current_args) and length(current_args) == 2 do
    case value do
      tuple when is_tuple(tuple) and tuple_size(tuple) == 2 -> {:ok, Tuple.to_list(tuple)}
      attrs -> {:ok, [Enum.at(current_args, 0), attrs]}
    end
  end

  defp normalize_pipeline_args(:before_chat_message, value, current_args)
       when is_list(current_args) and length(current_args) == 2 do
    case value do
      tuple when is_tuple(tuple) and tuple_size(tuple) == 2 -> {:ok, Tuple.to_list(tuple)}
      attrs -> {:ok, [Enum.at(current_args, 0), attrs]}
    end
  end

  defp normalize_pipeline_args(:before_party_create, value, current_args)
       when is_list(current_args) and length(current_args) == 2 do
    case value do
      tuple when is_tuple(tuple) and tuple_size(tuple) == 2 -> {:ok, Tuple.to_list(tuple)}
      attrs -> {:ok, [Enum.at(current_args, 0), attrs]}
    end
  end

  defp normalize_pipeline_args(:before_party_update, value, current_args)
       when is_list(current_args) and length(current_args) == 2 do
    case value do
      tuple when is_tuple(tuple) and tuple_size(tuple) == 2 -> {:ok, Tuple.to_list(tuple)}
      attrs -> {:ok, [Enum.at(current_args, 0), attrs]}
    end
  end

  defp normalize_pipeline_args(:before_lobby_update, value, current_args)
       when is_list(current_args) and length(current_args) == 2 do
    case value do
      tuple when is_tuple(tuple) and tuple_size(tuple) == 2 -> {:ok, Tuple.to_list(tuple)}
      attrs -> {:ok, [Enum.at(current_args, 0), attrs]}
    end
  end

  defp normalize_pipeline_args(:before_user_update, value, current_args)
       when is_list(current_args) and length(current_args) == 2 do
    case value do
      tuple when is_tuple(tuple) and tuple_size(tuple) == 2 -> {:ok, Tuple.to_list(tuple)}
      attrs -> {:ok, [Enum.at(current_args, 0), attrs]}
    end
  end

  defp normalize_pipeline_args(:before_user_register, value, current_args)
       when is_list(current_args) and length(current_args) == 2 do
    case value do
      tuple when is_tuple(tuple) and tuple_size(tuple) == 2 -> {:ok, Tuple.to_list(tuple)}
      attrs -> {:ok, [Enum.at(current_args, 0), attrs]}
    end
  end

  defp normalize_pipeline_args(:before_group_update, value, current_args)
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

  defp finalize_pipeline_value(:before_group_create, args)
       when is_list(args) and length(args) == 2 do
    Enum.at(args, 1)
  end

  defp finalize_pipeline_value(:before_chat_message, args)
       when is_list(args) and length(args) == 2 do
    Enum.at(args, 1)
  end

  defp finalize_pipeline_value(:before_lobby_update, args)
       when is_list(args) and length(args) == 2 do
    Enum.at(args, 1)
  end

  defp finalize_pipeline_value(:before_user_update, args)
       when is_list(args) and length(args) == 2 do
    Enum.at(args, 1)
  end

  defp finalize_pipeline_value(:before_user_register, args)
       when is_list(args) and length(args) == 2 do
    Enum.at(args, 1)
  end

  defp finalize_pipeline_value(:before_group_update, args)
       when is_list(args) and length(args) == 2 do
    Enum.at(args, 1)
  end

  defp finalize_pipeline_value(:before_party_create, args)
       when is_list(args) and length(args) == 2 do
    Enum.at(args, 1)
  end

  defp finalize_pipeline_value(:before_party_update, args)
       when is_list(args) and length(args) == 2 do
    Enum.at(args, 1)
  end

  defp finalize_pipeline_value(name, args) when is_atom(name) and is_list(args) do
    case args do
      [single] ->
        single

      many
      when name in [
             :before_lobby_join,
             :before_group_join,
             :before_user_kicked
           ] ->
        List.to_tuple(many)

      _other ->
        List.to_tuple(args)
    end
  end

  defp run_fanout(mods, name, args, opts, timeout) do
    arity = length(args)

    exporting_mods = Enum.filter(mods, &exports_function?(&1, name, arity))

    case exporting_mods do
      [] ->
        defaults_for_missing_callback(name, args)

      _ when name == :before_kv_get and arity == 2 ->
        run_before_kv_get(exporting_mods, args, opts, timeout)

      [first_mod | rest] ->
        first_res = safe_apply_raw(first_mod, name, args, opts, timeout)

        rest
        |> Enum.each(fn mod ->
          mod
          |> safe_apply_raw(name, args, opts, timeout)
          |> log_non_primary_hook_failure(mod, name)
        end)

        case first_res do
          {:ok, {:ok, res}} -> {:ok, res}
          {:ok, {:error, err}} -> {:error, err}
          {:ok, res} -> {:ok, res}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp run_before_kv_get(mods, args, opts, timeout) when is_list(mods) do
    # Security-sensitive hook: default to :public. Multiple plugin decisions
    # are intersected; incompatible restrictions fail closed to :server_only.
    # If any hook errors (timeout/exception), fail closed.
    mods
    |> Enum.reduce_while(:public, fn mod, decision ->
      mod
      |> safe_apply_raw(:before_kv_get, args, opts, timeout)
      |> normalize_before_kv_get_result()
      |> case do
        {:ok, access} ->
          {:cont, combine_kv_access(decision, access)}

        {:error, reason} ->
          Logger.warning("Hooks.before_kv_get failed mod=#{inspect(mod)}: #{inspect(reason)}")

          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, _} = err -> err
      decision -> {:ok, decision}
    end
  end

  defp combine_kv_access(:public, access), do: access
  defp combine_kv_access(access, :public), do: access
  defp combine_kv_access(:server_only, _access), do: :server_only
  defp combine_kv_access(_access, :server_only), do: :server_only
  defp combine_kv_access(access, access), do: access
  defp combine_kv_access(:owner_or_lobby_member, :owner_only), do: :owner_only
  defp combine_kv_access(:owner_only, :owner_or_lobby_member), do: :owner_only
  defp combine_kv_access(:owner_or_lobby_member, :lobby_members_only), do: :lobby_members_only
  defp combine_kv_access(:lobby_members_only, :owner_or_lobby_member), do: :lobby_members_only
  defp combine_kv_access(_left, _right), do: :server_only

  defp normalize_before_kv_get_result({:error, reason}), do: {:error, reason}
  defp normalize_before_kv_get_result({:ok, {:error, reason}}), do: {:error, reason}

  defp normalize_before_kv_get_result({:ok, {:ok, decision}})
       when decision in @kv_access_levels,
       do: {:ok, decision}

  defp normalize_before_kv_get_result({:ok, decision}) when decision in @kv_access_levels,
    do: {:ok, decision}

  defp normalize_before_kv_get_result({:ok, other}), do: {:error, {:invalid_return, other}}

  defp log_non_primary_hook_failure({:error, reason}, mod, name) do
    Logger.warning(
      "Hooks callback failed mod=#{inspect(mod)} name=#{inspect(name)}: #{inspect(reason)}"
    )
  end

  defp log_non_primary_hook_failure({:ok, {:error, reason}}, mod, name) do
    Logger.warning(
      "Hooks callback failed mod=#{inspect(mod)} name=#{inspect(name)}: #{inspect(reason)}"
    )
  end

  defp log_non_primary_hook_failure(_ok, _mod, _name), do: :ok

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

    if exports_function?(default_mod, name, arity) do
      case apply(default_mod, name, args) do
        {:ok, _} = ok -> ok
        {:error, _} = err -> err
        other -> {:ok, other}
      end
    else
      # Fallback when the Default module doesn't export the callback.
      # For pipeline hooks that transform multi-arity args, use
      # finalize_pipeline_value to return the correct element (e.g. attrs
      # rather than user for before_group_create/2).
      if lifecycle_pipeline_hook?(name, arity) and arity > 0 do
        {:ok, finalize_pipeline_value(name, args)}
      else
        {:ok, Enum.at(args, 0)}
      end
    end
  end

  defp exports_function?(mod, name, arity)
       when is_atom(mod) and is_atom(name) and is_integer(arity) do
    Code.ensure_loaded?(mod) and function_exported?(mod, name, arity)
  end

  defp exports_function?(_mod, _name, _arity), do: false

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

        excluded =
          [default_names, internal, scheduled]
          |> Enum.flat_map(&MapSet.to_list/1)
          |> MapSet.new()

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

      id when is_binary(id) ->
        case GameServer.Accounts.get_user(id) do
          %User{} = user -> Keyword.put(opts, :caller, user)
          nil -> opts
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

  @spec caller_id() :: String.t() | nil
  def caller_id do
    case caller() do
      %User{id: id} when is_binary(id) -> id
      %{} = m when is_map(m) -> Map.get(m, :id) || Map.get(m, "id")
      id when is_binary(id) -> id
      _ -> nil
    end
  end

  @doc "Return the user struct for the current caller when available. This will
  attempt to resolve the caller via GameServer.Accounts.get_user!/1 when the
  caller is a user id or a map containing an `:id` key. Returns nil when
  no caller or user is found."
  @spec caller_user() :: GameServer.Accounts.User.t() | nil
  def caller_user do
    case caller() do
      %User{} = u ->
        u

      %{} = m ->
        id = Map.get(m, :id) || Map.get(m, "id")

        if is_binary(id), do: GameServer.Accounts.get_user(id), else: nil

      id when is_binary(id) ->
        GameServer.Accounts.get_user(id)

      _ ->
        nil
    end
  end
end

defmodule GameServer.Hooks.Default do
  @moduledoc "Default no-op implementation for GameServer.Hooks"
  @behaviour GameServer.Hooks

  alias GameServer.Accounts.User
  alias GameServer.Payments.Entitlement
  alias GameServer.Payments.Purchase

  @impl true
  def after_startup, do: :ok

  @impl true
  def before_stop, do: :ok

  @impl true
  def before_user_register(_user, attrs), do: {:ok, attrs}

  @impl true
  def after_user_register(_user), do: :ok

  @impl true
  def after_user_login(_user), do: :ok

  @impl true
  def after_user_updated(_user), do: :ok

  @impl true
  def after_user_online(_user), do: :ok

  @impl true
  def after_user_offline(_user), do: :ok

  @impl true
  def after_user_deleted(_user), do: :ok

  @impl true
  def before_user_update(_user, attrs), do: {:ok, attrs}

  @impl true
  def before_lobby_create(attrs), do: {:ok, attrs}

  @impl true
  def after_lobby_create(_lobby), do: :ok

  @impl true
  def before_lobby_join(user, lobby, opts), do: {:ok, {user, lobby, opts}}

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
  def before_group_delete(group), do: {:ok, group}

  @impl true
  def before_group_kick(admin_id, target_id, group_id), do: {:ok, {admin_id, target_id, group_id}}

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
  def before_party_join(user, party), do: {:ok, {user, party}}

  @impl true
  def before_party_kick(target, leader, party), do: {:ok, {target, leader, party}}

  @impl true
  def before_chat_message(_user, attrs), do: {:ok, attrs}

  @impl true
  def after_chat_message(_message), do: :ok

  @impl true
  def after_lobby_join(_user, _lobby), do: :ok

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

  @impl true
  def after_achievement_unlocked(_user_id, _achievement), do: :ok

  @impl true
  def after_score_submitted(_record), do: :ok

  @impl true
  def after_purchase_fulfilled(%Purchase{} = purchase) do
    update_user_payment_metadata(purchase.user_id, fn metadata ->
      purchase_active = purchase.status == "completed"
      purchase_id = to_string(purchase.id)

      metadata
      |> put_payment_child("purchase_ids", purchase_id, purchase_active)
      |> put_payment_child(
        "purchase_details",
        purchase_id,
        purchase_metadata(purchase, purchase_active)
      )
    end)
  end

  @impl true
  def after_purchase_revoked(%Purchase{} = purchase) do
    update_user_payment_metadata(purchase.user_id, fn metadata ->
      purchase_id = to_string(purchase.id)

      metadata
      |> put_payment_child("purchase_ids", purchase_id, false)
      |> put_payment_child("purchase_details", purchase_id, purchase_metadata(purchase, false))
    end)
  end

  @impl true
  def after_entitlement_changed(%Entitlement{} = entitlement) do
    active = entitlement_active?(entitlement)

    update_user_payment_metadata(entitlement.user_id, fn metadata ->
      entitlement_id = to_string(entitlement.id)

      metadata
      |> put_payment_child("entitlements", entitlement.key, active)
      |> put_payment_child("entitlement_ids", entitlement_id, active)
      |> put_payment_child(
        "entitlement_details",
        entitlement.key,
        entitlement_metadata(entitlement, active)
      )
    end)
  end

  @impl true
  def on_custom_hook(_hook, _args), do: {:error, :not_implemented}

  defp update_user_payment_metadata(user_id, fun)
       when is_binary(user_id) and is_function(fun, 1) do
    case GameServer.Lock.serialize("user_payment_metadata", user_id, fn ->
           apply_user_payment_metadata(user_id, fun)
         end) do
      {:ok, :ok} -> :ok
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_user_payment_metadata(_user_id, _fun), do: :ok

  defp apply_user_payment_metadata(user_id, fun) do
    case GameServer.Accounts.get_user(user_id) do
      %User{} = user -> update_loaded_user_payment_metadata(user, fun)
      nil -> {:error, :user_not_found}
    end
  end

  defp update_loaded_user_payment_metadata(%User{} = user, fun) do
    metadata = fun.(user.metadata)

    case GameServer.Accounts.update_user(user, %{metadata: metadata}) do
      {:ok, _user} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_payment_child(metadata, child_key, item_key, value) do
    payments = metadata |> Map.get("payments") |> map_or_empty()
    child = payments |> Map.get(child_key) |> map_or_empty()

    Map.put(metadata, "payments", Map.put(payments, child_key, Map.put(child, item_key, value)))
  end

  defp map_or_empty(value) when is_map(value), do: value
  defp map_or_empty(_value), do: %{}

  defp purchase_metadata(%Purchase{} = purchase, active) do
    %{
      "active" => active,
      "amount" => purchase.amount,
      "currency" => purchase.currency,
      "order_id" => purchase.order_id,
      "product_id" => purchase.product_id,
      "provider" => purchase.provider,
      "provider_product_id" => purchase.provider_product_id,
      "provider_transaction_id" => purchase.provider_transaction_id,
      "status" => purchase.status,
      "purchased_at" => datetime_iso(purchase.purchased_at),
      "revoked_at" => datetime_iso(purchase.revoked_at)
    }
  end

  defp entitlement_metadata(%Entitlement{} = entitlement, active) do
    %{
      "active" => active,
      "expires_at" => datetime_iso(entitlement.expires_at),
      "id" => entitlement.id,
      "key" => entitlement.key,
      "product_id" => entitlement.product_id,
      "revoked_at" => datetime_iso(entitlement.revoked_at),
      "source_purchase_id" => entitlement.source_purchase_id,
      "status" => entitlement.status
    }
  end

  defp entitlement_active?(%Entitlement{status: "active", expires_at: nil}), do: true

  defp entitlement_active?(%Entitlement{status: "active", expires_at: %DateTime{} = expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now(:second)) == :gt
  end

  defp entitlement_active?(_entitlement), do: false

  defp datetime_iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp datetime_iso(_value), do: nil
end
