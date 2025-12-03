defmodule GameServerWeb.Api.V1.FriendController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Friends
  alias GameServer.Repo
  # Accounts is not used here, remove to avoid warnings
  alias OpenApiSpex.Schema

  tags(["Friends"])

  operation(:create,
    operation_id: "create_friend_request",
    summary: "Send a friend request",
    security: [%{"authorization" => []}],
    request_body: {
      "Friend request",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          target_user_id: %Schema{
            type: :integer,
            description: "Target user's id (user_id) to whom the request will be sent"
          }
        },
        required: [:target_user_id]
      }
    },
    responses: [
      created: {"Request created", "application/json", nil},
      conflict: {"Already friends or requested", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", nil}
    ]
  )

  operation(:index,
    operation_id: "list_friends",
    summary: "List current user's friends (returns a paginated set of user objects)",
    security: [%{"authorization" => []}],
    parameters: [
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
      ]
    ],
    responses: [
      ok:
        {"List of friends (paginated)", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{
               type: :array,
               items: %Schema{
                 type: :object,
                 properties: %{
                   id: %Schema{type: :integer},
                   email: %Schema{type: :string},
                   display_name: %Schema{type: :string},
                   profile_url: %Schema{type: :string}
                 }
               }
             },
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

  operation(:requests,
    operation_id: "list_friend_requests",
    summary: "List pending friend requests (incoming and outgoing)",
    security: [%{"authorization" => []}],
    parameters: [
      page: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Page number (1-based, applied to both lists)",
        required: false
      ],
      page_size: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Page size (applied to both lists)",
        required: false
      ]
    ],
    responses: [
      ok: {
        "Requests",
        "application/json",
        %Schema{
          type: :object,
          properties: %{
            incoming: %Schema{
              type: :array,
              items: %Schema{
                type: :object,
                properties: %{
                  id: %Schema{type: :integer},
                  requester: %Schema{
                    type: :object,
                    properties: %{
                      id: %Schema{type: :integer},
                      display_name: %Schema{type: :string}
                    }
                  },
                  target: %Schema{
                    type: :object,
                    properties: %{
                      id: %Schema{type: :integer},
                      display_name: %Schema{type: :string}
                    }
                  },
                  status: %Schema{type: :string},
                  inserted_at: %Schema{type: :string, format: :date_time}
                }
              }
            },
            outgoing: %Schema{
              type: :array,
              items: %Schema{
                type: :object,
                properties: %{
                  id: %Schema{type: :integer},
                  requester: %Schema{
                    type: :object,
                    properties: %{
                      id: %Schema{type: :integer},
                      display_name: %Schema{type: :string}
                    }
                  },
                  target: %Schema{
                    type: :object,
                    properties: %{
                      id: %Schema{type: :integer},
                      display_name: %Schema{type: :string}
                    }
                  },
                  status: %Schema{type: :string},
                  inserted_at: %Schema{type: :string, format: :date_time}
                }
              }
            },
            meta: %Schema{
              type: :object,
              properties: %{
                page: %Schema{type: :integer},
                page_size: %Schema{type: :integer},
                counts: %Schema{type: :object},
                total_counts: %Schema{type: :object},
                total_pages: %Schema{type: :object},
                has_more: %Schema{type: :object}
              }
            }
          }
        }
      }
    ]
  )

  operation(:accept,
    operation_id: "accept_friend_request",
    summary: "Accept a friend request",
    security: [%{"authorization" => []}],
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :integer},
        description:
          "Friendship record id (friendship_id) - the id of the friendship row, not a user id",
        required: true
      ]
    ],
    responses: [
      ok: {"Accepted", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", nil},
      forbidden: {"Not authorized", "application/json", nil}
    ]
  )

  operation(:reject,
    operation_id: "reject_friend_request",
    summary: "Reject a friend request",
    security: [%{"authorization" => []}],
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :integer},
        description:
          "Friendship record id (friendship_id) - the id of the friendship row, not a user id",
        required: true
      ]
    ],
    responses: [
      ok: {"Rejected", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", nil},
      forbidden: {"Not authorized", "application/json", nil}
    ]
  )

  operation(:block,
    operation_id: "block_friend_request",
    summary: "Block a friend request / user",
    security: [%{"authorization" => []}],
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :integer},
        description:
          "Friendship record id (friendship_id) - the id of the friendship row, not a user id",
        required: true
      ]
    ],
    responses: [
      ok: {"Blocked", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", nil},
      forbidden: {"Not authorized", "application/json", nil}
    ]
  )

  operation(:blocked,
    operation_id: "list_blocked_friends",
    summary: "List users you've blocked",
    security: [%{"authorization" => []}],
    parameters: [
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
      ]
    ],
    responses: [
      ok: {
        "Blocked list",
        "application/json",
        %Schema{
          type: :object,
          properties: %{
            data: %Schema{
              type: :array,
              items: %Schema{
                type: :object,
                properties: %{
                  id: %Schema{type: :integer},
                  requester: %Schema{
                    type: :object,
                    properties: %{
                      id: %Schema{type: :integer},
                      display_name: %Schema{type: :string},
                      email: %Schema{type: :string}
                    }
                  }
                }
              }
            },
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
        }
      }
    ]
  )

  operation(:unblock,
    operation_id: "unblock_friend",
    summary: "Unblock a previously-blocked friendship",
    security: [%{"authorization" => []}],
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :integer},
        description:
          "Friendship record id (friendship_id) - the id of the friendship row, not a user id",
        required: true
      ]
    ],
    responses: [
      ok: {"Unblocked", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", nil},
      forbidden: {"Not authorized", "application/json", nil},
      not_found: {"Not found", "application/json", nil}
    ]
  )

  operation(:delete,
    operation_id: "remove_friendship",
    summary: "Remove/cancel a friendship or request",
    security: [%{"authorization" => []}],
    parameters: [id: [in: :path, schema: %Schema{type: :integer}, required: true]],
    responses: [
      ok: {"Success", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", nil},
      forbidden: {"Not authorized", "application/json", nil}
    ]
  )

  # Clarify: the :id path parameter in accept/reject/block/delete/unblock
  # refers to the friendship record ID (friendship_id), not a user_id.

  def create(conn, %{"target_user_id" => _} = params) do
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        target_id = params["target_user_id"]

        case Friends.create_request(user.id, target_id) do
          {:ok, _f} ->
            conn |> put_status(:created) |> send_resp(:created, "")

          {:error, :cannot_friend_self} ->
            conn |> put_status(:bad_request) |> json(%{error: "cannot_friend_self"})

          {:error, :already_friends} ->
            conn |> put_status(:conflict) |> json(%{error: "already_friends"})

          {:error, :already_requested} ->
            conn |> put_status(:conflict) |> json(%{error: "already_requested"})

          {:error, %Ecto.Changeset{} = cs} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: Ecto.Changeset.traverse_errors(cs, & &1)})

          {:error, reason} ->
            conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  defp parse_page_params(params) do
    page = params["page"] || params[:page]
    page_size = params["page_size"] || params[:page_size]

    page =
      case page do
        p when is_binary(p) -> String.to_integer(p)
        p when is_integer(p) -> p
        _ -> 1
      end

    page_size =
      case page_size do
        p when is_binary(p) -> String.to_integer(p)
        p when is_integer(p) -> p
        _ -> 25
      end

    {page, page_size}
  end

  def block(conn, %{"id" => id}) do
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        case Friends.block_friend_request(String.to_integer(id), user) do
          {:ok, _f} ->
            json(conn, %{})

          {:error, :not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})

          {:error, :not_authorized} ->
            conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

          {:error, reason} ->
            conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def index(conn, params) do
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        {page, page_size} = parse_page_params(params)

        friends = Friends.list_friends_for_user(user, page: page, page_size: page_size)
        serialized = Enum.map(friends, &serialize_user/1)
        count = length(serialized)
        total_count = Friends.count_friends_for_user(user)

        json(conn, %{
          data: serialized,
          meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
        })

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def blocked(conn, params) do
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        {page, page_size} = parse_page_params(params)

        blocked = Friends.list_blocked_for_user(user, page: page, page_size: page_size)

        serialized =
          Enum.map(blocked, fn f -> %{id: f.id, requester: serialize_user(f.requester)} end)

        count = length(serialized)
        total_count = Friends.count_blocked_for_user(user)

        json(conn, %{
          data: serialized,
          meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
        })

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def unblock(conn, %{"id" => id}) do
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        case Friends.unblock_friendship(String.to_integer(id), user) do
          {:ok, :unblocked} ->
            json(conn, %{})

          {:error, :not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})

          {:error, :not_authorized} ->
            conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

          {:error, reason} ->
            conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def requests(conn, params) do
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        {page, page_size} = parse_page_params(params)

        incoming = Friends.list_incoming_requests(user, page: page, page_size: page_size)
        outgoing = Friends.list_outgoing_requests(user, page: page, page_size: page_size)

        inc_serialized = Enum.map(incoming, &serialize_request/1)
        out_serialized = Enum.map(outgoing, &serialize_request/1)

        total_in = Friends.count_incoming_requests(user)
        total_out = Friends.count_outgoing_requests(user)

        total_pages_in = if page_size > 0, do: div(total_in + page_size - 1, page_size), else: 0
        total_pages_out = if page_size > 0, do: div(total_out + page_size - 1, page_size), else: 0

        json(conn, %{
          incoming: inc_serialized,
          outgoing: out_serialized,
          meta: %{
            page: page,
            page_size: page_size,
            counts: %{incoming: length(inc_serialized), outgoing: length(out_serialized)},
            total_counts: %{incoming: total_in, outgoing: total_out},
            total_pages: %{incoming: total_pages_in, outgoing: total_pages_out},
            has_more: %{
              incoming: length(inc_serialized) == page_size,
              outgoing: length(out_serialized) == page_size
            }
          }
        })

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def accept(conn, %{"id" => id}) do
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        case Friends.accept_friend_request(String.to_integer(id), user) do
          {:ok, _f} ->
            json(conn, %{})

          {:error, :not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})

          {:error, :not_authorized} ->
            conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

          {:error, reason} ->
            conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def reject(conn, %{"id" => id}) do
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        case Friends.reject_friend_request(String.to_integer(id), user) do
          {:ok, _f} ->
            json(conn, %{})

          {:error, :not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})

          {:error, :not_authorized} ->
            conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

          {:error, reason} ->
            conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  def delete(conn, %{"id" => id}) do
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        # Try to fetch and delete. allow requesters to cancel pending, or either user to delete accepted friendship
        case Repo.get(Friends.Friendship, String.to_integer(id)) do
          nil ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})

          f ->
            handle_delete_friendship(conn, user, f)
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  defp handle_delete_friendship(conn, user, f) do
    cond do
      f.status == "pending" and f.requester_id == user.id ->
        case Friends.cancel_request(f.id, user) do
          {:ok, :cancelled} -> json(conn, %{})
          err -> conn |> put_status(:bad_request) |> json(%{error: to_string(err)})
        end

      f.status == "accepted" and (f.requester_id == user.id or f.target_id == user.id) ->
        case Friends.remove_friend(
               user.id,
               if(f.requester_id == user.id, do: f.target_id, else: f.requester_id)
             ) do
          {:ok, _} -> json(conn, %{})
          err -> conn |> put_status(:bad_request) |> json(%{error: to_string(err)})
        end

      true ->
        conn |> put_status(:forbidden) |> json(%{error: "not_authorized"})
    end
  end

  defp serialize_user(user) do
    %{
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      profile_url: user.profile_url
    }
  end

  defp serialize_request(%Friends.Friendship{} = f) do
    requester =
      case f.requester do
        %Ecto.Association.NotLoaded{} -> %{id: f.requester_id, display_name: nil}
        %{} = r -> %{id: r.id, display_name: r.display_name}
      end

    target =
      case f.target do
        %Ecto.Association.NotLoaded{} -> %{id: f.target_id, display_name: nil}
        %{} = t -> %{id: t.id, display_name: t.display_name}
      end

    %{
      id: f.id,
      requester: requester,
      target: target,
      status: f.status,
      inserted_at: f.inserted_at
    }
  end
end
