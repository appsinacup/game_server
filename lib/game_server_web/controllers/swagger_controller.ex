defmodule GameServerWeb.SwaggerController do
  use GameServerWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
