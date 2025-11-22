defmodule GameServerWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Game Server API.
  """

  alias OpenApiSpex.{Info, OpenApi, Paths, Server, Components, SecurityScheme}
  alias GameServerWeb.{Endpoint, Router}
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
        - Email/Password login at `/api/v1/auth/login`
        - Discord OAuth at `/auth/discord`

        ## Endpoints
        All API endpoints are under `/api/v1`
        """
      },
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            description: "Session-based authentication"
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
