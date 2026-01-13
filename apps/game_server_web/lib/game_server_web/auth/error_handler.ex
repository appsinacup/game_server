defmodule GameServerWeb.Auth.ErrorHandler do
  @moduledoc """
  Handles authentication errors for the Guardian pipeline.
  """

  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    body = Jason.encode!(%{error: error_message(type)})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, body)
  end

  defp error_message(:invalid_token),
    do: Gettext.gettext(GameServerWeb.Gettext, "Invalid authentication token")

  defp error_message(:token_expired),
    do: Gettext.gettext(GameServerWeb.Gettext, "Authentication token expired")

  defp error_message(:unauthenticated),
    do: Gettext.gettext(GameServerWeb.Gettext, "Authentication required")

  defp error_message(_), do: Gettext.gettext(GameServerWeb.Gettext, "Authentication failed")
end
