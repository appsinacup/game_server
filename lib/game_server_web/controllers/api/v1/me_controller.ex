defmodule GameServerWeb.Api.V1.MeController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts
  alias OpenApiSpex.Schema

  tags(["Users"])

  operation(:show,
    summary: "Return current user info",
    description: "Returns the current authenticated user's basic information.",
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
      ok: {
        "User info",
        "application/json",
        %Schema{
          type: :object,
          properties: %{
            data: %Schema{
              type: :object,
              properties: %{
                id: %Schema{type: :integer},
                email: %Schema{type: :string},
                discord_username: %Schema{type: :string},
                discord_avatar: %Schema{type: :string},
                is_admin: %Schema{type: :boolean},
                metadata: %Schema{type: :object}
              }
            }
          }
        }
      },
      unauthorized: {"Not authenticated", "application/json", nil}
    ]
  )

  def show(conn, _params) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.url_decode64(token, padding: false),
         {user, _} <- Accounts.get_user_by_session_token(decoded) do
      json(conn, %{
        data: %{
          id: user.id,
          email: user.email,
          discord_username: user.discord_username,
          discord_avatar: user.discord_avatar,
          is_admin: user.is_admin,
          metadata: user.metadata || %{}
        }
      })
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})
    end
  end
end
