defmodule GameServerWeb.Api.V1.HealthController do
  @moduledoc """
  Health check endpoint for the API.
  """
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServerWeb.Schemas.HealthResponse

  tags(["Health"])

  operation(:index,
    summary: "Health check",
    description: "Returns the health status of the API",
    responses: [
      ok: {"Health status", "application/json", HealthResponse}
    ]
  )

  def index(conn, _params) do
    json(conn, %{
      status: "ok",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
end
