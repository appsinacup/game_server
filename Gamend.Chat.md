# `Gamend.Chat`
[🔗](https://github.com/appsinacup/gamend/blob/v1.0.7/lib/gamend/chat.ex#L1)

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
@spec admin_delete_message(Ecto.UUID.t()) ::
  {:ok, Gamend.Chat.Message.t()} | {:error, term()}
```

Admin: delete a single message by id.

# `authorize_access`

```elixir
@spec authorize_access(Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
  :ok | {:error, atom()}
```

Returns `:ok` when user can access the chat conversation.

# `cleanup_chat`

```elixir
@spec cleanup_chat(String.t(), Ecto.UUID.t()) :: :ok
```

Delete all chat data (messages + read cursors) for a given conversation.

# `cleanup_friend_chat`

```elixir
@spec cleanup_friend_chat(Ecto.UUID.t(), Ecto.UUID.t()) :: :ok
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
@spec count_friend_messages(String.t(), String.t()) :: non_neg_integer()
```

Count total friend DM messages between two users.

# `count_messages`

```elixir
@spec count_messages(String.t(), Ecto.UUID.t()) :: non_neg_integer()
```

Count total messages in a chat conversation.

# `count_messages_by_type`

```elixir
@spec count_messages_by_type() :: map()
```

Count messages grouped by chat_type.

Returns a map like `%{"lobby" => 10, "group" => 5, "friend" => 3}`.

# `count_mutes`

```elixir
@spec count_mutes(map()) :: non_neg_integer()
```

Count mutes matching `filters`.

# `count_reports`

```elixir
@spec count_reports(map()) :: non_neg_integer()
```

Count reports matching `filters`.

# `count_unique_senders`

```elixir
@spec count_unique_senders() :: non_neg_integer()
```

Count distinct users who have sent at least one chat message.

# `count_unread`

```elixir
@spec count_unread(Ecto.UUID.t(), String.t(), Ecto.UUID.t()) :: non_neg_integer()
```

Count unread messages for a user in a specific chat conversation.

Returns 0 if the user has read all messages or has no cursor (all are unread
in which case `count_messages/2` should be used instead).

# `count_unread_friend`

```elixir
@spec count_unread_friend(Ecto.UUID.t(), Ecto.UUID.t()) :: non_neg_integer()
```

Count unread friend DMs between two users for a specific user.

# `count_unread_friends_batch`

```elixir
@spec count_unread_friends_batch(Ecto.UUID.t(), [Ecto.UUID.t()]) :: %{
  required(Ecto.UUID.t()) =&gt; non_neg_integer()
}
```

Count unread friend DMs for a user across all friends.

Returns a map of `%{friend_id => unread_count}` for friends that have
at least one unread message.

# `count_unread_groups_batch`

```elixir
@spec count_unread_groups_batch(Ecto.UUID.t(), [Ecto.UUID.t()]) :: %{
  required(Ecto.UUID.t()) =&gt; non_neg_integer()
}
```

Count unread messages for a user in multiple group chats.

Returns a map of `%{group_id => unread_count}`.

# `delete_messages`

```elixir
@spec delete_messages(String.t(), Ecto.UUID.t()) :: {non_neg_integer(), nil}
```

Delete all messages for a given chat conversation.

# `delete_own_message`

```elixir
@spec delete_own_message(Ecto.UUID.t(), Ecto.UUID.t()) ::
  {:ok, Gamend.Chat.Message.t()} | {:error, term()}
```

Delete a chat message owned by the given user.

Returns `{:error, :not_found}` if the message does not exist or
`{:error, :forbidden}` if the caller is not the sender.

# `delete_read_cursors`

```elixir
@spec delete_read_cursors(String.t(), Ecto.UUID.t()) :: {non_neg_integer(), nil}
```

Delete all read cursors for a given chat conversation.

# `filter_hits`

```elixir
@spec filter_hits(String.t()) :: [{String.t(), String.t(), String.t()}]
```

Every blocklist entry matching `content`, as `[{word, severity, match_mode}]`.

# `get_message`

```elixir
@spec get_message(Ecto.UUID.t()) :: Gamend.Chat.Message.t() | nil
```

Get a single message by id.

# `get_read_cursor`

```elixir
@spec get_read_cursor(Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
  Gamend.Chat.ReadCursor.t() | nil
```

Get the read cursor for a user in a chat conversation.

Returns `nil` if the user has never opened this conversation.

# `list_all_messages`

```elixir
@spec list_all_messages(map(), keyword()) :: [Gamend.Chat.Message.t()]
```

List all messages (admin). Supports filters: sender_id, chat_type, chat_ref_id, content.

# `list_friend_messages`

```elixir
@spec list_friend_messages(String.t(), String.t(), keyword()) :: [
  Gamend.Chat.Message.t()
]
```

List friend DM messages between two users.

Convenience wrapper that queries messages in both directions.

## Options

  * `:page` — page number (default 1)
  * `:page_size` — items per page (default 25)

# `list_messages`

```elixir
@spec list_messages(String.t(), Ecto.UUID.t(), keyword()) :: [Gamend.Chat.Message.t()]
```

List messages for a chat conversation.

## Options

  * `:page` — page number (default 1)
  * `:page_size` — items per page (default 25)

Returns a list of `%Message{}` structs ordered by `inserted_at` descending
(newest first).

# `list_mutes`

```elixir
@spec list_mutes(map(), keyword()) :: [Gamend.Chat.Mute.t()]
```

List mutes. Filters: `:user_id`, `:scope`, `:scope_ref_id`, `:active`.

# `list_reports`

```elixir
@spec list_reports(map(), keyword()) :: [Gamend.Chat.Report.t()]
```

List reports. Filters: `:status`, `:reported_user_id`, `:reporter_id`.

# `mark_read`

```elixir
@spec mark_read(Ecto.UUID.t(), String.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
  {:ok, Gamend.Chat.ReadCursor.t()} | {:error, term()}
```

Mark a chat conversation as read up to a given message id.

Uses an upsert to create or update the read cursor.

# `mute_user`

```elixir
@spec mute_user(Ecto.UUID.t(), String.t(), Ecto.UUID.t() | nil, map()) ::
  {:ok, Gamend.Chat.Mute.t()} | {:error, term()}
```

Mute `user_id` in `scope` (`"global"`, `"lobby"`, `"group"` or `"party"`).

`scope_ref_id` is the room id, or `nil` for a global mute. `attrs` may carry
`expires_at` (nil means permanent), `reason` and `muted_by`.

# `muted?`

```elixir
@spec muted?(Ecto.UUID.t(), String.t(), Ecto.UUID.t() | nil) :: boolean()
```

Whether `user_id` is currently muted for the given chat.

# `report_message`

```elixir
@spec report_message(Ecto.UUID.t(), Ecto.UUID.t(), String.t() | nil) ::
  {:ok, Gamend.Chat.Report.t()} | {:error, term()}
```

File a report about a message on behalf of `reporter_id`.

# `resolve_report`

```elixir
@spec resolve_report(Gamend.Chat.Report.t() | Ecto.UUID.t(), String.t(), map()) ::
  {:ok, Gamend.Chat.Report.t()} | {:error, term()}
```

Resolve a report: set its status, with an optional note and resolver.

# `review_report`

```elixir
@spec review_report(Gamend.Chat.Report.t() | Ecto.UUID.t()) ::
  {:ok, Gamend.Chat.Report.t()} | {:error, term()}
```

Claim a report for review, moving it from open to reviewing.

# `send_message`

```elixir
@spec send_message(map(), map()) :: {:ok, Gamend.Chat.Message.t()} | {:error, term()}
```

Send a chat message.

## Parameters

  * `scope` — `%{user: %User{}}` (current_scope)
  * `attrs` — map with `"chat_type"`, `"chat_ref_id"`, `"content"`, optional `"metadata"`

## Returns

  * `{:ok, %Message{}}` on success
  * `{:error, reason}` on failure

Moderation runs before the `before_chat_message` hook: a muted sender is
rejected with `{:error, :muted}` and a blocked word with
`{:error, :blocked_content}`, so a plugin never sees a message core already
refused. The hook can then modify attrs or reject the message itself. The
`after_chat_message` hook fires asynchronously after the message is persisted.

# `subscribe_friend_chat`

```elixir
@spec subscribe_friend_chat(Ecto.UUID.t(), Ecto.UUID.t()) :: :ok | {:error, term()}
```

Subscribe to chat events for a friend DM conversation.

# `subscribe_group_chat`

```elixir
@spec subscribe_group_chat(Ecto.UUID.t()) :: :ok | {:error, term()}
```

Subscribe to chat events for a group.

# `subscribe_lobby_chat`

```elixir
@spec subscribe_lobby_chat(Ecto.UUID.t()) :: :ok | {:error, term()}
```

Subscribe to chat events for a lobby.

# `subscribe_party_chat`

```elixir
@spec subscribe_party_chat(Ecto.UUID.t()) :: :ok | {:error, term()}
```

Subscribe to chat events for a party.

# `unmute_user`

```elixir
@spec unmute_user(Ecto.UUID.t(), String.t(), Ecto.UUID.t() | nil) ::
  {:ok, non_neg_integer()}
```

Lift a mute. Returns `{:ok, count}` — 0 when the user was not muted.

# `unsubscribe_friend_chat`

```elixir
@spec unsubscribe_friend_chat(Ecto.UUID.t(), Ecto.UUID.t()) :: :ok
```

Unsubscribe from friend DM chat events.

# `unsubscribe_group_chat`

```elixir
@spec unsubscribe_group_chat(Ecto.UUID.t()) :: :ok
```

Unsubscribe from group chat events.

# `unsubscribe_lobby_chat`

```elixir
@spec unsubscribe_lobby_chat(Ecto.UUID.t()) :: :ok
```

Unsubscribe from lobby chat events.

# `unsubscribe_party_chat`

```elixir
@spec unsubscribe_party_chat(Ecto.UUID.t()) :: :ok
```

Unsubscribe from party chat events.

# `update_message`

```elixir
@spec update_message(Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
  {:ok, Gamend.Chat.Message.t()} | {:error, term()}
```

Update a chat message owned by the given user.

Only the `content` and `metadata` fields can be changed. Returns
`{:error, :not_found}` if the message does not exist or
`{:error, :forbidden}` if the caller is not the sender.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
