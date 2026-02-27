defmodule GameServerWeb.ContentAssetController do
  @moduledoc """
  Serves static assets (images, etc.) from the blog or changelog directories.

  Routes:
    GET /content/blog/*path
    GET /content/changelog/*path
  """

  use GameServerWeb, :controller

  alias GameServer.Content

  def show(conn, %{"type" => type, "path" => path_parts}) do
    relative = Path.join(path_parts)

    case Content.content_asset_path(type, relative) do
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
end
