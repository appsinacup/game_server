defmodule GameServer.Accounts.UsernameTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.Accounts.UsernameGenerator
  alias GameServer.AccountsFixtures

  setup do
    orig = Application.get_env(:game_server_core, :hooks_module)
    on_exit(fn -> Application.put_env(:game_server_core, :hooks_module, orig) end)
    :ok
  end

  defmodule OverrideUsernameHooks do
    use GameServerWeb.TestSupport.NoopHooks

    @impl true
    def before_user_register(_user, attrs),
      do: {:ok, Map.put(attrs, "username", "Custom.Handle#{System.unique_integer([:positive])}")}
  end

  defmodule InvalidUsernameHooks do
    use GameServerWeb.TestSupport.NoopHooks

    @impl true
    def before_user_register(_user, attrs),
      do: {:ok, Map.put(attrs, "username", "!! not valid !!")}
  end

  defmodule VetoRegisterHooks do
    use GameServerWeb.TestSupport.NoopHooks

    @impl true
    def before_user_register(_user, _attrs), do: {:error, :registration_vetoed}
  end

  defp unique_device_id, do: "device-#{System.unique_integer([:positive])}"

  describe "generated usernames" do
    test "email registration gets a word-suffix username" do
      user = AccountsFixtures.unconfirmed_user_fixture()
      assert user.username =~ ~r/^[a-z]+-\d{4}$/
    end

    test "device registration gets a word-suffix username" do
      {:ok, user} = Accounts.find_or_create_from_device(unique_device_id())
      assert user.username =~ ~r/^[a-z]+-\d{4}$/
    end

    test "display name is slugified into the username" do
      {:ok, user} =
        Accounts.find_or_create_from_device(unique_device_id(), %{display_name: "Drágoș Test"})

      assert user.username =~ ~r/^dragos-test-\d{4}$/
    end

    test "explicit username in attrs is honored" do
      handle = "picked-#{System.unique_integer([:positive])}"

      {:ok, user} =
        Accounts.register_user(%{
          "email" => AccountsFixtures.unique_user_email(),
          "username" => handle
        })

      assert user.username == handle
    end
  end

  describe "before_user_register hook" do
    test "hook can override the username (lowercased on save)" do
      Application.put_env(:game_server_core, :hooks_module, OverrideUsernameHooks)

      user = AccountsFixtures.unconfirmed_user_fixture()
      assert user.username =~ ~r/^custom\.handle\d+$/
    end

    test "invalid hook username falls back to a generated one" do
      Application.put_env(:game_server_core, :hooks_module, InvalidUsernameHooks)

      user = AccountsFixtures.unconfirmed_user_fixture()
      assert user.username =~ ~r/^[a-z]+-\d+$/
    end

    test "hook can veto registration" do
      Application.put_env(:game_server_core, :hooks_module, VetoRegisterHooks)

      assert {:error, :registration_vetoed} =
               Accounts.register_user(%{"email" => AccountsFixtures.unique_user_email()})
    end
  end

  describe "update_username/2" do
    test "updates and lowercases a valid username" do
      user = AccountsFixtures.user_fixture()
      handle = "New.Handle#{System.unique_integer([:positive])}"

      assert {:ok, %User{} = updated} = Accounts.update_username(user, %{"username" => handle})
      assert updated.username == String.downcase(handle)
    end

    test "rejects a taken username" do
      taken = AccountsFixtures.user_fixture()
      user = AccountsFixtures.user_fixture()

      assert {:error, changeset} =
               Accounts.update_username(user, %{"username" => taken.username})

      assert {"has already been taken", _} = changeset.errors[:username]
    end

    test "rejects malformed usernames" do
      user = AccountsFixtures.user_fixture()

      for bad <- ["ab", "-leading", "trailing-", "two..dots", "spaced name", "nicö"] do
        result = Accounts.update_username(user, %{"username" => bad})
        assert {:error, changeset} = result
        assert Keyword.has_key?(changeset.errors, :username), "expected #{inspect(bad)} rejected"
      end
    end
  end

  test "get_user_by_username/1 is case-insensitive" do
    user = AccountsFixtures.user_fixture()

    found = Accounts.get_user_by_username(String.upcase(user.username))
    assert found && found.id == user.id
    refute Accounts.get_user_by_username("no-such-user-0000")
  end

  describe "UsernameGenerator.slug/1" do
    test "transliterates and normalizes" do
      assert UsernameGenerator.slug("Drágoș  Țest") == "dragos-test"
      assert UsernameGenerator.slug("A_B..C") == "a_b-c"
    end

    test "returns nil when too little survives" do
      assert UsernameGenerator.slug(nil) == nil
      assert UsernameGenerator.slug("阿明") == nil
      assert UsernameGenerator.slug("--") == nil
    end
  end
end
