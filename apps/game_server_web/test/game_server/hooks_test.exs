defmodule GameServer.HooksTest do
  # This test touches global Application environment (hooks module) and
  # must not run concurrently with other tests that depend on application
  # configuration values. Run serially to avoid races where a temporary
  # test hook leaks into other tests.
  use GameServer.DataCase, async: false

  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.Accounts.UserToken
  alias GameServer.Repo
  import GameServer.AccountsFixtures

  setup do
    orig = Application.get_env(:game_server_core, :hooks_module)
    on_exit(fn -> Application.put_env(:game_server_core, :hooks_module, orig) end)
    :ok
  end

  defmodule TestHooksRegister do
    @behaviour GameServer.Hooks

    @impl true
    def after_startup, do: :ok

    @impl true
    def before_stop, do: :ok

    # After-register hook - mutate the user record in DB so tests can observe it
    # Use metadata to avoid interfering with email-based token logic.
    @impl true
    def after_user_register(user) do
      meta = Map.put(user.metadata || %{}, "registered_hook", true)
      Repo.update!(Ecto.Changeset.change(user, metadata: meta))
    end

    @impl true
    def after_user_login(user) do
      # mark metadata to signal the hook ran
      meta = Map.put(user.metadata || %{}, "hooked", true)
      Repo.update!(Ecto.Changeset.change(user, metadata: meta))
    end

    # Lobby hooks - no-op implementations for test
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
  end

  test "after_user_register hook runs and can modify the created user" do
    Application.put_env(:game_server_core, :hooks_module, TestHooksRegister)

    {:ok, user} = Accounts.register_user(%{email: "a@example.com"})

    # after_user_register runs asynchronously; wait shortly for it to finish
    Process.sleep(50)

    reloaded = Accounts.get_user!(user.id)
    assert Map.get(reloaded.metadata || %{}, "registered_hook") == true
  end

  test "linking a provider does NOT automatically remove device_id from user" do
    device_id = "dev-#{System.unique_integer([:positive])}"
    user = unconfirmed_user_fixture(%{"device_id" => device_id})

    assert is_binary(user.device_id)

    {:ok, user} =
      Accounts.link_account(
        user,
        %{discord_id: "d999"},
        :discord_id,
        &User.discord_oauth_changeset/2
      )

    assert user.discord_id == "d999"
    # Device ID should remain - it's NOT automatically cleared anymore
    assert user.device_id == device_id
  end

  test "after_user_login hook runs on successful magic-link login" do
    Application.put_env(:game_server_core, :hooks_module, TestHooksRegister)

    user = unconfirmed_user_fixture()
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)

    assert {:ok, {_, _}} = Accounts.login_user_by_magic_link(encoded_token)

    # after_user_login runs asynchronously; wait for update
    Process.sleep(50)

    reloaded = Accounts.get_user!(user.id)
    assert Map.get(reloaded.metadata || %{}, "hooked") == true
  end

  describe "scheduled callbacks protection" do
    defmodule ScheduleTestHook do
      @behaviour GameServer.Hooks
      alias GameServer.Schedule

      @impl true
      def after_startup do
        # Register a scheduled callback
        Schedule.every_minutes(60, :my_scheduled_job)
        :ok
      end

      @impl true
      def before_stop, do: :ok

      # This is a public scheduled callback - protected from RPC
      def my_scheduled_job(_context), do: :ok

      # Required callbacks
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
    end

    alias GameServer.Hooks
    alias GameServer.Schedule

    test "scheduled callbacks are blocked from RPC call/3" do
      Application.put_env(:game_server_core, :hooks_module, ScheduleTestHook)

      # Trigger after_startup to register the scheduled job
      Hooks.internal_call(:after_startup, [])

      # The scheduled callback should be registered
      assert MapSet.member?(Schedule.registered_callbacks(), :my_scheduled_job)

      # Trying to call it via the public RPC API should fail
      assert {:error, :disallowed} = Hooks.call(:my_scheduled_job, [%{}])

      # Clean up
      Schedule.cancel(:my_scheduled_job)
    end

    test "cancelling a job removes it from protected list" do
      Application.put_env(:game_server_core, :hooks_module, ScheduleTestHook)

      # Register job
      Schedule.every_minutes(30, :temp_job)
      assert MapSet.member?(Schedule.registered_callbacks(), :temp_job)

      # Cancel it
      Schedule.cancel(:temp_job)
      refute MapSet.member?(Schedule.registered_callbacks(), :temp_job)
    end
  end
end
