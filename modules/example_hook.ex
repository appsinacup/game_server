defmodule GameServer.Modules.ExampleHook do
  @moduledoc """
  Small example Elixir hook implementation used for development/testing.

  Placed in the top-level `modules/` directory so it is not automatically
  compiled by Mix. This allows loading it at runtime via
  GameServer.Hooks.register_file/1 in development or via an external admin
  action.
  """

  @behaviour GameServer.Hooks

  alias GameServer.Accounts
  alias GameServer.Leaderboards

  @impl true
  def after_startup do
    # Create default leaderboard (ignores error if already exists)
    IO.puts("[ExampleHook] after_startup called - creating default leaderboard")

    result =
      Leaderboards.create_leaderboard(%{
        id: "login_count",
        title: "Login Count",
        sort_order: "desc",
        operator: "incr"
      })

    IO.puts("[ExampleHook] create_leaderboard result: #{inspect(result)}")
    :ok
  end

  @impl true
  def after_user_register(user) do
    # Add a flag to user metadata on registration
    meta = Map.put(user.metadata || %{}, "registered_example", true)
    Accounts.update_user(user, %{metadata: meta})

    IO.puts("[ExampleHook] after_user_register called for user=#{user.id}")

    :ok
  end

  @impl true
  def after_user_login(user) do
    # Increment login count on leaderboard
    Leaderboards.submit_score("login_count", user.id, 1)

    :ok
  end

  @impl true
  def before_lobby_create(attrs), do: {:ok, attrs}

  @impl true
  def after_lobby_create(_lobby), do: :ok

  @impl true
  def before_lobby_join(_user, _lobby, _opts), do: {:ok, :noop}

  @impl true
  def after_lobby_join(_user, _lobby), do: :ok

  @impl true
  def before_lobby_leave(_user, _lobby), do: {:ok, :noop}

  @impl true
  def after_lobby_leave(_user, _lobby), do: :ok

  @impl true
  def before_lobby_update(_lobby, attrs), do: {:ok, attrs}

  @impl true
  def after_lobby_update(_lobby), do: :ok

  @impl true
  def before_lobby_delete(_lobby), do: {:ok, :noop}

  @impl true
  def after_lobby_delete(_lobby), do: :ok

  @impl true
  def before_user_kicked(_host, _target, _lobby), do: {:ok, :noop}

  @impl true
  def after_user_kicked(_host, _target, _lobby), do: :ok

  @impl true
  def after_lobby_host_change(_lobby, _new_host_id), do: :ok

  @doc "Say hi to a user"
  def hello(name) when is_bitstring(name) do
    "Hello, #{name}!"
  end

  @doc "Set the user metadata"
  def set_current_user_meta(key, value) do
    user = GameServer.Hooks.caller_user()
    meta = user.metadata || %{}
    meta = Map.put(meta, key, value)
    Accounts.update_user(user, %{metadata: meta})

    :ok
  end
end
