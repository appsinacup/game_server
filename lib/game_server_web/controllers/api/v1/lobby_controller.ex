defmodule GameServerWeb.Api.V1.LobbyController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Lobbies
  alias OpenApiSpex.Schema

  tags(["Lobbies"])

  # Shared schema for lobby response
  @lobby_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Lobby ID"},
      name: %Schema{type: :string, description: "Unique slug identifier"},
      title: %Schema{type: :string, description: "Display title"},
      host_id: %Schema{type: :integer, description: "User ID of the host", nullable: true},
      hostless: %Schema{type: :boolean, description: "Whether this is a server-managed lobby"},
      max_users: %Schema{type: :integer, description: "Maximum number of users allowed"},
      is_hidden: %Schema{type: :boolean, description: "Hidden from public listings"},
      is_locked: %Schema{type: :boolean, description: "Locked - no new joins allowed"},
      metadata: %Schema{type: :object, description: "Arbitrary metadata"}
    },
    example: %{
      id: 1,
      name: "my-lobby-abc123",
      title: "My Game Lobby",
      host_id: 42,
      hostless: false,
      max_users: 8,
      is_hidden: false,
      is_locked: false,
      metadata: %{}
    }
  }

  operation(:index,
    operation_id: "list_lobbies",
    summary: "List lobbies",
    description:
      "Return all non-hidden lobbies. Supports optional text search via 'q' and metadata filters.",
    parameters: [
      q: [
        in: :query,
        schema: %Schema{type: :string},
        description: "Search term for name or title"
      ],
      metadata_key: [
        in: :query,
        schema: %Schema{type: :string},
        description: "Optional metadata key to filter by"
      ],
      metadata_value: [
        in: :query,
        schema: %Schema{type: :string},
        description: "Optional metadata value to match (used with metadata_key)"
      ]
    ],
    responses: [
      ok: {"List of lobbies", "application/json", %Schema{type: :array, items: @lobby_schema}}
    ]
  )

  operation(:create,
    operation_id: "create_lobby",
    summary: "Create a lobby",
    description:
      "Create a new lobby. The authenticated user becomes the host and is automatically joined.",
    security: [%{"authorization" => []}],
    request_body: {
      "Lobby creation parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          title: %Schema{type: :string, description: "Display title for the lobby"},
          max_users: %Schema{
            type: :integer,
            description: "Maximum users allowed (default: 8)",
            default: 8
          },
          is_hidden: %Schema{
            type: :boolean,
            description: "Hide from public listings",
            default: false
          },
          is_locked: %Schema{type: :boolean, description: "Lock the lobby", default: false},
          password: %Schema{
            type: :string,
            description: "Optional password to protect the lobby"
          },
          metadata: %Schema{type: :object, description: "Arbitrary metadata"}
        },
        example: %{
          title: "My Game Lobby",
          max_users: 4,
          is_hidden: false
        }
      }
    },
    responses: [
      created: {"Lobby created", "application/json", @lobby_schema},
      conflict:
        {"User already in a lobby", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:update,
    operation_id: "update_lobby",
    summary: "Update lobby (host only)",
    description: "Update lobby settings. Only the host can update the lobby.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Lobby ID", required: true]
    ],
    request_body: {
      "Lobby update parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          title: %Schema{type: :string, description: "New display title"},
          max_users: %Schema{type: :integer, description: "New maximum users"},
          is_hidden: %Schema{type: :boolean, description: "Hide from public listings"},
          is_locked: %Schema{type: :boolean, description: "Lock the lobby"},
          password: %Schema{type: :string, description: "New password (empty string to clear)"},
          metadata: %Schema{type: :object, description: "New metadata"}
        },
        example: %{
          title: "Updated Lobby Name",
          max_users: 6,
          is_locked: true
        }
      }
    },
    responses: [
      ok: {"Lobby updated", "application/json", @lobby_schema},
      forbidden:
        {"Not the host", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:join,
    operation_id: "join_lobby",
    summary: "Join a lobby",
    description:
      "Join an existing lobby. If the lobby requires a password, include it in the request body.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Lobby ID", required: true]
    ],
    request_body: {
      "Join parameters (optional)",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          password: %Schema{type: :string, description: "Lobby password if required"}
        },
        example: %{password: "secret123"}
      }
    },
    responses: [
      ok:
        {"Successfully joined", "application/json",
         %Schema{
           type: :object,
           properties: %{message: %Schema{type: :string}},
           example: %{message: "joined"}
         }},
      forbidden:
        {"Cannot join (locked, full, wrong password, etc)", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:leave,
    operation_id: "leave_lobby",
    summary: "Leave the current lobby",
    description: "Leave the lobby you are currently in.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Lobby ID", required: true]
    ],
    responses: [
      ok:
        {"Successfully left", "application/json",
         %Schema{
           type: :object,
           properties: %{message: %Schema{type: :string}},
           example: %{message: "left"}
         }},
      bad_request:
        {"Not in a lobby", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:kick,
    operation_id: "kick_user",
    summary: "Kick a user from the lobby",
    description: "Remove a user from the lobby. Only the host can kick users.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Lobby ID", required: true]
    ],
    request_body: {
      "Kick parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          target_user_id: %Schema{type: :integer, description: "ID of the user to kick"}
        },
        required: [:target_user_id],
        example: %{target_user_id: 123}
      }
    },
    responses: [
      ok:
        {"User kicked", "application/json",
         %Schema{
           type: :object,
           properties: %{message: %Schema{type: :string}},
           example: %{message: "kicked"}
         }},
      forbidden:
        {"Not the host or cannot kick this user", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  def index(conn, params) do
    filters = Map.take(params || %{}, ["q", "metadata_key", "metadata_value"]) |> Enum.into(%{})
    lobbies = Lobbies.list_lobbies(filters)

    json(conn, Enum.map(lobbies, &serialize_lobby/1))
  end

  def create(conn, params) do
    # authenticated user becomes host by default if not hostless
    case conn.assigns.current_scope do
      %{user: %{id: id}} when not is_nil(id) ->
        params = Map.put(params, "host_id", id)

        case Lobbies.create_lobby(params) do
          {:ok, lobby} ->
            conn |> put_status(:created) |> json(serialize_lobby(lobby))

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
          {:ok, _membership} -> json(conn, %{message: "joined"})
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
            json(conn, %{message: "left"})

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
          {:ok, lobby} -> json(conn, serialize_lobby(lobby))
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
          {:ok, _} -> json(conn, %{message: "kicked"})
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
