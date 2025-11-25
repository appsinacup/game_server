defmodule GameServerWeb.Api.V1.LobbyController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Lobbies
  alias OpenApiSpex.Schema

  tags(["Lobbies"])

  operation(:index,
    operation_id: "list_lobbies",
    summary: "List lobbies",
    description:
      "Return all non-hidden lobbies, supports optional text search via 'q' and metadata filters.",
    parameters: [
      q: [
        in: :query,
        schema: %Schema{type: :string},
        description: "Search term for name or title"
      ],
      metadata_key: [
        in: :query,
        schema: %Schema{type: :string},
        description: "optional metadata key to filter"
      ],
      metadata_value: [
        in: :query,
        schema: %Schema{type: :string},
        description: "optional metadata value to filter"
      ]
    ],
    responses: [ok: {"List of lobbies", "application/json", %Schema{type: :object}}]
  )

  operation(:create,
    operation_id: "create_lobby",
    summary: "Create a lobby",
    description: "Create a lobby. Authenticated user becomes the host.",
    security: [%{"authorization" => []}],
    request_body: {"Lobby params", "application/json", %Schema{type: :object}},
    responses: [created: {"Lobby created", "application/json", %Schema{type: :object}}]
  )

  operation(:join,
    operation_id: "join_lobby",
    summary: "Join a lobby",
    description: "Authenticated user joins a lobby; send password when required.",
    security: [%{"authorization" => []}],
    parameters: [
      authorization: [
        in: :header,
        name: "Authorization",
        schema: %Schema{type: :string},
        required: true
      ]
    ],
    request_body: {"Join params", "application/json", %Schema{type: :object}},
    responses: [ok: {"Joined", "application/json", %Schema{type: :object}}]
  )

  operation(:leave,
    operation_id: "leave_lobby",
    summary: "Leave the lobby",
    description: "Authenticated user leaves their current lobby.",
    security: [%{"authorization" => []}],
    parameters: [
      authorization: [
        in: :header,
        name: "Authorization",
        schema: %Schema{type: :string},
        required: true
      ]
    ],
    responses: [ok: {"Left", "application/json", %Schema{type: :object}}]
  )

  operation(:update,
    operation_id: "update_lobby",
    summary: "Update lobby (host only)",
    security: [%{"authorization" => []}],
    request_body: {"Update params", "application/json", %Schema{type: :object}},
    responses: [ok: {"Updated", "application/json", %Schema{type: :object}}]
  )

  operation(:kick,
    operation_id: "kick_user",
    summary: "Kick a user from the lobby (host only)",
    security: [%{"authorization" => []}],
    request_body: {"Kick params", "application/json", %Schema{type: :object}},
    responses: [ok: {"Kicked", "application/json", %Schema{type: :object}}]
  )

  def index(conn, params) do
    filters = Map.take(params || %{}, ["q", "metadata_key", "metadata_value"]) |> Enum.into(%{})
    lobbies = Lobbies.list_lobbies(filters)

    json(conn, %{data: Enum.map(lobbies, &serialize_lobby/1)})
  end

  def create(conn, params) do
    # authenticated user becomes host by default if not hostless
    case conn.assigns.current_scope do
      %{user: %{id: id}} when not is_nil(id) ->
        params = Map.put(params, "host_id", id)

        case Lobbies.create_lobby(params) do
          {:ok, lobby} ->
            conn |> put_status(:created) |> json(%{data: serialize_lobby(lobby)})

          {:error, :already_in_lobby} ->
            conn |> put_status(:conflict) |> json(%{error: "User already in a lobby"})

          {:error, cs} ->
            conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(cs)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def join(conn, %{"id" => id} = params) do
    case conn.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        opts = if Map.has_key?(params, "password"), do: %{password: params["password"]}, else: %{}

        case Lobbies.join_lobby(user, id, opts) do
          {:ok, _membership} -> json(conn, %{data: "joined"})
          {:error, reason} -> conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def leave(conn, _params) do
    case conn.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        case Lobbies.leave_lobby(user) do
          {:ok, _} ->
            json(conn, %{data: "left"})

          {:error, reason} ->
            conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case conn.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        lobby = Lobbies.get_lobby!(id)

        case Lobbies.update_lobby_by_host(user, lobby, params) do
          {:ok, lobby} -> json(conn, %{data: serialize_lobby(lobby)})
          {:error, reason} -> conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def kick(conn, %{"id" => id, "target_user_id" => target_user_id}) do
    case conn.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        lobby = Lobbies.get_lobby!(id)
        target_id = String.to_integer(to_string(target_user_id))

        target_user = GameServer.Accounts.get_user!(target_id)

        case Lobbies.kick_user(user, lobby, target_user) do
          {:ok, _} -> json(conn, %{data: "kicked"})
          {:error, reason} -> conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  defp serialize_lobby(lobby) do
    %{
      id: lobby.id,
      name: lobby.name,
      title: lobby.title,
      host_id: lobby.host_id,
      hostless: lobby.hostless,
      max_users: lobby.max_users,
      # is_private removed; use hidden + locked flags
      is_hidden: lobby.is_hidden,
      is_locked: lobby.is_locked,
      metadata: lobby.metadata || %{}
    }
  end

  defp errors_on(changeset) when is_map(changeset) do
    # Basic errors extraction for API responses
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  defp errors_on(_), do: %{}
end
