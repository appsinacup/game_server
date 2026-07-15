defmodule GameServerWeb.AdminLive.NotificationsTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.Notifications
  alias GameServer.Repo

  defp admin_fixture do
    user = AccountsFixtures.user_fixture()

    {:ok, admin} =
      user
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    admin
  end

  test "admin sends a notification with ids typed as text", %{conn: conn} do
    admin = admin_fixture()
    recipient = AccountsFixtures.user_fixture()

    {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/notifications")

    view |> element(~S(button[phx-click="toggle_create"])) |> render_click()

    view
    |> form("#admin-create-notification-form",
      notification: %{
        "sender_id" => admin.id,
        "recipient_id" => recipient.id,
        "title" => "form-notification",
        "content" => "hello from the admin form",
        "metadata" => ""
      }
    )
    |> render_submit()

    assert Notifications.count_notifications(recipient.id) == 1
  end

  test "non-UUID sender/recipient ids are rejected without creating anything", %{conn: conn} do
    admin = admin_fixture()
    recipient = AccountsFixtures.user_fixture()

    {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/notifications")

    view |> element(~S(button[phx-click="toggle_create"])) |> render_click()

    html =
      view
      |> form("#admin-create-notification-form",
        notification: %{
          "sender_id" => "42",
          "recipient_id" => recipient.id,
          "title" => "bad-sender",
          "content" => "",
          "metadata" => ""
        }
      )
      |> render_submit()

    assert html =~ "Sender ID and Recipient ID are required"
    assert Notifications.count_notifications(recipient.id) == 0
  end
end
