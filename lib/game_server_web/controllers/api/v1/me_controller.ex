defmodule GameServerWeb.Api.V1.MeController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema

  tags(["Users"])

  operation(:show,
    operation_id: "get_current_user",
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
                profile_url: %Schema{type: :string},
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
    # Guardian pipeline has already authenticated and loaded the user
    # into current_scope via AssignCurrentScope plug
    case conn.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        json(conn, %{
          data: %{
            id: user.id,
            email: user.email,
            profile_url: user.profile_url,
            is_admin: user.is_admin,
            metadata: user.metadata || %{}
          }
        })

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})
    end
  end
end
