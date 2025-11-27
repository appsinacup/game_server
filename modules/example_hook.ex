defmodule GameServer.Modules.ExampleHook do
  @moduledoc """
  Small example Elixir hook implementation used for development/testing.

  Placed in the top-level `modules/` directory so it is not automatically
  compiled by Mix. This allows loading it at runtime via
  GameServer.Hooks.register_file/1 in development or via an external admin
  action.
  """

  @behaviour GameServer.Hooks

  alias GameServer.Repo

# Print at compile time so you can see when this file is compiled by
# Code.compile_file/1 or by the watcher. This runs when the module is compiled.
IO.puts("[ExampleHook] compiled at: #{inspect(DateTime.utc_now())}")

  @impl true
  def after_user_register(user) do
    # simple side-effect: add a flag to user metadata (if present). Keep safe
    # and resilient so it won't crash tests if Repo isn't available.
    try do
      meta = Map.put(user.metadata || %{}, "registered_example", true)
      Repo.update!(Ecto.Changeset.change(user, metadata: meta))
    rescue
      _ -> :ok
    end

    IO.puts("[ExampleHook] after_user_register called for user=#{user.id}")

    :ok
  end

  @impl true
  def after_user_login(user) do
    # On successful login we'll update user metadata with a last_login timestamp
    # and bump a simple login counter. Keep this resilient for dev use so it
    # won't crash if Repo isn't available.
    try do
      meta = user.metadata || %{}

      meta =
        meta
        |> Map.put("last_login_at", DateTime.utc_now() |> DateTime.to_iso8601())
        |> Map.update("login_count", 1, &(&1 + 1))

      Repo.update!(Ecto.Changeset.change(user, metadata: meta))
    rescue
      _ -> :ok
    end

    IO.puts("[ExampleHook] after_user_login called for user=#{user.id}")

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
end
