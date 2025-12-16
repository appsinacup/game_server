defmodule GameServerWeb.PageController do
  use GameServerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def privacy(conn, _params) do
    render(conn, :privacy)
  end

  def data_deletion(conn, _params) do
    render(conn, :data_deletion)
  end

  def terms(conn, _params) do
    render(conn, :terms)
  end
end
