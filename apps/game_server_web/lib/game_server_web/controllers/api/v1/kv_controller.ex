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
      {:ok, access} ->
        if kv_access_allowed?(access, caller, user_id, lobby_id) do
          do_get(conn, key, user_id, lobby_id)
        else
          forbidden(conn)
        end

      {:error, _reason} ->
        forbidden(conn)
    end
  end

  defp kv_access_allowed?(:public, _caller, _user_id, _lobby_id), do: true

  defp kv_access_allowed?(:owner_only, caller, user_id, _lobby_id),
    do: caller_owns?(caller, user_id)

  defp kv_access_allowed?(:lobby_members_only, caller, _user_id, lobby_id),
    do: caller_in_lobby?(caller, lobby_id)

  defp kv_access_allowed?(:owner_or_lobby_member, caller, user_id, lobby_id),
    do: caller_owns?(caller, user_id) or caller_in_lobby?(caller, lobby_id)

  defp kv_access_allowed?(:admin_only, caller, _user_id, _lobby_id), do: caller_admin?(caller)
  defp kv_access_allowed?(:server_only, _caller, _user_id, _lobby_id), do: false
  defp kv_access_allowed?(_access, _caller, _user_id, _lobby_id), do: false

  defp caller_owns?(%Scope{user: %{id: caller_id}}, user_id),
    do: is_integer(user_id) and caller_id == user_id

  defp caller_owns?(_caller, _user_id), do: false

  defp caller_in_lobby?(%Scope{user: %{lobby_id: caller_lobby_id}}, lobby_id),
    do: is_integer(lobby_id) and caller_lobby_id == lobby_id

  defp caller_in_lobby?(_caller, _lobby_id), do: false

  defp caller_admin?(%Scope{user: %{is_admin: true}}), do: true
  defp caller_admin?(_caller), do: false

  defp forbidden(conn), do: conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

  defp do_get(conn, key, user_id, lobby_id) do
    case KV.get(key, user_id: user_id, lobby_id: lobby_id) do
      {:ok, %{value: value, metadata: metadata}} ->
        json(conn, %{data: value, metadata: metadata})

      :error ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  end
end
