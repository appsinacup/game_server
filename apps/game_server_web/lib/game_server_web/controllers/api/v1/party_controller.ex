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
      metadata: %Schema{type: :object, description: "Arbitrary metadata"},
      members: %Schema{
        type: :array,
        description: "Current party members",
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :integer},
            display_name: %Schema{type: :string, nullable: true},
            email: %Schema{type: :string, nullable: true}
          }
        }
      }
    },
    example: %{
      id: 1,
      leader_id: 42,
      max_size: 4,
      metadata: %{},
      members: [
        %{id: 42, display_name: "Player1", email: "player1@example.com"}
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

  operation(:invite,
    operation_id: "invite_to_party",
    summary: "Invite a user to the party (leader only)",
    description:
      "Send a party invite notification to a user. Only the party leader can send invites. The target user must not be in another party or lobby.",
    security: [%{"authorization" => []}],
    request_body: {
      "Invite parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          target_user_id: %Schema{type: :integer, description: "ID of the user to invite"}
        },
        required: [:target_user_id],
        example: %{target_user_id: 42}
      }
    },
    responses: [
      created:
        {"Invite sent", "application/json",
         %Schema{type: :object, properties: %{message: %Schema{type: :string}}}},
      conflict:
        {"Target already in a party/lobby or duplicate invite", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      forbidden:
        {"Not the leader", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:invites,
    operation_id: "list_party_invites",
    summary: "List pending party invites",
    description: "List all pending party invitations for the authenticated user.",
    security: [%{"authorization" => []}],
    parameters: [
      page: [in: :query, schema: %Schema{type: :integer}, description: "Page number"],
      page_size: [in: :query, schema: %Schema{type: :integer}, description: "Items per page"]
    ],
    responses: [
      ok:
        {"Party invites", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: %Schema{type: :object}},
             meta: %Schema{type: :object}
           }
         }},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:sent_invites,
    operation_id: "list_sent_party_invites",
    summary: "List sent party invites (leader only)",
    description: "List all party invitations sent by the authenticated user.",
    security: [%{"authorization" => []}],
    parameters: [
      page: [in: :query, schema: %Schema{type: :integer}, description: "Page number"],
      page_size: [in: :query, schema: %Schema{type: :integer}, description: "Items per page"]
    ],
    responses: [
      ok:
        {"Sent party invites", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: %Schema{type: :object}},
             meta: %Schema{type: :object}
           }
         }},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:accept_invite,
    operation_id: "accept_party_invite",
    summary: "Accept a party invite",
    description:
      "Accept a pending party invitation. The user joins the party and the invite is deleted.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :integer},
        description: "Invite (notification) ID",
        required: true
      ]
    ],
    responses: [
      ok: {"Successfully joined", "application/json", @party_schema},
      conflict:
        {"Already in a party or lobby", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      not_found:
        {"Invite not found", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      forbidden:
        {"Party full", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:decline_invite,
    operation_id: "decline_party_invite",
    summary: "Decline a party invite",
    description: "Decline (delete) a pending party invitation.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :integer},
        description: "Invite (notification) ID",
        required: true
      ]
    ],
    responses: [
      ok:
        {"Invite declined", "application/json",
         %Schema{type: :object, properties: %{message: %Schema{type: :string}}}},
      not_found:
        {"Invite not found", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      unauthorized:
        {"Not authenticated", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}}
    ]
  )

  operation(:cancel_invite,
    operation_id: "cancel_party_invite",
    summary: "Cancel a sent party invite (leader only)",
    description: "Cancel (delete) a party invitation that you sent.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :integer},
        description: "Invite (notification) ID",
        required: true
      ]
    ],
    responses: [
      ok:
        {"Invite cancelled", "application/json",
         %Schema{type: :object, properties: %{message: %Schema{type: :string}}}},
      not_found:
        {"Invite not found", "application/json",
         %Schema{type: :object, properties: %{error: %Schema{type: :string}}}},
      forbidden:
        {"Not the sender", "application/json",
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

  def invite(conn, %{"target_user_id" => target_user_id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        target_id =
          case target_user_id do
            id when is_integer(id) -> id
            id when is_binary(id) -> String.to_integer(id)
          end

        case Parties.invite_to_party(user, target_id) do
          {:ok, _notification} ->
            conn |> put_status(:created) |> json(%{message: "invite_sent"})

          {:error, :not_in_party} ->
            conn |> put_status(:bad_request) |> json(%{error: "not_in_party"})

          {:error, :not_leader} ->
            conn |> put_status(:forbidden) |> json(%{error: "not_leader"})

          {:error, :self_invite} ->
            conn |> put_status(:bad_request) |> json(%{error: "self_invite"})

          {:error, :blocked} ->
            conn |> put_status(:forbidden) |> json(%{error: "blocked"})

          {:error, :target_in_party} ->
            conn |> put_status(:conflict) |> json(%{error: "target_in_party"})

          {:error, :user_not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "user_not_found"})

          {:error, %Ecto.Changeset{}} ->
            conn |> put_status(:conflict) |> json(%{error: "invite_already_sent"})

          other ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def invites(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        page = parse_int(params["page"], 1)
        page_size = parse_int(params["page_size"], 25)
        invites = Parties.list_party_invites(user.id, page: page, page_size: page_size)
        total_count = Parties.count_party_invites(user.id)
        total_pages = if page_size > 0, do: div(total_count + page_size - 1, page_size), else: 0

        data =
          Enum.map(invites, fn n ->
            %{
              id: n.id,
              sender_id: n.sender_id,
              sender_name: (n.sender && (n.sender.display_name || n.sender.email)) || "",
              party_id: n.metadata["party_id"],
              content: n.content,
              inserted_at: n.inserted_at
            }
          end)

        json(conn, %{
          data: data,
          meta: %{
            page: page,
            page_size: page_size,
            count: length(data),
            total_count: total_count,
            total_pages: total_pages,
            has_more: length(data) == page_size
          }
        })

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def sent_invites(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        page = parse_int(params["page"], 1)
        page_size = parse_int(params["page_size"], 25)
        invites = Parties.list_sent_party_invites(user.id, page: page, page_size: page_size)

        data =
          Enum.map(invites, fn n ->
            %{
              id: n.id,
              recipient_id: n.recipient_id,
              recipient_name:
                (n.recipient && (n.recipient.display_name || n.recipient.email)) || "",
              party_id: n.metadata["party_id"],
              content: n.content,
              inserted_at: n.inserted_at
            }
          end)

        json(conn, %{data: data})

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def accept_invite(conn, %{"id" => id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        do_accept_invite(conn, user, id)

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  defp do_accept_invite(conn, user, id) do
    case Integer.parse(to_string(id)) do
      {invite_id, ""} ->
        handle_accept_result(conn, user, Parties.accept_party_invite(user, invite_id))

      _ ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  end

  defp handle_accept_result(conn, user, {:ok, _user}) do
    updated_user = GameServer.Accounts.get_user(user.id)

    if updated_user.party_id do
      party = Parties.get_party(updated_user.party_id)
      json(conn, serialize_party(party))
    else
      json(conn, %{message: "joined"})
    end
  end

  defp handle_accept_result(conn, _user, {:error, :invite_not_found}),
    do: conn |> put_status(:not_found) |> json(%{error: "invite_not_found"})

  defp handle_accept_result(conn, _user, {:error, :already_in_party}),
    do: conn |> put_status(:conflict) |> json(%{error: "already_in_party"})

  defp handle_accept_result(conn, _user, {:error, :party_not_found}),
    do: conn |> put_status(:not_found) |> json(%{error: "party_not_found"})

  defp handle_accept_result(conn, _user, {:error, :party_full}),
    do: conn |> put_status(:forbidden) |> json(%{error: "party_full"})

  defp handle_accept_result(conn, _user, other),
    do: conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(other)})

  def decline_invite(conn, %{"id" => id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        case Integer.parse(to_string(id)) do
          {invite_id, ""} ->
            case Parties.decline_party_invite(user, invite_id) do
              :ok ->
                json(conn, %{message: "invite_declined"})

              {:error, :invite_not_found} ->
                conn |> put_status(:not_found) |> json(%{error: "invite_not_found"})

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

  def cancel_invite(conn, %{"id" => id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) ->
        case Integer.parse(to_string(id)) do
          {invite_id, ""} ->
            case Parties.cancel_party_invite(user, invite_id) do
              :ok ->
                json(conn, %{message: "invite_cancelled"})

              {:error, :invite_not_found} ->
                conn |> put_status(:not_found) |> json(%{error: "invite_not_found"})

              {:error, :not_sender} ->
                conn |> put_status(:forbidden) |> json(%{error: "not_sender"})

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
      metadata: party.metadata || %{},
      members:
        Enum.map(members, fn m ->
          %{
            id: m.id,
            display_name: m.display_name || "",
            email: m.email || ""
          }
        end),
      inserted_at: party.inserted_at,
      updated_at: party.updated_at
    }
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, _default) when is_integer(val), do: val

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(_val, default), do: default

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
