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
        - Email/Password login at `/api/v1/login`
        - Discord OAuth at `/api/v1/auth/discord`

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
            description: "Session-based authentication"
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
