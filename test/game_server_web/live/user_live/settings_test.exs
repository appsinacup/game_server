defmodule GameServerWeb.UserLive.SettingsTest do
  use GameServerWeb.ConnCase, async: true

  alias GameServer.Accounts
  import Phoenix.LiveViewTest
  import GameServer.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      user = user_fixture()

      {:ok, user} =
        user
        |> GameServer.Accounts.User.admin_changeset(%{
          "metadata" => %{"display_name" => "Tester"},
          "is_admin" => true
        })
        |> GameServer.Repo.update()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "Change Email"
      assert html =~ "Save Password"
      assert html =~ "Tester"
      assert html =~ "<strong>Admin:</strong>"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_user(user_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/users/settings")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user email", %{conn: conn, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user password", %{conn: conn, user: user} do
      new_password = valid_user_password()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#password_form", %{
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/users/settings"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(user.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Save Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#password_form", %{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Save Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "linking/unlinking providers" do
    setup %{conn: conn} do
      user = user_fixture(%{email: unique_user_email()})
      %{conn: log_in_user(conn, user), user: user}
    end

    test "can unlink a provider when another provider remains", %{conn: conn, user: user} do
      _user =
        GameServer.Repo.update!(
          Ecto.Changeset.change(user, %{
            discord_id: "d1",
            google_id: "g1",
            profile_url: "https://cdn.discordapp.com/avatars/d1/a_abc.gif"
          })
        )

      {:ok, lv, html} = live(conn, ~p"/users/settings")

      assert html =~ "Unlink"

      # Click unlink on discord
      lv |> element("button[phx-value-provider=\"discord\"]") |> render_click()

      # page should show link button for discord (now unlinked)
      assert render(lv) =~ "Link"
      # google is now the last linked provider and unlink is disabled
      refute has_element?(lv, "button[phx-value-provider=\"google\"]")
      assert render(lv) =~ "btn-disabled"
    end

    test "cannot unlink last remaining social provider", %{conn: conn, user: user} do
      _user = GameServer.Repo.update!(Ecto.Changeset.change(user, %{discord_id: "d1"}))

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # Unlink is disabled for the last provider
      refute has_element?(lv, "button[phx-value-provider=\"discord\"]")
      assert render(lv) =~ "btn-disabled"
    end

    test "can delete conflicting account when other account has no password (provider-only)", %{
      conn: conn
    } do
      # other account is provider-only (no password) and already has the discord_id
      other_user = user_fixture(%{discord_id: "d_conflict"})

      {:ok, lv, html} =
        live(
          conn,
          ~p"/users/settings?conflict_provider=discord&conflict_user_id=#{other_user.id}"
        )

      assert html =~ "Conflict detected"
      assert has_element?(lv, "button[phx-value-id=\"#{other_user.id}\"]")

      # click delete
      lv |> element("button[phx-value-id=\"#{other_user.id}\"]") |> render_click()

      # other account should be removed
      refute GameServer.Repo.get(GameServer.Accounts.User, other_user.id)
      assert render(lv) =~ "Conflicting account deleted"
    end

    test "cannot delete conflicting account when other account has a password", %{conn: conn} do
      other_user = user_fixture(%{discord_id: "d_conflict"})
      # set a password for the other_user so it's a real claimed account
      other_user = set_password(other_user)

      {:ok, lv, html} =
        live(
          conn,
          ~p"/users/settings?conflict_provider=discord&conflict_user_id=#{other_user.id}"
        )

      assert html =~ "Conflict detected"

      lv |> element("button[phx-value-id=\"#{other_user.id}\"]") |> render_click()

      # other account should remain
      assert GameServer.Repo.get(GameServer.Accounts.User, other_user.id)
      assert render(lv) =~ "Cannot delete an account you do not own"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
