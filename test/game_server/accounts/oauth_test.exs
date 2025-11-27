defmodule GameServer.Accounts.OAuthTest do
  use GameServer.DataCase, async: true

  alias GameServer.Accounts
  alias GameServer.AccountsFixtures

  describe "find_or_create_from_discord/1" do
    test "prefers provider id and updates existing user" do
      user = AccountsFixtures.unconfirmed_user_fixture(%{email: "u1@example.com"})

      # set an existing discord id on the user
      user = Ecto.Changeset.change(user, discord_id: "d_existing") |> GameServer.Repo.update!()

      {:ok, returned} =
        Accounts.find_or_create_from_discord(%{
          discord_id: "d_existing",
          profile_url: "https://cdn.test/avatar.png"
        })

      assert returned.id == user.id
      assert returned.discord_id == "d_existing"
      assert returned.profile_url == "https://cdn.test/avatar.png"
    end

    test "links to existing user by email when provider id missing" do
      user = AccountsFixtures.unconfirmed_user_fixture(%{email: "link_me@example.com"})

      {:ok, returned} =
        Accounts.find_or_create_from_discord(%{
          discord_id: "d_link",
          email: "link_me@example.com"
        })

      assert returned.id == user.id
      assert returned.discord_id == "d_link"
    end

    test "creates a new user when neither provider nor email matched" do
      # provider only case should create
      {:ok, returned} =
        Accounts.find_or_create_from_discord(%{discord_id: "d_new", display_name: "newuser"})

      assert returned.discord_id == "d_new"
      assert returned.display_name == "newuser"
    end
  end
end
