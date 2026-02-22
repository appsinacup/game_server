# `GameServer.Notifications`

Notifications context – create, list, and delete persisted user-to-user
notifications.

Notifications can only be sent to accepted friends. They are stored in the
database so that recipients receive them even when offline. On WebSocket
connect the client gets all undeleted notifications (ordered by timestamp).
New notifications are also pushed in real-time via PubSub.

## PubSub Events

This module broadcasts to the `"notifications:user:<user_id>"` topic:

- `{:new_notification, notification}` – a new notification was created

## Usage

    # Send a notification to a friend
    {:ok, notification} = Notifications.send_notification(sender_id, %{
      "user_id" => recipient_id,
      "title" => "Game invite",
      "content" => "Join my lobby!",
      "metadata" => %{"lobby_id" => 42}
    })

    # List all notifications for a user (ordered oldest-first)
    notifications = Notifications.list_notifications(user_id)

    # Delete notifications by IDs (only owner can delete)
    {deleted_count, nil} = Notifications.delete_notifications(user_id, [1, 2, 3])

    # Count notifications for a user
    count = Notifications.count_notifications(user_id)

# `user_id`

```elixir
@type user_id() :: integer()
```

# `admin_create_notification`

```elixir
@spec admin_create_notification(user_id(), user_id(), map()) ::
  {:ok, GameServer.Notifications.Notification.t()}
  | {:error, Ecto.Changeset.t() | atom()}
```

Admin: create a notification from any sender to any recipient (no friendship check).

# `admin_delete_notification`

```elixir
@spec admin_delete_notification(integer()) ::
  {:ok, GameServer.Notifications.Notification.t()} | {:error, term()}
```

Admin: delete a single notification by ID (no ownership check).

# `count_all_notifications`

```elixir
@spec count_all_notifications(map()) :: non_neg_integer()
```

Count all notifications matching the given filters (admin).

# `count_notifications`

```elixir
@spec count_notifications(user_id()) :: non_neg_integer()
```

Count total notifications for a user.

# `delete_notifications`

```elixir
@spec delete_notifications(user_id(), [integer()]) :: {non_neg_integer(), nil}
```

Delete notifications by IDs, scoped to the recipient (owner).

Only notifications belonging to `user_id` will be deleted.
Returns `{deleted_count, nil}`.

# `get_notification`

```elixir
@spec get_notification(integer()) :: GameServer.Notifications.Notification.t() | nil
```

Get a single notification by ID.

# `get_notification!`

```elixir
@spec get_notification!(integer()) :: GameServer.Notifications.Notification.t()
```

Get a single notification by ID (raises if not found).

# `invalidate_notifications_cache`

Invalidate the notifications cache for a user (async).

# `list_all_notifications`

```elixir
@spec list_all_notifications(
  map(),
  keyword()
) :: [GameServer.Notifications.Notification.t()]
```

List all notifications (admin), with optional filters.

## Filters (map with string keys)

- `"recipient_id"` / `"user_id"` – filter by recipient user ID
- `"sender_id"` – filter by sender user ID
- `"title"` – partial (LIKE) match on title

## Options

- `:page` – page number (default 1)
- `:page_size` – results per page (default 25)

# `list_notifications`

```elixir
@spec list_notifications(
  user_id(),
  keyword()
) :: [GameServer.Notifications.Notification.t()]
```

List all notifications for a user, ordered oldest-first so the client
receives them in chronological order.

Supports pagination via `:page` and `:page_size` options.

# `send_notification`

```elixir
@spec send_notification(user_id(), map()) ::
  {:ok, GameServer.Notifications.Notification.t()}
  | {:error, Ecto.Changeset.t() | atom()}
```

Send a notification to a friend.

`sender_id` is the authenticated user. `attrs` must include:
- `"user_id"` or `"recipient_id"` – the target friend's user ID
- `"title"` – required
- `"content"` – optional
- `"metadata"` – optional map

Returns `{:error, :not_friends}` when the target is not an accepted friend.

# `subscribe`

```elixir
@spec subscribe(user_id()) :: :ok | {:error, term()}
```

Subscribe to notification events for a specific user.

# `unsubscribe`

```elixir
@spec unsubscribe(user_id()) :: :ok
```

Unsubscribe from notification events for a specific user.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
