defmodule GameServerWeb.Schemas.HealthResponse do
  @moduledoc """
  Health check response schema
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "HealthResponse",
    description: "Response from health check endpoint",
    type: :object,
    properties: %{
      status: %Schema{type: :string, description: "Health status", example: "ok"},
      timestamp: %Schema{
        type: :string,
        description: "Current timestamp",
        example: "2025-11-22T16:00:00Z"
      }
    },
    required: [:status, :timestamp]
  })
end
