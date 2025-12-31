defmodule GameServer.Hooks do
  @moduledoc """
  Behaviour for GameServer hooks/callbacks.

  Implement this behaviour in your hooks module to receive lifecycle events
  from the GameServer and run custom game logic.

  ## Setup

  1. Create a module implementing this behaviour
  2. Configure it in your GameServer instance

  ## Example

      defmodule MyGame.Hooks do
        @behaviour GameServer.Hooks

        @impl true
        def after_user_register(user) do
          # Give new users starting coins
          GameServer.Accounts.update_user(user, %{
            metadata: Map.put(user.metadata || %{}, "coins", 100)
          })
        end

        @impl true
        def after_user_login(user) do
          # Log login
          :ok
        end

        # Lobby hooks
        @impl true
        def before_lobby_create(attrs) do
          # Validate or modify lobby creation attributes
          {:ok, attrs}
        end

        @impl true
        def after_lobby_create(_lobby), do: :ok

        @impl true
        def before_lobby_join(user, lobby, opts) do
          # Check if user can join (e.g., level requirements)
          {:ok, {user, lobby, opts}}
        end

        @impl true
        def after_lobby_join(_user, _lobby), do: :ok

        @impl true
        def before_lobby_leave(user, lobby) do
          {:ok, {user, lobby}}
        end

        @impl true
        def after_lobby_leave(_user, _lobby), do: :ok

        @impl true
        def before_lobby_update(_lobby, attrs) do
          {:ok, attrs}
        end

        @impl true
        def after_lobby_update(_lobby), do: :ok

        @impl true
        def before_lobby_delete(lobby) do
          {:ok, lobby}
        end

        @impl true
        def after_lobby_delete(_lobby), do: :ok

        @impl true
        def before_user_kicked(host, target, lobby) do
          {:ok, {host, target, lobby}}
        end

        @impl true
        def after_user_kicked(_host, _target, _lobby), do: :ok

        @impl true
        def after_lobby_host_change(_lobby, _new_host_id), do: :ok

        # Custom RPC handlers - define your own functions!
        # These are called from game clients via the RPC channel.
        #
        # def give_coins(amount, opts) do
        #   caller = Keyword.get(opts, :caller)
        #   # Update user's coins...
        #   {:ok, %{new_balance: 150}}
        # end
      end

  ## Hook Types

  ### User Lifecycle Hooks

  - `after_user_register/1` - Called after a new user registers
  - `after_user_login/1` - Called after a user logs in

  ### Lobby Lifecycle Hooks

  Before hooks can block operations by returning `{:error, reason}`.
  After hooks are fire-and-forget.

  - `before_lobby_create/1` - Before lobby creation, receives attrs map
  - `after_lobby_create/1` - After lobby is created
  - `before_lobby_join/3` - Before user joins lobby
  - `after_lobby_join/2` - After user joins lobby
  - `before_lobby_leave/2` - Before user leaves lobby
  - `after_lobby_leave/2` - After user leaves lobby
  - `before_lobby_update/2` - Before lobby is updated
  - `after_lobby_update/1` - After lobby is updated
  - `before_lobby_delete/1` - Before lobby is deleted
  - `after_lobby_delete/1` - After lobby is deleted
  - `before_user_kicked/3` - Before user is kicked from lobby
  - `after_user_kicked/3` - After user is kicked from lobby
  - `after_lobby_host_change/2` - After lobby host changes
  - `before_kv_get/2` - Called before a KV `get` to determine whether a key should be publicly readable (`:public`) or restricted (`:private`)

    ## Custom RPC Functions

    Game clients can call RPCs exposed by your hooks module in two ways:

    1. **Exported functions**: any exported function in your hooks module (other
      than the callbacks above) can be called from game clients.

    2. **Dynamic functions (custom hooks)**: your `after_startup/0` callback may
      return a list of dynamic exports describing additional callable function
      names that do **not** need to exist as exported Elixir functions.
      These dynamic calls are dispatched to `on_custom_hook/2`.

      # Client calls: rpc("give_coins", {amount: 50})
      def give_coins(amount, opts) do
        caller = Keyword.get(opts, :caller)
        # Your game logic here
        {:ok, %{success: true}}
      end

  Return values:
  - `{:ok, data}` - Success, data is sent back to client
  - `{:error, reason}` - Error, reason is sent back to client
  - `:ok` - Success with no data
  """

  @typedoc "A user struct from GameServer.Accounts.User"
  @type user :: GameServer.Accounts.User.t()

  @typedoc "A lobby struct from GameServer.Lobbies.Lobby"
  @type lobby :: GameServer.Lobbies.Lobby.t()

  @typedoc "Result type for before hooks"
  @type hook_result(t) :: {:ok, t} | {:error, term()}

  @typedoc """
  A dynamic RPC export returned by `after_startup/0`.

  The minimal shape is:

      %{hook: "custom_hello"}

  Optionally, provide `:meta` for tooling / UI hints:

      %{hook: "custom_hello", meta: %{description: "...", args: [...], example_args: [...]}}

  Note: the runtime also accepts string keys (e.g. `%{"hook" => ...}`), but
  this type focuses on the atom-keyed form.
  """
  @type rpc_export :: %{
          required(:hook) => String.t(),
          optional(:meta) => map()
        }

  @typedoc """
  Options passed to hooks that accept an options map/keyword list.

  Common keys include `:user_id` (pos_integer) and other domain-specific
  options. Hooks may accept either a map or keyword list for convenience.
  """
  @type kv_opts :: map() | keyword()

  # Startup/shutdown callbacks
  @callback after_startup() :: :ok | [rpc_export()]
  @callback before_stop() :: any()

  @doc """
  Handle a dynamically-exported RPC function.

  This callback is invoked when a client calls a function name that was
  registered at runtime from `after_startup/0`.

  Receives the function name and the argument list.
  """
  @callback on_custom_hook(String.t(), list()) :: any()

  # User lifecycle callbacks
  @callback after_user_register(user()) :: any()
  @callback after_user_login(user()) :: any()

  # Lobby lifecycle callbacks
  @callback before_lobby_create(attrs :: map()) :: hook_result(map())
  @callback after_lobby_create(lobby()) :: any()

  @callback before_lobby_join(user(), lobby(), opts :: keyword()) ::
              hook_result({user(), lobby(), keyword()})
  @callback after_lobby_join(user(), lobby()) :: any()

  @callback before_lobby_leave(user(), lobby()) :: hook_result({user(), lobby()})
  @callback after_lobby_leave(user(), lobby()) :: any()

  @callback before_lobby_update(lobby(), attrs :: map()) :: hook_result(map())
  @callback after_lobby_update(lobby()) :: any()

  @callback before_lobby_delete(lobby()) :: hook_result(lobby())
  @callback after_lobby_delete(lobby()) :: any()

  @callback before_user_kicked(host :: user(), target :: user(), lobby()) ::
              hook_result({user(), user(), lobby()})
  @callback after_user_kicked(host :: user(), target :: user(), lobby()) :: any()

  @doc """
  Called before a KV `get/2` is performed. Implementations should return
  `:public` if the key may be read publicly, or `:private` to restrict access.

  Receives the `key` and an `opts` map/keyword (see `t:kv_opts/0`). Return
  either the bare atom (e.g. `:public`) or `{:ok, :public}`; return `{:error, reason}`
  to block the read.
  """
  @callback before_kv_get(String.t(), kv_opts()) :: hook_result(:public | :private)

  @callback after_lobby_host_change(lobby(), new_host_id :: integer()) :: any()

  @doc """
  Use this macro to get default implementations for all callbacks.

  This allows you to only implement the callbacks you need.

  ## Example

      defmodule MyGame.Hooks do
        use GameServer.Hooks

        @impl true
        def after_user_register(user) do
          # Only implement what you need
          :ok
        end
      end
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour GameServer.Hooks

      @impl true
      def after_startup, do: :ok

      @impl true
      def before_stop, do: :ok

      @impl true
      def on_custom_hook(_hook, _args), do: {:error, :not_implemented}

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
      def before_kv_get(_key, _opts), do: :public

      defoverridable after_user_register: 1,
                     after_user_login: 1,
                     on_custom_hook: 2,
                     before_lobby_create: 1,
                     after_lobby_create: 1,
                     before_lobby_join: 3,
                     after_lobby_join: 2,
                     before_lobby_leave: 2,
                     after_lobby_leave: 2,
                     before_lobby_update: 2,
                     after_lobby_update: 1,
                     before_lobby_delete: 1,
                     after_lobby_delete: 1,
                     before_user_kicked: 3,
                     after_user_kicked: 3,
                     after_lobby_host_change: 2,
                     before_kv_get: 2
    end
  end

  @doc """
  Returns the raw caller value for the current hook invocation.

  When GameServer executes a hook function, it may inject a `:caller` into the
  hook task's process dictionary. This helper fetches that raw value.
  """
  @spec caller() :: any() | nil
  def caller do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        %GameServer.Accounts.User{
          id: 0,
          email: "",
          display_name: nil,
          metadata: %{},
          is_admin: false,
          inserted_at: ~U[1970-01-01 00:00:00Z],
          updated_at: ~U[1970-01-01 00:00:00Z]
        }

      _ ->
        raise "#{__MODULE__}.caller/0 is a stub - only available at runtime on GameServer"
    end
  end

  @doc """
  Returns the caller's numeric id when available.

  If the caller is a `GameServer.Accounts.User` struct, returns its `id`.
  If the caller is a map, returns `:id` or `"id"`.
  If the caller is already an integer, returns it.
  Otherwise returns `nil`.
  """
  @spec caller_id() :: integer() | nil
  def caller_id do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder -> 0
      _ -> raise "#{__MODULE__}.caller_id/0 is a stub - only available at runtime on GameServer"
    end
  end

  @doc """
  Returns the user struct for the current caller when available.

  This is a convenience wrapper over `caller/0` that returns a user struct when
  the caller is already a `%GameServer.Accounts.User{}`.

  In the full GameServer application this may also resolve ids/maps via the DB.
  In the SDK it only returns the struct when it is already present.
  """
  @spec caller_user() :: GameServer.Accounts.User.t() | nil
  def caller_user do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        %GameServer.Accounts.User{
          id: 0,
          email: "",
          display_name: nil,
          metadata: %{},
          is_admin: false,
          inserted_at: ~U[1970-01-01 00:00:00Z],
          updated_at: ~U[1970-01-01 00:00:00Z]
        }

      _ ->
        raise "#{__MODULE__}.caller_user/0 is a stub - only available at runtime on GameServer"
    end
  end
end
