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
      title: %Schema{type: :string, description: "Display title"},
      host_id: %Schema{type: :integer, description: "User ID of the host", nullable: true},
      hostless: %Schema{type: :boolean, description: "Whether this is a server-managed lobby"},
      max_users: %Schema{type: :integer, description: "Maximum number of users allowed"},
      is_hidden: %Schema{type: :boolean, description: "Hidden from public listings"},
      is_locked: %Schema{type: :boolean, description: "Locked - no new joins allowed"},
      is_passworded: %Schema{
        type: :boolean,
        description: "Whether this lobby requires a password to join"
      },
      metadata: %Schema{type: :object, description: "Arbitrary metadata"}
    },
    example: %{
      id: 1,
      # 'name' (slug) intentionally omitted from API responses - use 'id' and 'title'
      title: "My Game Lobby",
      host_id: 42,
      hostless: false,
      max_users: 8,
      is_hidden: false,
      is_locked: false,
      is_passworded: false,
      metadata: %{}
    }
  }

  operation(:index,
    operation_id: "list_lobbies",
    summary: "List lobbies",
    description:
      "Return all non-hidden lobbies. Supports optional text search via 'title', metadata filters, password/lock filters, and numeric min/max for max_users.",
    parameters: [
      title: [
        in: :query,
        schema: %Schema{type: :string},
        description: "Search term for title"
      ],
      is_passworded: [
        in: :query,
        schema: %Schema{type: :string, enum: ["true", "false"]},
        description: "Filter by passworded lobbies - 'true' or 'false' (omit for any)"
      ],
      is_locked: [
        in: :query,
        schema: %Schema{type: :string, enum: ["true", "false"]},
        description: "Filter by locked status - 'true' or 'false' (omit for any)"
      ],
      min_users: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Minimum max_users to include"
      ],
      max_users: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Maximum max_users to include"
      ],
      page: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Page number (1-based)",
        required: false
      ],
      page_size: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Page size (max results per page)",
        required: false
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
      ok:
        {"List of lobbies (paginated)", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @lobby_schema},
             meta: %Schema{
               type: :object,
               properties: %{
                 page: %Schema{type: :integer},
                 page_size: %Schema{type: :integer},
                 count: %Schema{type: :integer},
                 total_count: %Schema{type: :integer},
                 total_pages: %Schema{type: :integer},
                 has_more: %Schema{type: :boolean}
               }
             }
           }
         }}
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
    description:
      "Update lobby settings. Only the host can update the lobby via the API (returns 403 if not host). Admins can still modify lobbies from the admin console - those changes are broadcast to viewers.",
    security: [%{"authorization" => []}],
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
    # Uses the authenticated user's lobby_id - no path id required
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
      no_content: {"Successfully joined", "application/json", nil},
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
    responses: [
      no_content: {"No content", "application/json", nil},
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
    summary: "Kick a user from the lobby (host only)",
    description:
      "Remove a user from the lobby. Only the host can kick users via the API (returns 403 if not host).",
    security: [%{"authorization" => []}],
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
      no_content: {"User kicked", "application/json", nil},
      forbidden:
        {"Not the host or cannot kick this user", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:quick_join,
    operation_id: "quick_join",
    summary: "Quick-join or create a lobby",
    description:
      "Attempt to find an open, non-passworded lobby that matches the provided criteria and join it; if none found, create a new lobby. The authenticated user will become the host when a lobby is created.",
    security: [%{"authorization" => []}],
    request_body: {
      "Quick join parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          title: %Schema{type: :string, description: "Optional title for a newly created lobby"},
          max_users: %Schema{
            type: :integer,
            description: "Optional maximum users to match/create"
          },
          metadata: %Schema{
            type: :object,
            description: "Optional metadata to match (substring match)"
          }
        }
      }
    },
    responses: [
      ok: {"Lobby joined or created", "application/json", @lobby_schema},
      conflict:
        {"User already in a lobby", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  def index(conn, params) do
    filters =
      Map.take(params || %{}, [
        "title",
        "metadata_key",
        "metadata_value",
        "is_passworded",
        "is_locked",
        "min_users",
        "max_users"
      ])
      |> Enum.into(%{})

    page =
      case params["page"] || params[:page] do
        p when is_binary(p) -> String.to_integer(p)
        p when is_integer(p) -> p
        _ -> 1
      end

    page_size =
      case params["page_size"] || params[:page_size] do
        p when is_binary(p) -> String.to_integer(p)
        p when is_integer(p) -> p
        _ -> 25
      end

    lobbies = Lobbies.list_lobbies(filters, page: page, page_size: page_size)
    serialized = Enum.map(lobbies, &serialize_lobby/1)
    count = length(serialized)

    total_count = Lobbies.count_list_lobbies(filters)

    json(conn, %{
      data: serialized,
      meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
    })
  end

  defp serialize_lobby(lobby) do
    %{
      id: lobby.id,
      title: lobby.title,
      host_id: lobby.host_id,
      hostless: lobby.hostless,
      max_users: lobby.max_users,
      is_hidden: lobby.is_hidden,
      is_locked: lobby.is_locked,
      metadata: lobby.metadata || %{},
      is_passworded: lobby.password_hash != nil
    }
  end

  ### API actions (create/join/update/leave/kick) ###

  def create(conn, params) do
    # disallow hostless creation from public API
    if Map.get(params, "hostless") == true or Map.get(params, :hostless) == true do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Not authenticated"})
    else
      case conn.assigns[:current_scope] do
        %{user: user} when is_map(user) ->
          attrs = Map.put(params, "host_id", user.id)

          case Lobbies.create_lobby(attrs) do
            {:ok, lobby} ->
              conn
              |> put_status(:created)
              |> json(serialize_lobby(lobby))

            {:error, %Ecto.Changeset{} = changeset} ->
              conn
              |> put_status(:conflict)
              |> json(%{
                error: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
              })

            other ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: inspect(other)})
          end

        _ ->
          conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
      end
    end
  end

  def join(conn, %{"id" => id} = params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        password = Map.get(params, "password") || Map.get(params, :password)

        case Lobbies.join_lobby(user, id, %{password: password}) do
          {:ok, _member} ->
            send_resp(conn, :no_content, "")

          {:error, :invalid_lobby} ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})

          {:error, :already_in_lobby} ->
            conn |> put_status(:forbidden) |> json(%{error: "already_in_lobby"})

          {:error, :password_required} ->
            conn |> put_status(:forbidden) |> json(%{error: "password_required"})

          {:error, :invalid_password} ->
            conn |> put_status(:forbidden) |> json(%{error: "invalid_password"})

          {:error, :locked} ->
            conn |> put_status(:forbidden) |> json(%{error: "locked"})

          {:error, :full} ->
            conn |> put_status(:forbidden) |> json(%{error: "full"})

          {:error, {:hook_rejected, _}} ->
            conn |> put_status(:forbidden) |> json(%{error: "rejected"})

          _ ->
            conn |> put_status(:forbidden) |> json(%{error: "cannot_join"})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def quick_join(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        title = Map.get(params, "title") || Map.get(params, :title)
        max_users = Map.get(params, "max_users") || Map.get(params, :max_users)
        metadata = Map.get(params, "metadata") || Map.get(params, :metadata)

        case Lobbies.quick_join(user, title, max_users, metadata || %{}) do
          {:ok, lobby} ->
            json(conn, serialize_lobby(lobby))

          {:error, :already_in_lobby} ->
            conn |> put_status(:conflict) |> json(%{error: "already_in_lobby"})

          {:error, reason} when is_atom(reason) ->
            conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})

          {:error, {:hook_rejected, _}} ->
            conn |> put_status(:forbidden) |> json(%{error: "rejected"})

          other ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def update(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        # Use the authenticated user's lobby_id - require that the user is in a lobby
        if is_nil(user.lobby_id) do
          conn |> put_status(:bad_request) |> json(%{error: "not_in_lobby"})
        else
          lobby = Lobbies.get_lobby!(user.lobby_id)

          case Lobbies.update_lobby_by_host(user, lobby, params) do
            {:ok, updated} ->
              json(conn, serialize_lobby(updated))

            {:error, :not_host} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_host"})

            {:error, :too_small} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: "too_small"})

            {:error, %Ecto.Changeset{} = changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)})

            other ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
          end
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def kick(conn, %{"target_user_id" => target_user_id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        if is_nil(user.lobby_id) do
          conn |> put_status(:bad_request) |> json(%{error: "not_in_lobby"})
        else
          lobby = Lobbies.get_lobby!(user.lobby_id)
          target = GameServer.Accounts.get_user!(target_user_id)

          case Lobbies.kick_user(user, lobby, target) do
            {:ok, _} ->
              send_resp(conn, :no_content, "")

            {:error, :not_host} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_host"})

            {:error, :cannot_kick_self} ->
              conn |> put_status(:forbidden) |> json(%{error: "cannot_kick_self"})

            {:error, :not_found} ->
              conn |> put_status(:not_found) |> json(%{error: "not_found"})

            {:error, {:hook_rejected, _}} ->
              conn |> put_status(:forbidden) |> json(%{error: "rejected"})

            other ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
          end
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def leave(conn, _params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        # Use the authenticated user's lobby (ignore path id)
        if is_nil(user.lobby_id) do
          conn |> put_status(:bad_request) |> json(%{error: "not_in_lobby"})
        else
          case Lobbies.leave_lobby(user) do
            {:ok, _} ->
              send_resp(conn, :no_content, "")

            {:error, :not_in_lobby} ->
              conn |> put_status(:bad_request) |> json(%{error: "not_in_lobby"})

            {:error, {:hook_rejected, _}} ->
              conn |> put_status(:forbidden) |> json(%{error: "rejected"})

            other ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
          end
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end
end
