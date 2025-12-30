defmodule GameServerWeb.Api.V1.Admin.PluginController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Hooks.PluginBuilder
  alias GameServer.Hooks.PluginManager
  alias OpenApiSpex.Schema

  tags(["Admin Plugins"])

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  operation(:reload,
    operation_id: "admin_plugins_reload",
    summary: "Reload hook plugins (admin)",
    security: [%{"authorization" => []}],
    responses: [
      ok: {"Plugins", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema}
    ]
  )

  def reload(conn, _params) do
    plugins = PluginManager.reload()

    json(conn, %{data: plugins})
  end

  operation(:buildable,
    operation_id: "admin_plugins_buildable",
    summary: "List buildable plugin sources (admin)",
    security: [%{"authorization" => []}],
    responses: [
      ok: {"Plugins", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema}
    ]
  )

  def buildable(conn, _params) do
    json(conn, %{data: PluginBuilder.list_buildable_plugins()})
  end

  operation(:build,
    operation_id: "admin_plugins_build",
    summary: "Build plugin bundle (admin)",
    security: [%{"authorization" => []}],
    request_body: {
      "Build request",
      "application/json",
      %Schema{type: :object, properties: %{name: %Schema{type: :string}}, required: [:name]}
    },
    responses: [
      ok: {"Build result", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema},
      bad_request: {"Bad request", "application/json", @error_schema}
    ]
  )

  def build(conn, %{"name" => name}) when is_binary(name) do
    case PluginBuilder.build(name) do
      {:ok, result} ->
        json(conn, %{data: result})

      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
    end
  end

  def build(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "missing_name"})
  end
end
