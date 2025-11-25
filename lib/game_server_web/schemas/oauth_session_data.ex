defmodule GameServerWeb.Schemas.OAuthSessionData do
  @moduledoc """
  Describes the payload stored in `OAuthSession.data` when a session completes or errors.

  Typical shapes stored here include authentication tokens and a small `user` object
  when authentication succeeds, or a `details` field with error info when it fails.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "OAuthSessionData",
    description: "Payload stored on completed or errored OAuth sessions",
    type: :object,
    properties: %{
      access_token: %Schema{type: :string, description: "Short-lived access token"},
      refresh_token: %Schema{type: :string, description: "Long-lived refresh token"},
      expires_in: %Schema{type: :integer, description: "Seconds until access_token expires"},
      details: %Schema{
        description: "Error details (string or object). When present the session failed",
        oneOf: [
          %Schema{type: :string},
          %Schema{type: :object}
        ]
      }
    },
    example: %{
      access_token: "eyJhb...",
      refresh_token: "eyJhb...",
      expires_in: 900
    }
  })
end
