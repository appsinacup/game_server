defmodule GameServerWeb.Api.V1.ChatController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Chat
  alias OpenApiSpex.Schema

  tags(["Chat"])

  @message_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Message ID"},
      content: %Schema{type: :string, description: "Message text"},
      metadata: %Schema{type: :object, description: "Arbitrary metadata"},
      sender_id: %Schema{type: :integer, description: "User ID of the sender"},
      chat_type: %Schema{
        type: :string,
        enum: ["lobby", "group", "friend"],
        description: "Type of chat conversation"
      },
      chat_ref_id: %Schema{
        type: :integer,
        description: "Reference ID (lobby_id, group_id, or friend user_id)"
      },
      inserted_at: %Schema{type: :string, format: "date-time"}
    },
    example: %{
      id: 1,
      content: "Hello everyone!",
      metadata: %{},
      sender_id: 42,
      chat_type: "lobby",
      chat_ref_id: 1,
      inserted_at: "2026-01-01T00:00:00Z"
    }
  }

  # ---------------------------------------------------------------------------
  # Send message
  # ---------------------------------------------------------------------------

  operation(:send,
    operation_id: "send_chat_message",
    summary: "Send a chat message",
    description:
      "Send a message to a lobby, group, or friend conversation. Requires authentication and membership/friendship.",
    request_body:
      {"Chat message", "application/json",
       %Schema{
         type: :object,
         required: [:chat_type, :chat_ref_id, :content],
         properties: %{
           chat_type: %Schema{
             type: :string,
             enum: ["lobby", "group", "friend"],
             description: "Type of chat"
           },
           chat_ref_id: %Schema{
             type: :integer,
             description: "Reference ID (lobby_id, group_id, or friend user_id)"
           },
           content: %Schema{type: :string, description: "Message text (1-4096 chars)"},
           metadata: %Schema{type: :object, description: "Optional metadata"}
         }
       }},
    responses: [
      created: {"Message sent", "application/json", @message_schema},
      bad_request: {"Invalid input", "application/json", %Schema{type: :object}},
      forbidden: {"Not allowed", "application/json", %Schema{type: :object}},
      unprocessable_entity:
        {"Validation or hook error", "application/json", %Schema{type: :object}}
    ]
  )

  def send(conn, params) do
    scope = conn.assigns[:current_scope]

    attrs = %{
      "chat_type" => params["chat_type"],
      "chat_ref_id" => parse_int(params["chat_ref_id"]),
      "content" => params["content"],
      "metadata" => params["metadata"] || %{}
    }

    case Chat.send_message(scope, attrs) do
      {:ok, message} ->
        conn |> put_status(:created) |> json(serialize_message(message))

      {:error, :not_in_lobby} ->
        conn |> put_status(:forbidden) |> json(%{error: "not_in_lobby"})

      {:error, :not_in_group} ->
        conn |> put_status(:forbidden) |> json(%{error: "not_in_group"})

      {:error, :not_friends} ->
        conn |> put_status(:forbidden) |> json(%{error: "not_friends"})

      {:error, :blocked} ->
        conn |> put_status(:forbidden) |> json(%{error: "blocked"})

      {:error, :invalid_chat_type} ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_chat_type"})

      {:error, {:hook_rejected, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "hook_rejected", reason: to_string(reason)})

      {:error, %Ecto.Changeset{} = cs} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_error", details: changeset_errors(cs)})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # ---------------------------------------------------------------------------
  # List messages
  # ---------------------------------------------------------------------------

  operation(:index,
    operation_id: "list_chat_messages",
    summary: "List chat messages",
    description:
      "List messages for a lobby, group, or friend conversation. Paginated, newest first.",
    parameters: [
      chat_type: [
        in: :query,
        required: true,
        schema: %Schema{type: :string, enum: ["lobby", "group", "friend"]},
        description: "Type of chat"
      ],
      chat_ref_id: [
        in: :query,
        required: true,
        schema: %Schema{type: :integer},
        description: "Reference ID (lobby_id, group_id, or friend user_id)"
      ],
      page: [
        in: :query,
        schema: %Schema{type: :integer, default: 1},
        description: "Page number"
      ],
      page_size: [
        in: :query,
        schema: %Schema{type: :integer, default: 25},
        description: "Items per page (max 100)"
      ]
    ],
    responses: [
      ok:
        {"Chat messages", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @message_schema},
             meta: %Schema{type: :object}
           }
         }}
    ]
  )

  def index(conn, params) do
    scope = conn.assigns[:current_scope]
    user_id = scope.user.id
    chat_type = params["chat_type"]
    chat_ref_id = parse_int(params["chat_ref_id"])
    page = parse_int(params["page"]) || 1
    page_size = min(parse_int(params["page_size"]) || 25, 100)

    {messages, total_count} =
      if chat_type == "friend" do
        msgs = Chat.list_friend_messages(user_id, chat_ref_id, page: page, page_size: page_size)
        total = Chat.count_friend_messages(user_id, chat_ref_id)
        {msgs, total}
      else
        msgs = Chat.list_messages(chat_type, chat_ref_id, page: page, page_size: page_size)
        total = Chat.count_messages(chat_type, chat_ref_id)
        {msgs, total}
      end

    count = length(messages)

    json(conn, %{
      data: Enum.map(messages, &serialize_message/1),
      meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
    })
  end

  # ---------------------------------------------------------------------------
  # Mark read
  # ---------------------------------------------------------------------------

  operation(:mark_read,
    operation_id: "mark_chat_read",
    summary: "Mark chat as read",
    description: "Update the read cursor for the current user in a chat conversation.",
    request_body:
      {"Read cursor", "application/json",
       %Schema{
         type: :object,
         required: [:chat_type, :chat_ref_id, :message_id],
         properties: %{
           chat_type: %Schema{type: :string, enum: ["lobby", "group", "friend"]},
           chat_ref_id: %Schema{type: :integer},
           message_id: %Schema{type: :integer, description: "Last read message ID"}
         }
       }},
    responses: [
      ok: {"Read cursor updated", "application/json", %Schema{type: :object}},
      unprocessable_entity: {"Error", "application/json", %Schema{type: :object}}
    ]
  )

  def mark_read(conn, params) do
    user_id = conn.assigns[:current_scope].user.id
    chat_type = params["chat_type"]
    chat_ref_id = parse_int(params["chat_ref_id"])
    message_id = parse_int(params["message_id"])

    case Chat.mark_read(user_id, chat_type, chat_ref_id, message_id) do
      {:ok, cursor} ->
        json(conn, %{
          chat_type: cursor.chat_type,
          chat_ref_id: cursor.chat_ref_id,
          last_read_message_id: cursor.last_read_message_id,
          updated_at: cursor.updated_at
        })

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # ---------------------------------------------------------------------------
  # Unread count
  # ---------------------------------------------------------------------------

  operation(:unread,
    operation_id: "chat_unread_count",
    summary: "Get unread message count",
    description: "Get the number of unread messages for the current user in a chat conversation.",
    parameters: [
      chat_type: [
        in: :query,
        required: true,
        schema: %Schema{type: :string, enum: ["lobby", "group", "friend"]}
      ],
      chat_ref_id: [
        in: :query,
        required: true,
        schema: %Schema{type: :integer}
      ]
    ],
    responses: [
      ok:
        {"Unread count", "application/json",
         %Schema{
           type: :object,
           properties: %{
             unread_count: %Schema{type: :integer}
           }
         }}
    ]
  )

  def unread(conn, params) do
    user_id = conn.assigns[:current_scope].user.id
    chat_type = params["chat_type"]
    chat_ref_id = parse_int(params["chat_ref_id"])

    count =
      if chat_type == "friend" do
        Chat.count_unread_friend(user_id, chat_ref_id)
      else
        Chat.count_unread(user_id, chat_type, chat_ref_id)
      end

    json(conn, %{unread_count: count})
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp serialize_message(msg) do
    %{
      id: msg.id,
      content: msg.content,
      metadata: msg.metadata,
      sender_id: msg.sender_id,
      chat_type: msg.chat_type,
      chat_ref_id: msg.chat_ref_id,
      inserted_at: msg.inserted_at
    }
  end

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
