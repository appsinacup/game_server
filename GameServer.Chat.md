# `GameServer.Chat`

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

# `admin_delete_message`

```elixir
@spec admin_delete_message(integer()) ::
  {:ok, GameServer.Chat.Message.t()} | {:error, term()}
```

Admin: delete a single message by id.

# `cleanup_chat`

```elixir
@spec cleanup_chat(String.t(), integer()) :: :ok
```

Delete all chat data (messages + read cursors) for a given conversation.

# `cleanup_friend_chat`

```elixir
@spec cleanup_friend_chat(integer(), integer()) :: :ok
```

Delete all friend DM messages and read cursors between two users.

Friend messages are stored bidirectionally (each user's messages use
the other's id as chat_ref_id), so both directions must be cleaned up.

# `count_all_messages`

```elixir
@spec count_all_messages(map()) :: non_neg_integer()
```

Count all messages matching filters (admin).

# `count_friend_messages`

```elixir
@spec count_friend_messages(integer(), integer()) :: non_neg_integer()
```

Count total friend DM messages between two users.

# `count_messages`

```elixir
@spec count_messages(String.t(), integer()) :: non_neg_integer()
```

Count total messages in a chat conversation.

# `count_messages_by_type`

```elixir
@spec count_messages_by_type() :: map()
```

Count messages grouped by chat_type.

Returns a map like `%{"lobby" => 10, "group" => 5, "friend" => 3}`.

# `count_unique_senders`

```elixir
@spec count_unique_senders() :: non_neg_integer()
```

Count distinct users who have sent at least one chat message.

# `count_unread`

```elixir
@spec count_unread(integer(), String.t(), integer()) :: non_neg_integer()
```

Count unread messages for a user in a specific chat conversation.

Returns 0 if the user has read all messages or has no cursor (all are unread
in which case `count_messages/2` should be used instead).

# `count_unread_friend`

```elixir
@spec count_unread_friend(integer(), integer()) :: non_neg_integer()
```

Count unread friend DMs between two users for a specific user.

# `count_unread_friends_batch`

```elixir
@spec count_unread_friends_batch(integer(), [integer()]) :: %{
  required(integer()) =&gt; non_neg_integer()
}
```

Count unread friend DMs for a user across all friends.

Returns a map of `%{friend_id => unread_count}` for friends that have
at least one unread message.

# `count_unread_groups_batch`

```elixir
@spec count_unread_groups_batch(integer(), [integer()]) :: %{
  required(integer()) =&gt; non_neg_integer()
}
```

Count unread messages for a user in multiple group chats.

Returns a map of `%{group_id => unread_count}`.

# `delete_messages`

```elixir
@spec delete_messages(String.t(), integer()) :: {non_neg_integer(), nil}
```

Delete all messages for a given chat conversation.

# `delete_own_message`

```elixir
@spec delete_own_message(integer(), integer()) ::
  {:ok, GameServer.Chat.Message.t()} | {:error, term()}
```

Delete a chat message owned by the given user.

Returns `{:error, :not_found}` if the message does not exist or
`{:error, :forbidden}` if the caller is not the sender.

# `delete_read_cursors`

```elixir
@spec delete_read_cursors(String.t(), integer()) :: {non_neg_integer(), nil}
```

Delete all read cursors for a given chat conversation.

# `get_message`

```elixir
@spec get_message(integer()) :: GameServer.Chat.Message.t() | nil
```

Get a single message by id.

# `get_read_cursor`

```elixir
@spec get_read_cursor(integer(), String.t(), integer()) ::
  GameServer.Chat.ReadCursor.t() | nil
```

Get the read cursor for a user in a chat conversation.

Returns `nil` if the user has never opened this conversation.

# `list_all_messages`

```elixir
@spec list_all_messages(
  map(),
  keyword()
) :: [GameServer.Chat.Message.t()]
```

List all messages (admin). Supports filters: sender_id, chat_type, chat_ref_id, content.

# `list_friend_messages`

```elixir
@spec list_friend_messages(integer(), integer(), keyword()) :: [
  GameServer.Chat.Message.t()
]
```

List friend DM messages between two users.

Convenience wrapper that queries messages in both directions.

## Options

  * `:page` — page number (default 1)
  * `:page_size` — items per page (default 25)

# `list_messages`

```elixir
@spec list_messages(String.t(), integer(), keyword()) :: [GameServer.Chat.Message.t()]
```

List messages for a chat conversation.

## Options

  * `:page` — page number (default 1)
  * `:page_size` — items per page (default 25)

Returns a list of `%Message{}` structs ordered by `inserted_at` descending
(newest first).

# `mark_read`

```elixir
@spec mark_read(integer(), String.t(), integer(), integer()) ::
  {:ok, GameServer.Chat.ReadCursor.t()} | {:error, term()}
```

Mark a chat conversation as read up to a given message id.

Uses an upsert to create or update the read cursor.

# `send_message`

```elixir
@spec send_message(map(), map()) ::
  {:ok, GameServer.Chat.Message.t()} | {:error, term()}
```

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

# `subscribe_friend_chat`

```elixir
@spec subscribe_friend_chat(integer(), integer()) :: :ok | {:error, term()}
```

Subscribe to chat events for a friend DM conversation.

# `subscribe_group_chat`

```elixir
@spec subscribe_group_chat(integer()) :: :ok | {:error, term()}
```

Subscribe to chat events for a group.

# `subscribe_lobby_chat`

```elixir
@spec subscribe_lobby_chat(integer()) :: :ok | {:error, term()}
```

Subscribe to chat events for a lobby.

# `subscribe_party_chat`

```elixir
@spec subscribe_party_chat(integer()) :: :ok | {:error, term()}
```

Subscribe to chat events for a party.

# `unsubscribe_friend_chat`

```elixir
@spec unsubscribe_friend_chat(integer(), integer()) :: :ok
```

Unsubscribe from friend DM chat events.

# `unsubscribe_group_chat`

```elixir
@spec unsubscribe_group_chat(integer()) :: :ok
```

Unsubscribe from group chat events.

# `unsubscribe_lobby_chat`

```elixir
@spec unsubscribe_lobby_chat(integer()) :: :ok
```

Unsubscribe from lobby chat events.

# `unsubscribe_party_chat`

```elixir
@spec unsubscribe_party_chat(integer()) :: :ok
```

Unsubscribe from party chat events.

# `update_message`

```elixir
@spec update_message(integer(), integer(), map()) ::
  {:ok, GameServer.Chat.Message.t()} | {:error, term()}
```

Update a chat message owned by the given user.

Only the `content` and `metadata` fields can be changed. Returns
`{:error, :not_found}` if the message does not exist or
`{:error, :forbidden}` if the caller is not the sender.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
