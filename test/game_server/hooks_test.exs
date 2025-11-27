defmodule GameServer.HooksTest do
  # This test touches global Application environment (hooks module) and
  # must not run concurrently with other tests that depend on application
  # configuration values. Run serially to avoid races where a temporary
  # test hook leaks into other tests.
  use GameServer.DataCase, async: false

  alias GameServer.Accounts
  alias GameServer.Repo
  import GameServer.AccountsFixtures

  setup do
    orig = Application.get_env(:game_server, :hooks_module)
    on_exit(fn -> Application.put_env(:game_server, :hooks_module, orig) end)
    :ok
  end

  defmodule TestHooksRegister do
    @behaviour GameServer.Hooks

    # After-register hook — mutate the user record in DB so tests can observe it
    # Use metadata to avoid interfering with email-based token logic.
    def after_user_register(user) do
      meta = Map.put(user.metadata || %{}, "registered_hook", true)
      Repo.update!(Ecto.Changeset.change(user, metadata: meta))
    end

    def after_user_login(user) do
      # mark metadata to signal the hook ran
      meta = Map.put(user.metadata || %{}, "hooked", true)
      Repo.update!(Ecto.Changeset.change(user, metadata: meta))
    end

    # Lobby hooks - no-op implementations for test
    def before_lobby_create(attrs), do: {:ok, attrs}
    def after_lobby_create(_lobby), do: :ok
    def before_lobby_join(user, lobby, opts), do: {:ok, {user, lobby, opts}}
    def after_lobby_join(_user, _lobby), do: :ok
    def before_lobby_leave(user, lobby), do: {:ok, {user, lobby}}
    def after_lobby_leave(_user, _lobby), do: :ok
    def before_lobby_update(_lobby, attrs), do: {:ok, attrs}
    def after_lobby_update(_lobby), do: :ok
    def before_lobby_delete(lobby), do: {:ok, lobby}
    def after_lobby_delete(_lobby), do: :ok
    def before_user_kicked(host, target, lobby), do: {:ok, {host, target, lobby}}
    def after_user_kicked(_host, _target, _lobby), do: :ok
    def after_lobby_host_change(_lobby, _new_host_id), do: :ok
  end

  test "after_user_register hook runs and can modify the created user" do
    Application.put_env(:game_server, :hooks_module, TestHooksRegister)

    {:ok, user} = Accounts.register_user(%{email: "a@example.com"})

    # after_user_register runs asynchronously; wait shortly for it to finish
    Process.sleep(50)

    reloaded = Accounts.get_user!(user.id)
    assert Map.get(reloaded.metadata || %{}, "registered_hook") == true
  end

  test "linking a provider removes device_id from user" do
    user = unconfirmed_user_fixture(%{"device_id" => "dev-#{System.unique_integer([:positive])}"})

    assert is_binary(user.device_id)

    {:ok, user} =
      Accounts.link_account(
        user,
        %{discord_id: "d999"},
        :discord_id,
        &GameServer.Accounts.User.discord_oauth_changeset/2
      )

    assert user.discord_id == "d999"
    assert is_nil(user.device_id)
  end

  test "after_user_login hook runs on successful magic-link login" do
    Application.put_env(:game_server, :hooks_module, TestHooksRegister)

    user = unconfirmed_user_fixture()
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)

    assert {:ok, {_, _}} = Accounts.login_user_by_magic_link(encoded_token)

    # after_user_login runs asynchronously; wait for update
    Process.sleep(50)

    reloaded = Accounts.get_user!(user.id)
    assert Map.get(reloaded.metadata || %{}, "hooked") == true
  end
end
