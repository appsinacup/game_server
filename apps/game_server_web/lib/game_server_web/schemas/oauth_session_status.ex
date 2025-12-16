defmodule GameServerWeb.Schemas.OAuthSessionStatus do
  @moduledoc """
  Schema describing the response for OAuth session status checks
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "OAuthSessionStatus",
    description: "Status payload returned when querying an OAuth session",
    type: :object,
    properties: %{
      status: %Schema{
        type: :string,
        description: "Current session status",
        enum: ["pending", "completed", "error", "conflict"]
      },
      data: GameServerWeb.Schemas.OAuthSessionData,
      message: %Schema{
        type: :string,
        description: "Optional human-readable message describing the current status"
      }
    },
    required: [:status]
  })
end
