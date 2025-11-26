defmodule GameServerWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Game Server API.
  """

  alias GameServerWeb.{Endpoint, Router}
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "Game Server API",
        version: "1.0.0",
        description: """
        API for Game Server application

        ## Authentication

        This API uses JWT (JSON Web Tokens) with access and refresh tokens:

        ### Getting Tokens
        - **Email/Password**: POST to `/api/v1/login` with email and password
        - **Device (SDK)**: POST to `/api/v1/login` with a `device_id` string (creates/returns a device user)
        - **Discord OAuth**: Use `/api/v1/auth/discord` flow
        - **Google OAuth**: Use `/api/v1/auth/google` flow
        - **Facebook OAuth**: Use `/api/v1/auth/facebook` flow
        - **Apple Sign In**: Use `/auth/apple` browser flow (API flow not yet implemented)

        Both methods return:
        - `access_token` - Short-lived (15 min), use for API requests
        - `refresh_token` - Long-lived (30 days), use to get new access tokens

        ### Using Tokens
        Include the access token in the Authorization header:
        ```
        Authorization: Bearer <access_token>
        ```

        ### Refreshing Tokens
        When your access token expires, use POST `/api/v1/refresh` with your refresh token to get a new access token.

        ## Endpoints
        All API endpoints are under `/api/v1`
        """
      },
      paths: filter_api_paths(Paths.from_router(Router)),
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT",
            description:
              "JWT access token - obtain from /api/v1/login, /api/v1/auth/discord/callback, /api/v1/auth/google/callback, /api/v1/auth/facebook/callback, or /auth/apple"
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  # Filter out non-API routes (browser routes) from the OpenAPI spec
  defp filter_api_paths(paths) do
    Map.filter(paths, fn {path, _path_item} ->
      # Only include paths that start with /api/
      String.starts_with?(path, "/api/")
    end)
  end
end
