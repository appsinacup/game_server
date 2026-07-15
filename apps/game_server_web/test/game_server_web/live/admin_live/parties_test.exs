defmodule GameServerWeb.AdminLive.PartiesTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.Parties.Party
  alias GameServer.Repo

  defp admin_fixture do
    user = AccountsFixtures.user_fixture()

    {:ok, admin} =
      user
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    admin
  end

  test "admin creates a party with a leader id submitted as form text", %{conn: conn} do
    admin = admin_fixture()
    leader = AccountsFixtures.user_fixture()

    {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/parties")

    view |> element(~S(button[phx-click="show_create"])) |> render_click()

    view
    |> form("#party-create-form",
      party: %{"leader_id" => leader.id, "max_size" => "4"}
    )
    |> render_submit()

    party = Repo.get_by(Party, leader_id: leader.id)
    assert party
    assert party.max_size == 4
  end

  test "non-UUID leader ids are rejected without creating a party", %{conn: conn} do
    admin = admin_fixture()

    {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/parties")

    view |> element(~S(button[phx-click="show_create"])) |> render_click()

    html =
      view
      |> form("#party-create-form", party: %{"leader_id" => "123", "max_size" => "4"})
      |> render_submit()

    assert html =~ "Leader ID must be a valid user ID"
    assert Repo.aggregate(Party, :count) == 0
  end
end
