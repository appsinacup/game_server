defmodule GameServerWeb.Schemas.GamendSession do
  @moduledoc """
  Gamend session payload returned from OAuth/login flows.

  This is used by the GDScript client generator to produce a typed
  GamendSession model instead of relying on anonymous inline objects.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "GamendSession",
    description: "OAuth session with access/refresh tokens and expiry",
    type: :object,
    properties: %{
      access_token: %Schema{type: :string, description: "Short-lived access token"},
      refresh_token: %Schema{type: :string, description: "Long-lived refresh token"},
      expires_at: %Schema{type: :integer, format: :int64, description: "Epoch seconds when the access token expires"},
      user_id: %Schema{type: :string, description: "ID of the authenticated user (optional)", example: "user_1234"}
    },
    required: [:access_token, :refresh_token]
  })
end
