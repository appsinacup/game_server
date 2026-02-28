defmodule GameServer.Chat do
  @moduledoc """
  Context for chat messaging across lobbies, groups, and friend DMs.

  ## Chat types

    * `"lobby"` — messages within a lobby. `chat_ref_id` is the lobby id.
    * `"group"` — messages within a group. `chat_ref_id` is the group id.
    * `"friend"` — direct messages between two friends. `chat_ref_id` is the
      other user's id (each user stores the *other* user's id so queries work
      symmetrically).

  ## PubSub topics

    * `"chat:lobby:<id>"` — lobby chat events
    * `"chat:group:<id>"` — group chat events
    * `"chat:friend:<low>:<high>"` — friend DM events (sorted pair of user ids)

  ## Hooks

    * `before_chat_message/2` — pipeline hook `(user, attrs)` → `{:ok, attrs}` | `{:error, reason}`
    * `after_chat_message/1` — fire-and-forget after a message is persisted
  """

  import Ecto.Query

  use Nebulex.Caching, cache: GameServer.Cache

  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.Chat.Message
  alias GameServer.Chat.ReadCursor
  alias GameServer.Repo

  require Logger

  # ---------------------------------------------------------------------------
  # Cache helpers
  # ---------------------------------------------------------------------------

  @chat_cache_ttl_ms 60_000

  defp chat_version(chat_type, chat_ref_id) do
    GameServer.Cache.get({:chat, :version, chat_type, chat_ref_id}) || 1
  end

  defp invalidate_chat_cache(chat_type, chat_ref_id) do
    GameServer.Async.run(fn ->
      _ = GameServer.Cache.incr({:chat, :version, chat_type, chat_ref_id}, 1, default: 1)
      :ok
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  @doc "Subscribe to chat events for a lobby."
  @spec subscribe_lobby_chat(integer()) :: :ok | {:error, term()}
  def subscribe_lobby_chat(lobby_id),
    do: Phoenix.PubSub.subscribe(GameServer.PubSub, "chat:lobby:#{lobby_id}")

  @doc "Unsubscribe from lobby chat events."
  @spec unsubscribe_lobby_chat(integer()) :: :ok
  def unsubscribe_lobby_chat(lobby_id),
    do: Phoenix.PubSub.unsubscribe(GameServer.PubSub, "chat:lobby:#{lobby_id}")

  @doc "Subscribe to chat events for a group."
  @spec subscribe_group_chat(integer()) :: :ok | {:error, term()}
  def subscribe_group_chat(group_id),
    do: Phoenix.PubSub.subscribe(GameServer.PubSub, "chat:group:#{group_id}")

  @doc "Unsubscribe from group chat events."
  @spec unsubscribe_group_chat(integer()) :: :ok
  def unsubscribe_group_chat(group_id),
    do: Phoenix.PubSub.unsubscribe(GameServer.PubSub, "chat:group:#{group_id}")

  @doc "Subscribe to chat events for a friend DM conversation."
  @spec subscribe_friend_chat(integer(), integer()) :: :ok | {:error, term()}
  def subscribe_friend_chat(user_a_id, user_b_id) do
    {low, high} = friend_pair(user_a_id, user_b_id)
    Phoenix.PubSub.subscribe(GameServer.PubSub, "chat:friend:#{low}:#{high}")
  end

  @doc "Unsubscribe from friend DM chat events."
  @spec unsubscribe_friend_chat(integer(), integer()) :: :ok
  def unsubscribe_friend_chat(user_a_id, user_b_id) do
    {low, high} = friend_pair(user_a_id, user_b_id)
    Phoenix.PubSub.unsubscribe(GameServer.PubSub, "chat:friend:#{low}:#{high}")
  end

  defp broadcast_chat(chat_type, chat_ref_id, sender_id, event) do
    topic = chat_topic(chat_type, chat_ref_id, sender_id)
    Phoenix.PubSub.broadcast(GameServer.PubSub, topic, event)

    # For friend DMs, also broadcast to the recipient's user topic so the
    # UserChannel can forward the message without subscribing to every pair.
    if chat_type == "friend" do
      Phoenix.PubSub.broadcast(GameServer.PubSub, "user:#{chat_ref_id}", event)
    end
  end

  defp chat_topic("lobby", lobby_id, _sender_id), do: "chat:lobby:#{lobby_id}"
  defp chat_topic("group", group_id, _sender_id), do: "chat:group:#{group_id}"

  defp chat_topic("friend", friend_id, sender_id) do
    {low, high} = friend_pair(sender_id, friend_id)
    "chat:friend:#{low}:#{high}"
  end

  defp friend_pair(a, b) when a < b, do: {a, b}
  defp friend_pair(a, b), do: {b, a}

  # ---------------------------------------------------------------------------
  # Send message
  # ---------------------------------------------------------------------------

  @doc """
  Send a chat message.

  ## Parameters

    * `scope` — `%{user: %User{}}` (current_scope)
    * `attrs` — map with `"chat_type"`, `"chat_ref_id"`, `"content"`, optional `"metadata"`

  ## Returns

    * `{:ok, %Message{}}` on success
    * `{:error, reason}` on failure

  The `before_chat_message` hook is called before persistence and can modify
  attrs or reject the message. The `after_chat_message` hook fires asynchronously
  after the message is persisted.
  """
  @spec send_message(map(), map()) ::
          {:ok, Message.t()} | {:error, term()}
  def send_message(%{user: %User{id: sender_id}}, attrs) when is_map(attrs) do
    with :ok <- validate_chat_access(sender_id, attrs),
         {:ok, attrs} <- run_before_hook(sender_id, attrs) do
      do_send_message(sender_id, attrs)
    end
  end

  defp run_before_hook(sender_id, attrs) do
    case Accounts.get_user(sender_id) do
      nil ->
        {:error, :user_not_found}

      user ->
        case GameServer.Hooks.internal_call(:before_chat_message, [user, attrs]) do
          {:ok, attrs} -> {:ok, attrs}
          {:error, reason} -> {:error, {:hook_rejected, reason}}
        end
    end
  end

  defp do_send_message(sender_id, attrs) do
    changeset =
      %Message{sender_id: sender_id}
      |> Message.changeset(attrs)

    case Repo.insert(changeset) do
      {:ok, message} = ok ->
        chat_type = message.chat_type
        chat_ref_id = message.chat_ref_id

        invalidate_chat_cache(chat_type, chat_ref_id)
        broadcast_chat(chat_type, chat_ref_id, sender_id, {:new_chat_message, message})

        GameServer.Async.run(fn ->
          GameServer.Hooks.internal_call(:after_chat_message, [message])
        end)

        ok

      {:error, _changeset} = err ->
        err
    end
  end

  # ---------------------------------------------------------------------------
  # Access validation
  # ---------------------------------------------------------------------------

  defp validate_chat_access(sender_id, %{"chat_type" => "lobby", "chat_ref_id" => lobby_id}) do
    validate_chat_access(sender_id, %{chat_type: "lobby", chat_ref_id: lobby_id})
  end

  defp validate_chat_access(sender_id, %{chat_type: "lobby", chat_ref_id: lobby_id}) do
    case Accounts.get_user(sender_id) do
      %User{lobby_id: ^lobby_id} when lobby_id != nil -> :ok
      _ -> {:error, :not_in_lobby}
    end
  end

  defp validate_chat_access(sender_id, %{"chat_type" => "group", "chat_ref_id" => group_id}) do
    validate_chat_access(sender_id, %{chat_type: "group", chat_ref_id: group_id})
  end

  defp validate_chat_access(sender_id, %{chat_type: "group", chat_ref_id: group_id}) do
    case GameServer.Groups.get_membership(group_id, sender_id) do
      nil -> {:error, :not_in_group}
      _member -> :ok
    end
  end

  defp validate_chat_access(sender_id, %{
         "chat_type" => "friend",
         "chat_ref_id" => friend_id
       }) do
    validate_chat_access(sender_id, %{chat_type: "friend", chat_ref_id: friend_id})
  end

  defp validate_chat_access(sender_id, %{chat_type: "friend", chat_ref_id: friend_id}) do
    cond do
      GameServer.Friends.blocked?(sender_id, friend_id) ->
        {:error, :blocked}

      GameServer.Friends.friends?(sender_id, friend_id) ->
        :ok

      true ->
        {:error, :not_friends}
    end
  end

  defp validate_chat_access(_sender_id, _attrs), do: {:error, :invalid_chat_type}

  # ---------------------------------------------------------------------------
  # List messages (paginated, cached)
  # ---------------------------------------------------------------------------

  @doc """
  List messages for a chat conversation.

  ## Options

    * `:page` — page number (default 1)
    * `:page_size` — items per page (default 25)

  Returns a list of `%Message{}` structs ordered by `inserted_at` descending
  (newest first).
  """
  @spec list_messages(String.t(), integer(), keyword()) :: [Message.t()]
  def list_messages(chat_type, chat_ref_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
    offset = (page - 1) * page_size

    do_list_messages(chat_type, chat_ref_id, page, page_size, offset)
  end

  @decorate cacheable(
              key:
                {:chat, :list, chat_version(chat_type, chat_ref_id), chat_type, chat_ref_id, page,
                 page_size},
              opts: [ttl: @chat_cache_ttl_ms]
            )
  defp do_list_messages(chat_type, chat_ref_id, page, page_size, offset) do
    _ = page

    base_query(chat_type, chat_ref_id)
    |> order_by([m], desc: m.inserted_at, desc: m.id)
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  List friend DM messages between two users.

  Convenience wrapper that queries messages in both directions.

  ## Options

    * `:page` — page number (default 1)
    * `:page_size` — items per page (default 25)
  """
  @spec list_friend_messages(integer(), integer(), keyword()) :: [Message.t()]
  def list_friend_messages(user_a_id, user_b_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
    offset = (page - 1) * page_size

    from(m in Message,
      where:
        (m.chat_type == "friend" and m.sender_id == ^user_a_id and m.chat_ref_id == ^user_b_id) or
          (m.chat_type == "friend" and m.sender_id == ^user_b_id and m.chat_ref_id == ^user_a_id),
      order_by: [desc: m.inserted_at, desc: m.id],
      limit: ^page_size,
      offset: ^offset
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Count helpers
  # ---------------------------------------------------------------------------

  @doc "Count total messages in a chat conversation."
  @spec count_messages(String.t(), integer()) :: non_neg_integer()
  def count_messages(chat_type, chat_ref_id) do
    base_query(chat_type, chat_ref_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc "Count total friend DM messages between two users."
  @spec count_friend_messages(integer(), integer()) :: non_neg_integer()
  def count_friend_messages(user_a_id, user_b_id) do
    from(m in Message,
      where:
        (m.chat_type == "friend" and m.sender_id == ^user_a_id and m.chat_ref_id == ^user_b_id) or
          (m.chat_type == "friend" and m.sender_id == ^user_b_id and m.chat_ref_id == ^user_a_id)
    )
    |> Repo.aggregate(:count, :id)
  end

  defp base_query("friend", _chat_ref_id) do
    # For friend chats, callers should use list_friend_messages/3 instead
    from(m in Message, where: false)
  end

  defp base_query(chat_type, chat_ref_id) do
    from(m in Message,
      where: m.chat_type == ^chat_type and m.chat_ref_id == ^chat_ref_id
    )
  end

  # ---------------------------------------------------------------------------
  # Read cursors
  # ---------------------------------------------------------------------------

  @doc """
  Mark a chat conversation as read up to a given message id.

  Uses an upsert to create or update the read cursor.
  """
  @spec mark_read(integer(), String.t(), integer(), integer()) ::
          {:ok, ReadCursor.t()} | {:error, term()}
  def mark_read(user_id, chat_type, chat_ref_id, message_id) do
    attrs = %{
      chat_type: chat_type,
      chat_ref_id: chat_ref_id,
      last_read_message_id: message_id
    }

    %ReadCursor{user_id: user_id}
    |> ReadCursor.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [last_read_message_id: message_id, updated_at: DateTime.utc_now(:second)]
      ],
      conflict_target: {:unsafe_fragment, "user_id, chat_type, chat_ref_id"}
    )
  end

  @doc """
  Get the read cursor for a user in a chat conversation.

  Returns `nil` if the user has never opened this conversation.
  """
  @spec get_read_cursor(integer(), String.t(), integer()) :: ReadCursor.t() | nil
  def get_read_cursor(user_id, chat_type, chat_ref_id) do
    from(c in ReadCursor,
      where: c.user_id == ^user_id and c.chat_type == ^chat_type and c.chat_ref_id == ^chat_ref_id
    )
    |> Repo.one()
  end

  @doc """
  Count unread messages for a user in a specific chat conversation.

  Returns 0 if the user has read all messages or has no cursor (all are unread
  in which case `count_messages/2` should be used instead).
  """
  @spec count_unread(integer(), String.t(), integer()) :: non_neg_integer()
  def count_unread(user_id, chat_type, chat_ref_id) do
    case get_read_cursor(user_id, chat_type, chat_ref_id) do
      nil ->
        # Never read — all messages are unread
        count_messages(chat_type, chat_ref_id)

      %ReadCursor{last_read_message_id: nil} ->
        count_messages(chat_type, chat_ref_id)

      %ReadCursor{last_read_message_id: last_id} ->
        from(m in Message,
          where:
            m.chat_type == ^chat_type and m.chat_ref_id == ^chat_ref_id and
              m.id > ^last_id
        )
        |> Repo.aggregate(:count, :id)
    end
  end

  @doc """
  Count unread friend DMs between two users for a specific user.
  """
  @spec count_unread_friend(integer(), integer()) :: non_neg_integer()
  def count_unread_friend(user_id, friend_id) do
    cursor = get_read_cursor(user_id, "friend", friend_id)

    query =
      from(m in Message,
        where: m.chat_type == "friend" and m.sender_id == ^friend_id and m.chat_ref_id == ^user_id
      )

    case cursor do
      nil ->
        Repo.aggregate(query, :count, :id)

      %ReadCursor{last_read_message_id: nil} ->
        Repo.aggregate(query, :count, :id)

      %ReadCursor{last_read_message_id: last_id} ->
        from(m in query, where: m.id > ^last_id)
        |> Repo.aggregate(:count, :id)
    end
  end

  # ---------------------------------------------------------------------------
  # Delete helpers (for cleanup / admin)
  # ---------------------------------------------------------------------------

  @doc "Delete all messages for a given chat conversation."
  @spec delete_messages(String.t(), integer()) :: {non_neg_integer(), nil}
  def delete_messages(chat_type, chat_ref_id) do
    result =
      from(m in Message,
        where: m.chat_type == ^chat_type and m.chat_ref_id == ^chat_ref_id
      )
      |> Repo.delete_all()

    invalidate_chat_cache(chat_type, chat_ref_id)
    result
  end

  @doc "Get a single message by id."
  @spec get_message(integer()) :: Message.t() | nil
  def get_message(id) do
    Repo.get(Message, id)
  end

  # ---------------------------------------------------------------------------
  # Admin helpers
  # ---------------------------------------------------------------------------

  @doc "List all messages (admin). Supports filters: sender_id, chat_type, chat_ref_id, content."
  @spec list_all_messages(map(), keyword()) :: [Message.t()]
  def list_all_messages(filters \\ %{}, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
    sort_by = Keyword.get(opts, :sort_by, nil)
    offset = (page - 1) * page_size

    base_admin_query(filters)
    |> admin_sort(sort_by)
    |> limit(^page_size)
    |> offset(^offset)
    |> preload(:sender)
    |> Repo.all()
  end

  @doc "Count all messages matching filters (admin)."
  @spec count_all_messages(map()) :: non_neg_integer()
  def count_all_messages(filters \\ %{}) do
    base_admin_query(filters) |> Repo.aggregate(:count, :id)
  end

  @doc "Admin: delete a single message by id."
  @spec admin_delete_message(integer()) :: {:ok, Message.t()} | {:error, term()}
  def admin_delete_message(id) do
    case Repo.get(Message, id) do
      nil ->
        {:error, :not_found}

      message ->
        result = Repo.delete(message)
        invalidate_chat_cache(message.chat_type, message.chat_ref_id)
        result
    end
  end

  defp base_admin_query(filters) do
    query = from(m in Message)

    query =
      case Map.get(filters, :sender_id) || Map.get(filters, "sender_id") do
        nil -> query
        "" -> query
        v -> where(query, [m], m.sender_id == ^parse_int(v))
      end

    query =
      case Map.get(filters, :chat_type) || Map.get(filters, "chat_type") do
        nil -> query
        "" -> query
        v -> where(query, [m], m.chat_type == ^v)
      end

    query =
      case Map.get(filters, :chat_ref_id) || Map.get(filters, "chat_ref_id") do
        nil -> query
        "" -> query
        v -> where(query, [m], m.chat_ref_id == ^parse_int(v))
      end

    query =
      case Map.get(filters, :content) || Map.get(filters, "content") do
        nil -> query
        "" -> query
        v -> where(query, [m], like(m.content, ^"%#{v}%"))
      end

    query
  end

  defp admin_sort(query, "inserted_at_asc"), do: order_by(query, [m], asc: m.inserted_at)
  defp admin_sort(query, "inserted_at"), do: order_by(query, [m], desc: m.inserted_at)
  defp admin_sort(query, _), do: order_by(query, [m], desc: m.inserted_at)

  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {i, ""} -> i
      _ -> 0
    end
  end

  defp parse_int(_), do: 0
end
