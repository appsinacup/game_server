defmodule GameServerWeb.HostContentAssetController do
  @moduledoc """
  Serves static assets (images, etc.) from host-registered content sources.

  Routes:
    GET /content/blog/*path
    GET /content/changelog/*path
  """

  use GameServerHostWeb, :controller

  alias GameServer.Content

  def show(conn, %{"type" => type, "path" => path_parts})
      when is_list(path_parts) and path_parts != [] do
    relative = Path.join(path_parts)

    case Content.asset_path(type, relative) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Not found")

      abs_path ->
        content_type = MIME.from_path(abs_path)

        conn
        |> put_resp_content_type(content_type)
        |> send_file(200, abs_path)
    end
  end

  def show(conn, _params) do
    conn
    |> put_status(:not_found)
    |> text("Not found")
  end
end
