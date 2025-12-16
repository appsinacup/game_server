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

  defp error_message(:invalid_token), do: "Invalid authentication token"
  defp error_message(:token_expired), do: "Authentication token expired"
  defp error_message(:unauthenticated), do: "Authentication required"
  defp error_message(_), do: "Authentication failed"
end
