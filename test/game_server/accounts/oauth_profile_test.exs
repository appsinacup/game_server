defmodule GameServer.Accounts.OAuthProfileTest do
  use GameServer.DataCase, async: true

  alias GameServer.Accounts

  describe "OAuth profile_url handling" do
    test "saves google profile_url on create" do
      attrs = %{
        google_id: "g_123",
        email: "guser@example.com",
        profile_url: "https://example.com/g.png"
      }

      assert {:ok, user} = Accounts.find_or_create_from_google(attrs)
      assert user.google_id == "g_123"
      assert user.profile_url == "https://example.com/g.png"
    end

    test "saves facebook profile_url on create" do
      attrs = %{
        facebook_id: "f_123",
        email: "fuser@example.com",
        profile_url: "https://example.com/f.png"
      }

      assert {:ok, user} = Accounts.find_or_create_from_facebook(attrs)
      assert user.facebook_id == "f_123"
      assert user.profile_url == "https://example.com/f.png"
    end

    test "saves display_name from google and facebook on create" do
      gattrs = %{
        google_id: "g_name",
        email: "gname@example.com",
        profile_url: "https://example.com/g.png",
        display_name: "Google Guy"
      }

      fattrs = %{
        facebook_id: "f_name",
        email: "fname@example.com",
        profile_url: "https://example.com/f.png",
        display_name: "FB Person"
      }

      assert {:ok, gu} = Accounts.find_or_create_from_google(gattrs)
      assert gu.display_name == "Google Guy"

      assert {:ok, fu} = Accounts.find_or_create_from_facebook(fattrs)
      assert fu.display_name == "FB Person"
    end

    test "does not overwrite existing profile_url when updating via provider" do
      # create initial user with profile_url already set
      {:ok, user} = GameServer.Accounts.register_user(%{email: "exist@example.com"})

      user =
        Ecto.Changeset.change(user, profile_url: "https://existing.example/old.png")
        |> GameServer.Repo.update!()

      # Attempt to link google with new profile_url; existing profile_url should remain
      attrs = %{google_id: "g_999", email: user.email, profile_url: "https://example.com/new.png"}

      assert {:ok, updated} = Accounts.find_or_create_from_google(attrs)
      assert updated.id == user.id
      assert updated.profile_url == "https://existing.example/old.png"
      # ensure display_name is not overwritten when linking if already set
      # create a user with a manually set display_name and attempt to link a provider
      {:ok, user2} = GameServer.Accounts.register_user(%{email: "display@example.com"})

      user2 =
        Ecto.Changeset.change(user2, display_name: "Local Name") |> GameServer.Repo.update!()

      attrs = %{google_id: "g_link", email: user2.email, display_name: "Provider Name"}
      assert {:ok, updated2} = Accounts.find_or_create_from_google(attrs)
      assert updated2.display_name == "Local Name"
    end
  end
end
