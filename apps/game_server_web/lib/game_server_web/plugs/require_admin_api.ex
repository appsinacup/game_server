defmodule GameServerWeb.Plugs.RequireAdminApi do
  @moduledoc """
  Ensures the current API request is performed by an admin user.

  Unlike browser flows, this plug returns JSON errors (no redirects).
  """

  import Plug.Conn

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case conn.assigns[:current_scope] do
      %{user: %{is_admin: true}} ->
        conn

      %{user: _user} ->
        forbidden(conn)

      _ ->
        # In practice, unauthenticated requests should be handled by the Guardian
        # error handler, but keep this safe and explicit.
        unauthorized(conn)
    end
  end

  defp forbidden(conn) do
    body = Jason.encode!(%{error: "forbidden"})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, body)
    |> halt()
  end

  defp unauthorized(conn) do
    body = Jason.encode!(%{error: "unauthorized"})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, body)
    |> halt()
  end
end
