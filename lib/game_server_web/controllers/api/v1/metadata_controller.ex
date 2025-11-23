defmodule GameServerWeb.Api.V1.MetadataController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts
  alias OpenApiSpex.Schema

  tags(["Users"])

  operation(:show,
    summary: "Return current user's metadata",
    description: "Returns only the metadata map for the authenticated user.",
    security: [%{"authorization" => []}],
    parameters: [
      authorization: [
        in: :header,
        name: "Authorization",
        schema: %Schema{type: :string},
        description: "Bearer token",
        required: true
      ]
    ],
    responses: [
      ok: {"User metadata", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", nil}
    ]
  )

  def show(conn, _params) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.url_decode64(token, padding: false),
         {user, _} <- Accounts.get_user_by_session_token(decoded) do
      json(conn, %{data: user.metadata || %{}})
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})
    end
  end
end
