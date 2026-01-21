defmodule GameServerWeb.Api.V1.KvController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts.Scope
  alias GameServer.Hooks
  alias GameServer.KV
  alias OpenApiSpex.Schema

  @kv_schema %Schema{
    type: :object,
    properties: %{data: %Schema{type: :object}, metadata: %Schema{type: :object}}
  }
  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  tags(["KV"])

  operation(:show,
    operation_id: "get_kv",
    summary: "Get a key/value entry",
    security: [%{"authorization" => []}],
    parameters: [
      key: [in: :path, schema: %Schema{type: :string}, description: "Key", required: true],
      user_id: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Optional owner user id",
        required: false
      ],
      lobby_id: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Optional owner lobby id",
        required: false
      ]
    ],
    responses: [
      ok: {"KV entry", "application/json", @kv_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      not_found: {"Not found", "application/json", @error_schema},
      forbidden: {"Forbidden", "application/json", @error_schema}
    ]
  )

  def show(conn, %{"key" => key} = params) do
    user_id =
      case params["user_id"] do
        nil ->
          nil

        s when is_binary(s) ->
          case Integer.parse(s) do
            {i, _} -> i
            _ -> nil
          end

        i when is_integer(i) ->
          i

        _ ->
          nil
      end

    lobby_id =
      case params["lobby_id"] do
        nil ->
          nil

        s when is_binary(s) ->
          case Integer.parse(s) do
            {i, _} -> i
            _ -> nil
          end

        i when is_integer(i) ->
          i

        _ ->
          nil
      end

    # Use caller scope assigned by plugs (route is authenticated via :api_auth)
    caller = Map.get(conn.assigns, :current_scope)

    case Hooks.internal_call(:before_kv_get, [key, %{user_id: user_id, lobby_id: lobby_id}],
           caller: caller
         ) do
      {:ok, :public} ->
        do_get(conn, key, user_id, lobby_id)

      {:ok, :private} ->
        # Use the resolved caller (from assigns or token) to decide permissions.
        cond do
          match?(%Scope{user: %{id: ^user_id}}, caller) ->
            do_get(conn, key, user_id, lobby_id)

          is_integer(lobby_id) and match?(%Scope{user: %{lobby_id: ^lobby_id}}, caller) ->
            do_get(conn, key, user_id, lobby_id)

          match?(%Scope{user: %{is_admin: true}}, caller) ->
            do_get(conn, key, user_id, lobby_id)

          true ->
            conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
        end

      {:error, _reason} ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

      _ ->
        do_get(conn, key, user_id, lobby_id)
    end
  end

  defp do_get(conn, key, user_id, lobby_id) do
    case KV.get(key, user_id: user_id, lobby_id: lobby_id) do
      {:ok, %{value: value, metadata: metadata}} ->
        json(conn, %{data: value, metadata: metadata})

      :error ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  end
end
