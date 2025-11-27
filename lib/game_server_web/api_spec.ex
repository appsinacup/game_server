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
        version: api_version(),
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

        ## Users
        Users endpoints cover the user lifecycle and profile features. Key highlights:

        - **Registration and login** (email/password, device token for SDKs, and OAuth providers)
        - **Profile metadata** (JSON blob per user) and editable profile fields
        - **Account lifecycle**: password reset, email confirmation, and account deletion
        - **Sessions & tokens**: both browser sessions and JWT-based API tokens are supported

        ## Friends
        The Friends domain offers lightweight social features:

        - **Friend requests** (send / accept / reject / block flows)
        - **Friend listing & pagination**, with basic privacy controls
        - **Domain helpers** to manage and query friend relationships from API or UI contexts

        ## Lobbies
        Lobbies provide matchmaking / room management primitives. Highlights:

        - **Create / list / update / delete** lobbies with rich metadata (mode, region, tags)
        - **Host-managed or hostless** modes (hostless allowed internally, not creatable via public API)
        - **Membership management**: join, leave, kick users, and automatic host transfer
        - **Controls & protection**: max users, hidden/locked states, and optional password protection
        - **Hidden lobbies** are excluded from public listings; public listing endpoints are paginated
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

  defp api_version do
    # Prefer an environment-supplied APP_VERSION when present (CI injects this),
    # then fall back to the application vsn or Mix project version.
    case System.get_env("APP_VERSION") || Application.spec(:game_server, :vsn) do
      nil -> Mix.Project.config()[:version] || "1.0.0"
      vsn -> to_string(vsn)
    end
  end

  # Filter out non-API routes (browser routes) from the OpenAPI spec
  defp filter_api_paths(paths) do
    Map.filter(paths, fn {path, _path_item} ->
      # Only include paths that start with /api/
      String.starts_with?(path, "/api/")
    end)
  end
end
