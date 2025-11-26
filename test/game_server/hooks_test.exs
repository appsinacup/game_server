defmodule GameServer.HooksTest do
  # This test touches global Application environment (hooks module) and
  # must not run concurrently with other tests that depend on application
  # configuration values. Run serially to avoid races where a temporary
  # test hook leaks into other tests.
  use GameServer.DataCase, async: false

  alias GameServer.Accounts
  import GameServer.AccountsFixtures

  setup do
    orig = Application.get_env(:game_server, :hooks_module)
    on_exit(fn -> Application.put_env(:game_server, :hooks_module, orig) end)
    :ok
  end

  defmodule TestHooksRegister do
    @behaviour GameServer.Hooks

    def before_user_register(%{"email" => e} = attrs) do
      {:ok, Map.put(attrs, "email", e <> ".hook")}
    end

    def after_user_register(_), do: :ok
    def before_user_login(u), do: {:ok, u}
    def after_user_login(_), do: :ok

    def before_account_link(user, _p, attrs),
      do: {:ok, {user, Map.put(attrs, :profile_url, "hooked")}}

    def after_account_link(_), do: :ok
    def before_user_delete(user), do: {:ok, user}
    def after_user_delete(_), do: :ok
  end

  test "before_user_register can mutate attrs" do
    Application.put_env(:game_server, :hooks_module, TestHooksRegister)

    {:ok, user} = Accounts.register_user(%{email: "a@example.com"})

    assert user.email == "a@example.com.hook"
  end

  test "before_account_link can modify attrs and after hook runs" do
    Application.put_env(:game_server, :hooks_module, TestHooksRegister)

    user = unconfirmed_user_fixture()

    {:ok, user} =
      Accounts.link_account(
        user,
        %{discord_id: "d123"},
        :discord_id,
        &GameServer.Accounts.User.discord_oauth_changeset/2
      )

    assert user.discord_id == "d123"
    assert user.profile_url == "hooked"
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

  test "before_user_login may block login via magic link" do
    # install hook that vetoes login
    defmodule BlockLoginHook do
      @behaviour GameServer.Hooks
      def before_user_register(attrs), do: {:ok, attrs}
      def after_user_register(_), do: :ok
      def before_user_login(_), do: {:error, :banned}
      def after_user_login(_), do: :ok
      def before_account_link(u, _p, attrs), do: {:ok, {u, attrs}}
      def after_account_link(_), do: :ok
      def before_user_delete(u), do: {:ok, u}
      def after_user_delete(_), do: :ok
    end

    Application.put_env(:game_server, :hooks_module, BlockLoginHook)

    user = unconfirmed_user_fixture()
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    GameServer.Repo.insert!(user_token)

    assert {:error, {:hook_rejected, :banned}} = Accounts.login_user_by_magic_link(encoded_token)
  end
end
