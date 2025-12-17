defmodule GameServerWeb.Api.V1.MetadataController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  tags(["Users"])

  operation(:show,
    operation_id: "get_user_metadata",
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
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  def show(conn, _params) do
    # Guardian pipeline has already authenticated and loaded the user
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        json(conn, %{data: user.metadata || %{}})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})
    end
  end
end
