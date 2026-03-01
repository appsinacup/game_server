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

# `delete_messages`

```elixir
@spec delete_messages(String.t(), integer()) :: {non_neg_integer(), nil}
```

Delete all messages for a given chat conversation.

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

---

*Consult [api-reference.md](api-reference.md) for complete listing*
