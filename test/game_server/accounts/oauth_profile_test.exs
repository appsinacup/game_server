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
    end
  end
end
