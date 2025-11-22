defmodule GameServerWeb.PageController do
  use GameServerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
