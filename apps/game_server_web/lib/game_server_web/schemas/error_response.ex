defmodule GameServerWeb.Schemas.ErrorResponse do
  @moduledoc """
  Error response schema
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ErrorResponse",
    description: "Error response",
    type: :object,
    properties: %{
      error: %Schema{type: :string, description: "Error message", example: "Not found"}
    },
    required: [:error]
  })
end
