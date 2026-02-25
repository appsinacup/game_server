defmodule GameServerWeb.Api.V1.PartyController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Parties
  alias OpenApiSpex.Schema

  tags(["Parties"])

  @party_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Party ID"},
      leader_id: %Schema{type: :integer, description: "User ID of the party leader"},
      max_size: %Schema{type: :integer, description: "Maximum party members allowed"},
      code: %Schema{
        type: :string,
        description: "Unique 6-character code for joining the party"
      },
      metadata: %Schema{type: :object, description: "Arbitrary metadata"},
      members: %Schema{
        type: :array,
        description: "Current party members",
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :integer},
            display_name: %Schema{type: :string, nullable: true},
            email: %Schema{type: :string, nullable: true},
            profile_url: %Schema{type: :string, nullable: true},
            is_online: %Schema{type: :boolean},
            last_seen_at: %Schema{type: :string, format: "date-time", nullable: true}
          }
        }
      }
    },
    example: %{
      id: 1,
      leader_id: 42,
      max_size: 4,
      code: "A3BK7P",
      metadata: %{},
      members: [
        %{
          id: 42,
          display_name: "Player1",
          email: "player1@example.com",
          profile_url: "",
          is_online: true,
          last_seen_at: "2025-01-15T10:30:00Z"
        }
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # OpenApiSpex operation definitions
  # ---------------------------------------------------------------------------

  operation(:show,
    operation_id: "show_party",
    summary: "Get current party",
    description: "Get the party the authenticated user is currently in, including members.",
    security: [%{"authorization" => []}],
    responses: [
      ok: {"Party details", "application/json", @party_schema},
      not_found:
        {"Not in a party", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:create,
    operation_id: "create_party",
    summary: "Create a party",
    description:
      "Create a new party. The authenticated user becomes the leader and first member. Cannot create a party while already in a party.",
    security: [%{"authorization" => []}],
    request_body: {
      "Party creation parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          max_size: %Schema{
            type: :integer,
            description: "Maximum members allowed (default: 4, min: 2, max: 32)",
            default: 4
          },
          metadata: %Schema{type: :object, description: "Arbitrary metadata"}
        },
        example: %{max_size: 4}
      }
    },
    responses: [
      created: {"Party created", "application/json", @party_schema},
      conflict:
        {"Already in a party", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:leave,
    operation_id: "leave_party",
    summary: "Leave the current party",
    description:
      "Leave the party you are currently in. If you are the leader, the party is disbanded and all members are removed.",
    security: [%{"authorization" => []}],
    responses: [
      ok: {"Success", "application/json", %Schema{type: :object}},
      bad_request:
        {"Not in a party", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:join_by_code,
    operation_id: "join_party_by_code",
    summary: "Join a party by code",
    description:
      "Join a party using its unique 6-character code. The code is case-insensitive. " <>
        "If you are already in a party, you will automatically leave it first " <>
        "(disbanding it if you are the leader).",
    security: [%{"authorization" => []}],
    request_body: {
      "Join parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          code: %Schema{
            type: :string,
            description: "The 6-character party code",
            minLength: 6,
            maxLength: 6
          }
        },
        required: [:code],
        example: %{code: "A3BK7P"}
      }
    },
    responses: [
      ok: {"Party joined", "application/json", @party_schema},
      not_found:
        {"Party not found", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      forbidden:
        {"Party full", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:kick,
    operation_id: "kick_party_member",
    summary: "Kick a member from the party (leader only)",
    description: "Remove a member from the party. Only the party leader can kick members.",
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
      ok: {"User kicked", "application/json", %Schema{type: :object}},
      forbidden:
        {"Not the leader", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:update,
    operation_id: "update_party",
    summary: "Update party settings (leader only)",
    description:
      "Update party settings such as max_size and metadata. Only the leader can update.",
    security: [%{"authorization" => []}],
    request_body: {
      "Party update parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          max_size: %Schema{type: :integer, description: "New maximum size"},
          metadata: %Schema{type: :object, description: "New metadata"}
        },
        example: %{max_size: 6}
      }
    },
    responses: [
      ok: {"Party updated", "application/json", @party_schema},
      forbidden:
        {"Not the leader", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:create_lobby,
    operation_id: "party_create_lobby",
    summary: "Create a lobby with the party (leader only)",
    description:
      "The party leader creates a new lobby and all party members join it atomically. The party is kept intact. No party member may already be in a lobby. The lobby must have enough capacity for all party members.",
    security: [%{"authorization" => []}],
    request_body: {
      "Lobby creation parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          title: %Schema{type: :string, description: "Display title for the lobby"},
          max_users: %Schema{type: :integer, description: "Maximum users allowed (default: 8)"},
          is_hidden: %Schema{type: :boolean, description: "Hide from public listings"},
          is_locked: %Schema{type: :boolean, description: "Lock the lobby"},
          password: %Schema{type: :string, description: "Optional password"},
          metadata: %Schema{type: :object, description: "Arbitrary metadata"}
        },
        example: %{title: "Party Lobby", max_users: 8}
      }
    },
    responses: [
      created:
        {"Lobby created with all party members", "application/json", %Schema{type: :object}},
      forbidden:
        {"Not the leader or lobby too small", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:join_lobby,
    operation_id: "party_join_lobby",
    summary: "Join a lobby with the party (leader only)",
    description:
      "The party leader joins an existing lobby and all party members join atomically. The party is kept intact. No party member may already be in a lobby. The lobby must have enough free space for all party members.",
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
      ok: {"Lobby joined with all party members", "application/json", %Schema{type: :object}},
      forbidden:
        {"Cannot join (not enough space, locked, wrong password, etc)", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  # ---------------------------------------------------------------------------
  # Actions
  # ---------------------------------------------------------------------------

  def show(conn, _params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        if is_nil(user.party_id) do
          conn |> put_status(:not_found) |> json(%{error: "not_in_party"})
        else
          party = Parties.get_party(user.party_id)

          if is_nil(party) do
            conn |> put_status(:not_found) |> json(%{error: "party_not_found"})
          else
            json(conn, serialize_party(party))
          end
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def create(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        case Parties.create_party(user, params) do
          {:ok, party} ->
            conn
            |> put_status(:created)
            |> json(serialize_party(party))

          {:error, :already_in_party} ->
            conn |> put_status(:conflict) |> json(%{error: "already_in_party"})

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
            })

          other ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def leave(conn, _params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        case Parties.leave_party(user) do
          {:ok, _} ->
            json(conn, %{})

          {:error, :not_in_party} ->
            json(conn, %{})

          other ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def join_by_code(conn, %{"code" => code}) when is_binary(code) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        case Parties.join_party_by_code(user, code) do
          {:ok, updated_user} ->
            updated_user = GameServer.Accounts.get_user(updated_user.id)

            if updated_user.party_id do
              party = Parties.get_party(updated_user.party_id)
              json(conn, serialize_party(party))
            else
              json(conn, %{message: "joined"})
            end

          {:error, :party_not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "party_not_found"})

          {:error, :party_full} ->
            conn |> put_status(:forbidden) |> json(%{error: "party_full"})

          other ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def join_by_code(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "missing_code"})
  end

  def kick(conn, %{"target_user_id" => target_user_id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        target_id =
          case target_user_id do
            id when is_integer(id) -> id
            id when is_binary(id) -> String.to_integer(id)
          end

        case Parties.kick_member(user, target_id) do
          {:ok, _} ->
            json(conn, %{})

          {:error, :not_in_party} ->
            conn |> put_status(:bad_request) |> json(%{error: "not_in_party"})

          {:error, :not_leader} ->
            conn |> put_status(:forbidden) |> json(%{error: "not_leader"})

          {:error, :cannot_kick_self} ->
            conn |> put_status(:forbidden) |> json(%{error: "cannot_kick_self"})

          {:error, :user_not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "user_not_found"})

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
        case Parties.update_party(user, params) do
          {:ok, party} ->
            json(conn, serialize_party(party))

          {:error, :not_in_party} ->
            conn |> put_status(:bad_request) |> json(%{error: "not_in_party"})

          {:error, :not_leader} ->
            conn |> put_status(:forbidden) |> json(%{error: "not_leader"})

          {:error, :too_small} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: "too_small"})

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
            })

          other ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def create_lobby(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        case Parties.create_lobby_with_party(user, params) do
          {:ok, lobby} ->
            conn
            |> put_status(:created)
            |> json(serialize_lobby(lobby))

          {:error, :not_in_party} ->
            conn |> put_status(:bad_request) |> json(%{error: "not_in_party"})

          {:error, :not_leader} ->
            conn |> put_status(:forbidden) |> json(%{error: "not_leader"})

          {:error, :lobby_too_small_for_party} ->
            conn |> put_status(:forbidden) |> json(%{error: "lobby_too_small_for_party"})

          {:error, :member_in_lobby} ->
            conn |> put_status(:conflict) |> json(%{error: "member_in_lobby"})

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
            })

          other ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def join_lobby(conn, %{"id" => id} = params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        case Integer.parse(to_string(id)) do
          {lobby_id, ""} ->
            opts = %{password: Map.get(params, "password") || Map.get(params, :password)}

            case Parties.join_lobby_with_party(user, lobby_id, opts) do
              {:ok, lobby} ->
                json(conn, serialize_lobby(lobby))

              {:error, :not_in_party} ->
                conn |> put_status(:bad_request) |> json(%{error: "not_in_party"})

              {:error, :not_leader} ->
                conn |> put_status(:forbidden) |> json(%{error: "not_leader"})

              {:error, :member_in_lobby} ->
                conn |> put_status(:conflict) |> json(%{error: "member_in_lobby"})

              {:error, :invalid_lobby} ->
                conn |> put_status(:not_found) |> json(%{error: "not_found"})

              {:error, :locked} ->
                conn |> put_status(:forbidden) |> json(%{error: "locked"})

              {:error, :not_enough_space} ->
                conn |> put_status(:forbidden) |> json(%{error: "not_enough_space"})

              {:error, :password_required} ->
                conn |> put_status(:forbidden) |> json(%{error: "password_required"})

              {:error, :invalid_password} ->
                conn |> put_status(:forbidden) |> json(%{error: "invalid_password"})

              other ->
                conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
            end

          _ ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  # ---------------------------------------------------------------------------
  # Serialization
  # ---------------------------------------------------------------------------

  defp serialize_party(party) do
    members = Parties.get_party_members(party.id)

    %{
      id: party.id,
      leader_id: party.leader_id,
      max_size: party.max_size,
      code: party.code,
      metadata: party.metadata || %{},
      members:
        Enum.map(members, fn m ->
          %{
            id: m.id,
            display_name: m.display_name || "",
            email: m.email || "",
            profile_url: m.profile_url || "",
            is_online: m.is_online || false,
            last_seen_at: m.last_seen_at
          }
        end),
      inserted_at: party.inserted_at,
      updated_at: party.updated_at
    }
  end

  defp serialize_lobby(lobby) do
    host_id = if is_nil(lobby.host_id), do: -1, else: lobby.host_id

    %{
      id: lobby.id,
      title: lobby.title,
      host_id: host_id,
      hostless: lobby.hostless,
      max_users: lobby.max_users,
      is_hidden: lobby.is_hidden,
      is_locked: lobby.is_locked,
      metadata: lobby.metadata || %{},
      is_passworded: lobby.password_hash != nil
    }
  end
end
