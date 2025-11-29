defmodule GameServerWeb.Api.V1.HookController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  operation(:index,
    operation_id: "list_hooks",
    summary: "List available hook functions",
    tags: ["Hooks"],
    security: [%{"authorization" => []}],
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def index(conn, _params) do
    functions = GameServer.Hooks.exported_functions()
    json(conn, %{data: functions})
  end

  operation(:invoke,
    operation_id: "call_hook",
    summary: "Invoke a hook function",
    tags: ["Hooks"],
    security: [%{"authorization" => []}],
    request_body:
      {"Call hook", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           fn: %OpenApiSpex.Schema{type: :string},
           args: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :any}}
         },
         required: [:fn]
       }},
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      unauthorized: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def invoke(conn, %{"fn" => fn_name} = params) do
    user = conn.assigns.current_scope.user
    args = Map.get(params, "args", [])

    # If the first argument for many hooks is a user, prepend it if not already provided
    # Consumers can decide how they supply args.
    args = if Enum.empty?(args), do: [user], else: args

    case GameServer.Hooks.call(fn_name, args, caller: user) do
      {:ok, res} ->
        json(conn, %{ok: true, result: res})

      {:error, :not_implemented} ->
        conn |> put_status(:bad_request) |> json(%{error: :not_implemented})

      {:error, :not_allowed} ->
        conn |> put_status(:bad_request) |> json(%{error: :not_allowed})

      {:error, :timeout} ->
        conn |> put_status(:bad_request) |> json(%{error: :timeout})

      {:error, other} ->
        conn |> put_status(:bad_request) |> json(%{error: inspect(other)})
    end
  end
end
