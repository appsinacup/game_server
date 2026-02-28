defmodule GameServer.Chat do
  @moduledoc ~S"""
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
  

  **Note:** This is an SDK stub. Calling these functions will raise an error.
  The actual implementation runs on the GameServer.
  """



  @doc ~S"""
    Admin: delete a single message by id.
  """
  @spec admin_delete_message(integer()) :: {:ok, GameServer.Chat.Message.t()} | {:error, term()}
  def admin_delete_message(_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Chat.admin_delete_message/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count all messages matching filters (admin).
  """
  @spec count_all_messages(map()) :: non_neg_integer()
  def count_all_messages(_filters) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Chat.count_all_messages/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count total friend DM messages between two users.
  """
  @spec count_friend_messages(integer(), integer()) :: non_neg_integer()
  def count_friend_messages(_user_a_id, _user_b_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Chat.count_friend_messages/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count total messages in a chat conversation.
  """
  @spec count_messages(String.t(), integer()) :: non_neg_integer()
  def count_messages(_chat_type, _chat_ref_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Chat.count_messages/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count unread messages for a user in a specific chat conversation.
    
    Returns 0 if the user has read all messages or has no cursor (all are unread
    in which case `count_messages/2` should be used instead).
    
  """
  @spec count_unread(integer(), String.t(), integer()) :: non_neg_integer()
  def count_unread(_user_id, _chat_type, _chat_ref_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Chat.count_unread/3 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count unread friend DMs between two users for a specific user.
    
  """
  @spec count_unread_friend(integer(), integer()) :: non_neg_integer()
  def count_unread_friend(_user_id, _friend_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Chat.count_unread_friend/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Delete all messages for a given chat conversation.
  """
  @spec delete_messages(String.t(), integer()) :: {non_neg_integer(), nil}
  def delete_messages(_chat_type, _chat_ref_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Chat.delete_messages/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Get a single message by id.
  """
  @spec get_message(integer()) :: GameServer.Chat.Message.t() | nil
  def get_message(_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.Chat.get_message/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Get the read cursor for a user in a chat conversation.
    
    Returns `nil` if the user has never opened this conversation.
    
  """
  @spec get_read_cursor(integer(), String.t(), integer()) :: GameServer.Chat.ReadCursor.t() | nil
  def get_read_cursor(_user_id, _chat_type, _chat_ref_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.Chat.get_read_cursor/3 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    List all messages (admin). Supports filters: sender_id, chat_type, chat_ref_id, content.
  """
  @spec list_all_messages(
  map(),
  keyword()
) :: [GameServer.Chat.Message.t()]
  def list_all_messages(_filters, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.Chat.list_all_messages/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    List friend DM messages between two users.
    
    Convenience wrapper that queries messages in both directions.
    
    ## Options
    
      * `:page` — page number (default 1)
      * `:page_size` — items per page (default 25)
    
  """
  @spec list_friend_messages(integer(), integer(), keyword()) :: [GameServer.Chat.Message.t()]
  def list_friend_messages(_user_a_id, _user_b_id, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.Chat.list_friend_messages/3 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    List messages for a chat conversation.
    
    ## Options
    
      * `:page` — page number (default 1)
      * `:page_size` — items per page (default 25)
    
    Returns a list of `%Message{}` structs ordered by `inserted_at` descending
    (newest first).
    
  """
  @spec list_messages(String.t(), integer(), keyword()) :: [GameServer.Chat.Message.t()]
  def list_messages(_chat_type, _chat_ref_id, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.Chat.list_messages/3 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Mark a chat conversation as read up to a given message id.
    
    Uses an upsert to create or update the read cursor.
    
  """
  @spec mark_read(integer(), String.t(), integer(), integer()) ::
  {:ok, GameServer.Chat.ReadCursor.t()} | {:error, term()}
  def mark_read(_user_id, _chat_type, _chat_ref_id, _message_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Chat.mark_read/4 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
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
  @spec send_message(map(), map()) :: {:ok, GameServer.Chat.Message.t()} | {:error, term()}
  def send_message(_map, _attrs) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Chat.send_message/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Subscribe to chat events for a friend DM conversation.
  """
  @spec subscribe_friend_chat(integer(), integer()) :: :ok | {:error, term()}
  def subscribe_friend_chat(_user_a_id, _user_b_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.Chat.subscribe_friend_chat/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Subscribe to chat events for a group.
  """
  @spec subscribe_group_chat(integer()) :: :ok | {:error, term()}
  def subscribe_group_chat(_group_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.Chat.subscribe_group_chat/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Subscribe to chat events for a lobby.
  """
  @spec subscribe_lobby_chat(integer()) :: :ok | {:error, term()}
  def subscribe_lobby_chat(_lobby_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.Chat.subscribe_lobby_chat/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Unsubscribe from friend DM chat events.
  """
  @spec unsubscribe_friend_chat(integer(), integer()) :: :ok
  def unsubscribe_friend_chat(_user_a_id, _user_b_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.Chat.unsubscribe_friend_chat/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Unsubscribe from group chat events.
  """
  @spec unsubscribe_group_chat(integer()) :: :ok
  def unsubscribe_group_chat(_group_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.Chat.unsubscribe_group_chat/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Unsubscribe from lobby chat events.
  """
  @spec unsubscribe_lobby_chat(integer()) :: :ok
  def unsubscribe_lobby_chat(_lobby_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.Chat.unsubscribe_lobby_chat/1 is a stub - only available at runtime on GameServer"
    end
  end

end
