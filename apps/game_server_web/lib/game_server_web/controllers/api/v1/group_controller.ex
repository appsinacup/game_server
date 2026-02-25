defmodule GameServerWeb.Api.V1.GroupController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Groups
  alias OpenApiSpex.Schema

  tags(["Groups"])

  # ---------------------------------------------------------------------------
  # Shared schemas
  # ---------------------------------------------------------------------------

  @group_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Group ID"},
      title: %Schema{type: :string, description: "Display title"},
      description: %Schema{type: :string, description: "Description", nullable: true},
      type: %Schema{
        type: :string,
        enum: ["public", "private", "hidden"],
        description: "Visibility type"
      },
      max_members: %Schema{type: :integer, description: "Maximum number of members"},
      metadata: %Schema{type: :object, description: "Server-managed metadata"},
      creator_id: %Schema{type: :integer, description: "User ID of the creator", nullable: true},
      member_count: %Schema{type: :integer, description: "Current member count"},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    example: %{
      id: 1,
      title: "Awesome Guild",
      description: "A group for awesome players",
      type: "public",
      max_members: 100,
      metadata: %{"lang_tag" => "en"},
      creator_id: 42,
      member_count: 12
    }
  }

  @error_schema %Schema{
    type: :object,
    properties: %{error: %Schema{type: :string}}
  }

  @meta_schema %Schema{
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

  @member_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Membership ID"},
      user_id: %Schema{type: :integer},
      group_id: %Schema{type: :integer},
      role: %Schema{type: :string, enum: ["admin", "member"]},
      display_name: %Schema{type: :string, nullable: true},
      inserted_at: %Schema{type: :string, format: :"date-time"}
    }
  }

  @join_request_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Join request ID"},
      user_id: %Schema{type: :integer},
      group_id: %Schema{type: :integer},
      status: %Schema{type: :string, enum: ["pending", "accepted", "rejected"]},
      display_name: %Schema{type: :string, nullable: true},
      inserted_at: %Schema{type: :string, format: :"date-time"}
    }
  }

  @invitation_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Notification ID"},
      group_id: %Schema{type: :integer},
      group_name: %Schema{type: :string},
      sender_id: %Schema{type: :integer},
      inserted_at: %Schema{type: :string, format: :"date-time"}
    }
  }

  # ---------------------------------------------------------------------------
  # Operations
  # ---------------------------------------------------------------------------

  operation(:index,
    operation_id: "list_groups",
    summary: "List groups",
    description:
      "Return all non-hidden groups. Supports filtering by title, type, max_members, and metadata.",
    parameters: [
      title: [
        in: :query,
        schema: %Schema{type: :string},
        description: "Search by title (prefix)"
      ],
      type: [
        in: :query,
        schema: %Schema{type: :string, enum: ["public", "private"]},
        description: "Filter by group type"
      ],
      min_members: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Minimum max_members to include"
      ],
      max_members: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Maximum max_members to include"
      ],
      metadata_key: [
        in: :query,
        schema: %Schema{type: :string},
        description: "Metadata key to filter by"
      ],
      metadata_value: [
        in: :query,
        schema: %Schema{type: :string},
        description: "Metadata value to match (with metadata_key)"
      ],
      page: [in: :query, schema: %Schema{type: :integer}, description: "Page number"],
      page_size: [in: :query, schema: %Schema{type: :integer}, description: "Page size"]
    ],
    responses: [
      ok:
        {"List of groups", "application/json",
         %Schema{
           type: :object,
           properties: %{data: %Schema{type: :array, items: @group_schema}, meta: @meta_schema}
         }}
    ]
  )

  operation(:show,
    operation_id: "get_group",
    summary: "Get group details",
    description: "Get a single group by ID including member count.",
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true]
    ],
    responses: [
      ok: {"Group details", "application/json", @group_schema},
      not_found: {"Group not found", "application/json", @error_schema}
    ]
  )

  operation(:create,
    operation_id: "create_group",
    summary: "Create a group",
    description:
      "Create a new group. The authenticated user becomes an admin member automatically.",
    security: [%{"authorization" => []}],
    request_body: {
      "Group creation parameters",
      "application/json",
      %Schema{
        type: :object,
        required: [:title],
        properties: %{
          title: %Schema{type: :string, description: "Display title (unique)"},
          description: %Schema{type: :string, description: "Optional description"},
          type: %Schema{
            type: :string,
            enum: ["public", "private", "hidden"],
            default: "public"
          },
          max_members: %Schema{type: :integer, description: "Max members (default: 100)"},
          metadata: %Schema{type: :object, description: "Server metadata"}
        },
        example: %{title: "My Guild", type: "public", max_members: 50}
      }
    },
    responses: [
      created: {"Group created", "application/json", @group_schema},
      conflict: {"Title taken or validation error", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:update,
    operation_id: "update_group",
    summary: "Update a group (admin only)",
    description:
      "Update group settings. Only group admins can update. Cannot reduce max_members below current member count.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true]
    ],
    request_body: {
      "Group update parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          title: %Schema{type: :string},
          description: %Schema{type: :string},
          type: %Schema{type: :string, enum: ["public", "private", "hidden"]},
          max_members: %Schema{type: :integer},
          metadata: %Schema{type: :object}
        }
      }
    },
    responses: [
      ok: {"Group updated", "application/json", @group_schema},
      forbidden: {"Not an admin", "application/json", @error_schema},
      unprocessable_entity: {"Validation error", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:join,
    operation_id: "join_group",
    summary: "Join a group",
    description:
      "Join a group. For public groups the user is added immediately. " <>
        "For private groups a join request is created (an admin must approve it). " <>
        "Hidden groups require an invite and cannot be joined directly.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true]
    ],
    responses: [
      ok: {"Joined successfully (public group)", "application/json", @member_schema},
      created: {"Join request created (private group)", "application/json", @join_request_schema},
      forbidden:
        {"Cannot join (full, hidden, already member, already requested)", "application/json",
         @error_schema},
      not_found: {"Group not found", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:leave,
    operation_id: "leave_group",
    summary: "Leave a group",
    description: "Leave a group you are a member of.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true]
    ],
    responses: [
      ok: {"Left successfully", "application/json", %Schema{type: :object}},
      bad_request: {"Not a member", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:kick,
    operation_id: "kick_group_member",
    summary: "Kick a member (admin only)",
    description: "Remove a member from the group. Only group admins can kick.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true]
    ],
    request_body: {
      "Kick parameters",
      "application/json",
      %Schema{
        type: :object,
        required: [:target_user_id],
        properties: %{
          target_user_id: %Schema{type: :integer, description: "User ID to kick"}
        },
        example: %{target_user_id: 123}
      }
    },
    responses: [
      ok: {"User kicked", "application/json", %Schema{type: :object}},
      forbidden: {"Not admin or cannot kick", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:members,
    operation_id: "list_group_members",
    summary: "List group members",
    description: "Get paginated members of a group with their roles.",
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true],
      page: [in: :query, schema: %Schema{type: :integer}, description: "Page number (default: 1)"],
      page_size: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Items per page (default: 25)"
      ]
    ],
    responses: [
      ok:
        {"Members list", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @member_schema},
             meta: @meta_schema
           }
         }},
      not_found: {"Group not found", "application/json", @error_schema}
    ]
  )

  operation(:promote,
    operation_id: "promote_group_member",
    summary: "Promote member to admin",
    description: "Promote a member to admin role. Only admins can promote.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true]
    ],
    request_body: {
      "Promote parameters",
      "application/json",
      %Schema{
        type: :object,
        required: [:target_user_id],
        properties: %{
          target_user_id: %Schema{type: :integer, description: "User ID to promote"}
        }
      }
    },
    responses: [
      ok: {"Member promoted", "application/json", @member_schema},
      forbidden: {"Not admin", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:demote,
    operation_id: "demote_group_member",
    summary: "Demote admin to member",
    description: "Demote an admin to regular member. Only admins can demote.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true]
    ],
    request_body: {
      "Demote parameters",
      "application/json",
      %Schema{
        type: :object,
        required: [:target_user_id],
        properties: %{
          target_user_id: %Schema{type: :integer, description: "User ID to demote"}
        }
      }
    },
    responses: [
      ok: {"Member demoted", "application/json", @member_schema},
      forbidden: {"Not admin", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:join_requests,
    operation_id: "list_join_requests",
    summary: "List pending join requests (admin only)",
    description: "List pending join requests for a group. Only group admins can view.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true],
      page: [in: :query, schema: %Schema{type: :integer}, description: "Page number"],
      page_size: [in: :query, schema: %Schema{type: :integer}, description: "Page size"]
    ],
    responses: [
      ok:
        {"Join requests", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @join_request_schema},
             meta: @meta_schema
           }
         }},
      forbidden: {"Not admin", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:approve_request,
    operation_id: "approve_join_request",
    summary: "Approve a join request (admin only)",
    description: "Approve a pending join request. The user becomes a member.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true],
      request_id: [
        in: :path,
        schema: %Schema{type: :integer},
        description: "Join request ID",
        required: true
      ]
    ],
    responses: [
      ok: {"Request approved", "application/json", @member_schema},
      forbidden: {"Not admin or group full", "application/json", @error_schema},
      not_found: {"Request not found", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:reject_request,
    operation_id: "reject_join_request",
    summary: "Reject a join request (admin only)",
    description: "Reject a pending join request.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true],
      request_id: [
        in: :path,
        schema: %Schema{type: :integer},
        description: "Join request ID",
        required: true
      ]
    ],
    responses: [
      ok: {"Request rejected", "application/json", @join_request_schema},
      forbidden: {"Not admin", "application/json", @error_schema},
      not_found: {"Request not found", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:cancel_request,
    operation_id: "cancel_join_request",
    summary: "Cancel your own pending join request",
    description: "Cancel a join request that the current user previously sent.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true],
      request_id: [
        in: :path,
        schema: %Schema{type: :integer},
        description: "Join request ID",
        required: true
      ]
    ],
    responses: [
      ok: {"Request cancelled", "application/json", @join_request_schema},
      forbidden: {"Not owner or not pending", "application/json", @error_schema},
      not_found: {"Request not found", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:invite,
    operation_id: "invite_to_group",
    summary: "Invite a user to a hidden group (admin only)",
    description:
      "Send an invitation notification to a user for a hidden group. The user can then accept it.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true]
    ],
    request_body: {
      "Invite parameters",
      "application/json",
      %Schema{
        type: :object,
        required: [:target_user_id],
        properties: %{
          target_user_id: %Schema{type: :integer, description: "User ID to invite"}
        }
      }
    },
    responses: [
      ok: {"Invitation sent", "application/json", %Schema{type: :object}},
      forbidden: {"Not admin or target already member", "application/json", @error_schema},
      not_found: {"Group not found", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:accept_invite,
    operation_id: "accept_group_invite",
    summary: "Accept a group invitation",
    description: "Accept an invitation to join a hidden group.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, description: "Group ID", required: true]
    ],
    responses: [
      ok: {"Joined successfully", "application/json", @member_schema},
      forbidden:
        {"Cannot join (full, not hidden, already member)", "application/json", @error_schema},
      not_found: {"Group not found", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:invitations,
    operation_id: "list_group_invitations",
    summary: "List my group invitations",
    description: "List pending group invitations for the authenticated user, with pagination.",
    security: [%{"authorization" => []}],
    parameters: [
      page: [in: :query, schema: %Schema{type: :integer}, description: "Page number (default: 1)"],
      page_size: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Items per page (default: 25)"
      ]
    ],
    responses: [
      ok:
        {"Invitations list", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @invitation_schema},
             meta: @meta_schema
           }
         }},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:my_groups,
    operation_id: "list_my_groups",
    summary: "List groups I belong to",
    description: "List groups the authenticated user is a member of, with pagination.",
    security: [%{"authorization" => []}],
    parameters: [
      page: [in: :query, schema: %Schema{type: :integer}, description: "Page number (default: 1)"],
      page_size: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Items per page (default: 25)"
      ]
    ],
    responses: [
      ok:
        {"My groups", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @group_schema},
             meta: @meta_schema
           }
         }},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:sent_invitations,
    operation_id: "list_sent_invitations",
    summary: "List group invitations I have sent",
    description: "List group invitations sent by the authenticated user, with pagination.",
    security: [%{"authorization" => []}],
    parameters: [
      page: [in: :query, schema: %Schema{type: :integer}, description: "Page number (default: 1)"],
      page_size: [
        in: :query,
        schema: %Schema{type: :integer},
        description: "Items per page (default: 25)"
      ]
    ],
    responses: [
      ok:
        {"Sent invitations list", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{
               type: :array,
               items: %Schema{
                 type: :object,
                 properties: %{
                   id: %Schema{type: :integer},
                   group_id: %Schema{type: :integer},
                   group_name: %Schema{type: :string},
                   sender_id: %Schema{type: :integer},
                   recipient_id: %Schema{type: :integer},
                   recipient_name: %Schema{type: :string, nullable: true},
                   inserted_at: %Schema{type: :string, format: :"date-time"}
                 }
               }
             },
             meta: @meta_schema
           }
         }},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:cancel_invite,
    operation_id: "cancel_group_invite",
    summary: "Cancel a sent group invitation",
    description: "Cancel (delete) a group invitation that the authenticated user sent.",
    security: [%{"authorization" => []}],
    parameters: [
      invite_id: [
        in: :path,
        type: :integer,
        description: "Notification ID of the invitation to cancel",
        required: true
      ]
    ],
    responses: [
      ok:
        {"Invitation cancelled", "application/json",
         %Schema{
           type: :object,
           properties: %{status: %Schema{type: :string}}
         }},
      forbidden: {"Not allowed", "application/json", @error_schema},
      not_found: {"Invitation not found", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  operation(:notify_group,
    operation_id: "notify_group",
    summary: "Send a notification to all group members",
    description:
      "Broadcasts a notification to every member of the group (except the sender). " <>
        "Any group member can send. Sending again from the same user with the same title " <>
        "replaces the previous notification (upsert, prevents spam).",
    security: [%{"authorization" => []}],
    parameters: [
      id: [
        in: :path,
        type: :integer,
        description: "Group ID",
        required: true
      ]
    ],
    request_body:
      {"Notification payload", "application/json",
       %Schema{
         type: :object,
         required: [:content],
         properties: %{
           content: %Schema{type: :string, description: "Notification message text"},
           title: %Schema{
             type: :string,
             description:
               "Notification title (default: \"group_notification\"). " <>
                 "Different titles create separate notification slots per sender/recipient."
           },
           metadata: %Schema{
             type: :object,
             description:
               "Optional extra metadata (group_id and group_name are added automatically)",
             additionalProperties: true
           }
         }
       }},
    responses: [
      ok:
        {"Notifications sent", "application/json",
         %Schema{
           type: :object,
           properties: %{
             sent: %Schema{type: :integer, description: "Number of notifications delivered"}
           }
         }},
      forbidden: {"Not a member", "application/json", @error_schema},
      not_found: {"Group not found", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  # ---------------------------------------------------------------------------
  # Actions
  # ---------------------------------------------------------------------------

  def index(conn, params) do
    filters =
      %{}
      |> maybe_put_string_filter(:title, param_value(params, "title", :title))
      |> maybe_put_string_filter(:type, param_value(params, "type", :type))
      |> maybe_put_int_filter(:min_members, param_value(params, "min_members", :min_members))
      |> maybe_put_int_filter(:max_members, param_value(params, "max_members", :max_members))
      |> maybe_put_string_filter(
        :metadata_key,
        param_value(params, "metadata_key", :metadata_key)
      )
      |> maybe_put_string_filter(
        :metadata_value,
        param_value(params, "metadata_value", :metadata_value)
      )

    {page, page_size} = parse_page_params(params)
    sort_by = Map.get(params, "sort_by")

    groups =
      Groups.list_groups(filters,
        page: page,
        page_size: page_size,
        sort_by: sort_by
      )

    serialized = Enum.map(groups, &serialize_group/1)
    count = length(serialized)
    total_count = Groups.count_list_groups(filters)

    json(conn, %{
      data: serialized,
      meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
    })
  end

  def show(conn, %{"id" => id}) do
    case parse_id(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      group_id ->
        case Groups.get_group(group_id) do
          nil -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
          group -> json(conn, serialize_group(group))
        end
    end
  end

  def create(conn, params) do
    with_auth(conn, fn user ->
      case Groups.create_group(user.id, params) do
        {:ok, group} ->
          conn |> put_status(:created) |> json(serialize_group(group))

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:conflict)
          |> json(%{error: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)})

        {:error, reason} when is_atom(reason) ->
          conn |> put_status(:conflict) |> json(%{error: to_string(reason)})
      end
    end)
  end

  def update(conn, %{"id" => id} = params) do
    with_auth(conn, fn user ->
      case parse_id(id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        group_id ->
          case Groups.update_group(user.id, group_id, params) do
            {:ok, group} ->
              json(conn, serialize_group(group))

            {:error, :not_admin} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_admin"})

            {:error, :max_members_too_low} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "max_members_too_low"})

            {:error, %Ecto.Changeset{} = changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{
                error: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
              })

            {:error, reason} when is_atom(reason) ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  def join(conn, %{"id" => id}) do
    with_auth(conn, fn user ->
      case parse_id(id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        group_id ->
          group = Groups.get_group(group_id)
          do_join(conn, user, group, group_id)
      end
    end)
  end

  defp do_join(conn, _user, nil, _group_id) do
    conn |> put_status(:not_found) |> json(%{error: "not_found"})
  end

  defp do_join(conn, user, %{type: "public"} = _group, group_id) do
    case Groups.join_group(user.id, group_id) do
      {:ok, member} ->
        json(conn, serialize_member(member))

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      {:error, reason} ->
        conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
    end
  end

  defp do_join(conn, user, %{type: "private"} = _group, group_id) do
    case Groups.request_join(user.id, group_id) do
      {:ok, request} ->
        conn |> put_status(:created) |> json(serialize_join_request(request))

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      {:error, reason} ->
        conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
    end
  end

  defp do_join(conn, _user, _group, _group_id) do
    # hidden groups require an invite
    conn |> put_status(:forbidden) |> json(%{error: "not_joinable"})
  end

  def leave(conn, %{"id" => id}) do
    with_auth(conn, fn user ->
      case parse_id(id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        group_id ->
          case Groups.leave_group(user.id, group_id) do
            {:ok, _} ->
              json(conn, %{})

            {:error, :not_member} ->
              conn |> put_status(:bad_request) |> json(%{error: "not_member"})

            {:error, reason} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  def kick(conn, %{"id" => id} = params) do
    with_auth(conn, fn user ->
      target_user_id = Map.get(params, "target_user_id") || Map.get(params, :target_user_id)

      case {parse_id(id), parse_id(target_user_id)} do
        {nil, _} ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        {_, nil} ->
          conn |> put_status(:bad_request) |> json(%{error: "missing_target_user_id"})

        {group_id, tid} ->
          case Groups.kick_member(user.id, group_id, tid) do
            {:ok, _} ->
              json(conn, %{})

            {:error, :not_admin} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_admin"})

            {:error, :cannot_kick_self} ->
              conn |> put_status(:forbidden) |> json(%{error: "cannot_kick_self"})

            {:error, :not_member} ->
              conn |> put_status(:not_found) |> json(%{error: "not_member"})

            {:error, reason} ->
              conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  def members(conn, %{"id" => id} = params) do
    case parse_id(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      group_id ->
        case Groups.get_group(group_id) do
          nil ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})

          _group ->
            {page, page_size} = parse_page_params(params)

            members =
              Groups.get_group_members_paginated(group_id, page: page, page_size: page_size)

            serialized = Enum.map(members, &serialize_member/1)
            count = length(serialized)
            total_count = Groups.count_group_members(group_id)

            json(conn, %{
              data: serialized,
              meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
            })
        end
    end
  end

  def promote(conn, %{"id" => id} = params) do
    with_auth(conn, fn user ->
      target_user_id = Map.get(params, "target_user_id") || Map.get(params, :target_user_id)

      case {parse_id(id), parse_id(target_user_id)} do
        {nil, _} ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        {_, nil} ->
          conn |> put_status(:bad_request) |> json(%{error: "missing_target_user_id"})

        {group_id, tid} ->
          case Groups.promote_member(user.id, group_id, tid) do
            {:ok, member} ->
              json(conn, serialize_member(member))

            {:error, :not_admin} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_admin"})

            {:error, :cannot_promote_self} ->
              conn |> put_status(:forbidden) |> json(%{error: "cannot_promote_self"})

            {:error, :not_member} ->
              conn |> put_status(:not_found) |> json(%{error: "not_member"})

            {:error, :already_admin} ->
              conn |> put_status(:forbidden) |> json(%{error: "already_admin"})

            {:error, reason} ->
              conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  def demote(conn, %{"id" => id} = params) do
    with_auth(conn, fn user ->
      target_user_id = Map.get(params, "target_user_id") || Map.get(params, :target_user_id)

      case {parse_id(id), parse_id(target_user_id)} do
        {nil, _} ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        {_, nil} ->
          conn |> put_status(:bad_request) |> json(%{error: "missing_target_user_id"})

        {group_id, tid} ->
          case Groups.demote_member(user.id, group_id, tid) do
            {:ok, member} ->
              json(conn, serialize_member(member))

            {:error, :not_admin} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_admin"})

            {:error, :cannot_demote_self} ->
              conn |> put_status(:forbidden) |> json(%{error: "cannot_demote_self"})

            {:error, :not_member} ->
              conn |> put_status(:not_found) |> json(%{error: "not_member"})

            {:error, :already_member} ->
              conn |> put_status(:forbidden) |> json(%{error: "already_member"})

            {:error, reason} ->
              conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  def join_requests(conn, %{"id" => id} = params) do
    with_auth(conn, fn user ->
      case parse_id(id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        group_id ->
          {page, page_size} = parse_page_params(params)

          case Groups.list_join_requests(user.id, group_id, page: page, page_size: page_size) do
            {:ok, requests} ->
              serialized = Enum.map(requests, &serialize_join_request/1)
              count = length(serialized)
              total_count = Groups.count_join_requests(group_id)

              json(conn, %{
                data: serialized,
                meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
              })

            {:error, :not_admin} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_admin"})
          end
      end
    end)
  end

  def approve_request(conn, %{"id" => _id, "request_id" => request_id}) do
    with_auth(conn, fn user ->
      case parse_id(request_id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        rid ->
          case Groups.approve_join_request(user.id, rid) do
            {:ok, member} ->
              json(conn, serialize_member(member))

            {:error, :not_found} ->
              conn |> put_status(:not_found) |> json(%{error: "not_found"})

            {:error, :not_pending} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_pending"})

            {:error, :not_admin} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_admin"})

            {:error, :full} ->
              conn |> put_status(:forbidden) |> json(%{error: "full"})

            {:error, reason} when is_atom(reason) ->
              conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})

            {:error, reason} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  def reject_request(conn, %{"id" => _id, "request_id" => request_id}) do
    with_auth(conn, fn user ->
      case parse_id(request_id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        rid ->
          case Groups.reject_join_request(user.id, rid) do
            {:ok, request} ->
              json(conn, serialize_join_request(request))

            {:error, :not_found} ->
              conn |> put_status(:not_found) |> json(%{error: "not_found"})

            {:error, :not_pending} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_pending"})

            {:error, :not_admin} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_admin"})

            {:error, reason} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  def cancel_request(conn, %{"id" => _id, "request_id" => request_id}) do
    with_auth(conn, fn user ->
      case parse_id(request_id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        rid ->
          case Groups.cancel_join_request(user.id, rid) do
            {:ok, request} ->
              json(conn, serialize_join_request(request))

            {:error, :not_found} ->
              conn |> put_status(:not_found) |> json(%{error: "not_found"})

            {:error, :not_pending} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_pending"})

            {:error, :not_owner} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_owner"})

            {:error, reason} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  def invite(conn, %{"id" => id} = params) do
    with_auth(conn, fn user ->
      target_user_id = Map.get(params, "target_user_id") || Map.get(params, :target_user_id)

      case {parse_id(id), parse_id(target_user_id)} do
        {nil, _} ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        {_, nil} ->
          conn |> put_status(:bad_request) |> json(%{error: "missing_target_user_id"})

        {group_id, tid} ->
          case Groups.invite_to_group(user.id, group_id, tid) do
            {:ok, _} ->
              json(conn, %{})

            {:error, :not_found} ->
              conn |> put_status(:not_found) |> json(%{error: "not_found"})

            {:error, :not_admin} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_admin"})

            {:error, :already_member} ->
              conn |> put_status(:forbidden) |> json(%{error: "already_member"})

            {:error, :blocked} ->
              conn |> put_status(:forbidden) |> json(%{error: "blocked"})

            {:error, reason} ->
              conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  def accept_invite(conn, %{"id" => id}) do
    with_auth(conn, fn user ->
      case parse_id(id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        group_id ->
          case Groups.accept_invite(user.id, group_id) do
            {:ok, member} ->
              json(conn, serialize_member(member))

            {:error, :not_found} ->
              conn |> put_status(:not_found) |> json(%{error: "not_found"})

            {:error, :not_hidden} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_hidden"})

            {:error, :already_member} ->
              conn |> put_status(:forbidden) |> json(%{error: "already_member"})

            {:error, :full} ->
              conn |> put_status(:forbidden) |> json(%{error: "full"})

            {:error, reason} ->
              conn |> put_status(:forbidden) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  def invitations(conn, params) do
    with_auth(conn, fn user ->
      {page, page_size} = parse_page_params(params)
      invites = Groups.list_invitations(user.id, page: page, page_size: page_size)
      count = length(invites)
      total_count = Groups.count_invitations(user.id)

      json(conn, %{
        data: invites,
        meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
      })
    end)
  end

  def my_groups(conn, params) do
    with_auth(conn, fn user ->
      {page, page_size} = parse_page_params(params)
      groups = Groups.list_user_groups(user.id, page: page, page_size: page_size)
      serialized = Enum.map(groups, &serialize_group/1)
      count = length(serialized)
      total_count = Groups.count_user_groups(user.id)

      json(conn, %{
        data: serialized,
        meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
      })
    end)
  end

  def sent_invitations(conn, params) do
    with_auth(conn, fn user ->
      {page, page_size} = parse_page_params(params)
      invites = Groups.list_sent_invitations(user.id, page: page, page_size: page_size)
      count = length(invites)
      total_count = Groups.count_sent_invitations(user.id)

      json(conn, %{
        data: invites,
        meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
      })
    end)
  end

  def cancel_invite(conn, %{"invite_id" => invite_id}) do
    with_auth(conn, fn user ->
      case parse_id(invite_id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        iid ->
          case Groups.cancel_invite(user.id, iid) do
            :ok ->
              json(conn, %{status: "cancelled"})

            {:error, :not_found} ->
              conn |> put_status(:not_found) |> json(%{error: "not_found"})

            {:error, :not_owner} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_owner"})
          end
      end
    end)
  end

  def notify_group(conn, %{"id" => id} = params) do
    with_auth(conn, fn user ->
      case parse_id(id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        group_id ->
          content = Map.get(params, "content") || Map.get(params, :content) || ""
          title = Map.get(params, "title") || Map.get(params, :title)
          extra_metadata = Map.get(params, "metadata") || Map.get(params, :metadata) || %{}

          # Pass the title through metadata so the domain function can extract it
          metadata =
            if title do
              Map.put(extra_metadata, "title", title)
            else
              extra_metadata
            end

          case Groups.notify_group(user.id, group_id, content, metadata) do
            {:ok, sent} ->
              json(conn, %{sent: sent})

            {:error, :not_found} ->
              conn |> put_status(:not_found) |> json(%{error: "not_found"})

            {:error, :not_member} ->
              conn |> put_status(:forbidden) |> json(%{error: "not_member"})

            {:error, reason} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
          end
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp with_auth(conn, fun) do
    case conn.assigns[:current_scope] do
      %{user: user} when is_map(user) -> fun.(user)
      _ -> conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  defp serialize_group(group) do
    member_count = Groups.count_group_members(group.id)

    %{
      id: group.id,
      title: group.title,
      description: group.description,
      type: group.type,
      max_members: group.max_members,
      metadata: group.metadata || %{},
      creator_id: group.creator_id,
      member_count: member_count,
      inserted_at: group.inserted_at,
      updated_at: group.updated_at
    }
  end

  defp serialize_member(member) do
    display_name =
      if Ecto.assoc_loaded?(member.user) and member.user do
        member.user.display_name
      else
        nil
      end

    %{
      id: member.id,
      user_id: member.user_id,
      group_id: member.group_id,
      role: member.role,
      display_name: display_name,
      inserted_at: member.inserted_at
    }
  end

  defp serialize_join_request(request) do
    display_name =
      if Ecto.assoc_loaded?(request.user) and request.user do
        request.user.display_name
      else
        nil
      end

    %{
      id: request.id,
      user_id: request.user_id,
      group_id: request.group_id,
      status: request.status,
      display_name: display_name,
      inserted_at: request.inserted_at
    }
  end

  defp parse_id(nil), do: nil

  defp parse_id(id) when is_integer(id), do: id

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {i, ""} -> i
      _ -> nil
    end
  end

  defp parse_page_params(params) do
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

    {page, page_size}
  end

  defp param_value(params, string_key, atom_key) when is_map(params) do
    Map.get(params, string_key) || Map.get(params, atom_key)
  end

  defp maybe_put_string_filter(filters, _key, nil), do: filters
  defp maybe_put_string_filter(filters, _key, ""), do: filters
  defp maybe_put_string_filter(filters, key, v) when is_binary(v), do: Map.put(filters, key, v)
  defp maybe_put_string_filter(filters, _key, _v), do: filters

  defp maybe_put_int_filter(filters, _key, nil), do: filters

  defp maybe_put_int_filter(filters, key, v) when is_binary(v) do
    case Integer.parse(v) do
      {i, _} -> Map.put(filters, key, i)
      _ -> filters
    end
  end

  defp maybe_put_int_filter(filters, key, v) when is_integer(v), do: Map.put(filters, key, v)
  defp maybe_put_int_filter(filters, _key, _v), do: filters
end
