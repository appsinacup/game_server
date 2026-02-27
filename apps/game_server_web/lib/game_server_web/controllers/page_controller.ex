defmodule GameServerWeb.PageController do
  use GameServerWeb, :controller

  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.Repo

  def home(conn, _params) do
    stats = %{
      users_count: Repo.aggregate(User, :count),
      users_active_1d: Accounts.count_users_active_since(1),
      users_active_7d: Accounts.count_users_active_since(7),
      users_active_30d: Accounts.count_users_active_since(30)
    }

    conn
    |> assign(:page_title, gettext("Home"))
    |> render(:home, stats: stats)
  end

  def privacy(conn, _params) do
    conn
    |> assign(:page_title, gettext("Privacy Policy"))
    |> render(:privacy)
  end

  def data_deletion(conn, _params) do
    conn
    |> assign(:page_title, gettext("Data Deletion"))
    |> render(:data_deletion)
  end

  def terms(conn, _params) do
    conn
    |> assign(:page_title, gettext("Terms of Service"))
    |> render(:terms)
  end
end
