# `GameServer.Lobbies`

Context module for lobby management: creating, updating, listing and searching lobbies.

This module contains the core domain operations; more advanced membership and
permission logic will be added in follow-up tasks.

## Usage

    # Create a lobby (returns {:ok, lobby} | {:error, changeset})
    {:ok, lobby} = GameServer.Lobbies.create_lobby(%{name: "fun-room", title: "Fun Room", host_id: host_id})

    # List public lobbies (paginated/filterable)
    lobbies = GameServer.Lobbies.list_lobbies(%{}, page: 1, page_size: 25)

    # Join and leave
    {:ok, user} = GameServer.Lobbies.join_lobby(user, lobby.id)
    {:ok, _} = GameServer.Lobbies.leave_lobby(user)

    # Get current lobby members
    members = GameServer.Lobbies.get_lobby_members(lobby)

    # Subscribe to global or per-lobby events
    :ok = GameServer.Lobbies.subscribe_lobbies()
    :ok = GameServer.Lobbies.subscribe_lobby(lobby.id)

## PubSub Events

This module broadcasts the following events:

- `"lobbies"` topic (global lobby list changes):
  - `{:lobby_created, lobby}` - a new lobby was created
  - `{:lobby_updated, lobby}` - a lobby was updated
  - `{:lobby_deleted, lobby_id}` - a lobby was deleted

- `"lobby:<lobby_id>"` topic (per-lobby membership changes):
  - `{:user_joined, lobby_id, user_id}` - a user joined the lobby
  - `{:user_left, lobby_id, user_id}` - a user left the lobby
  - `{:user_kicked, lobby_id, user_id}` - a user was kicked from the lobby
  - `{:lobby_updated, lobby}` - the lobby settings were updated
  - `{:host_changed, lobby_id, new_host_id}` - the host changed (e.g., after host leaves)

# `can_edit_lobby?`

```elixir
@spec can_edit_lobby?(
  GameServer.Accounts.User.t() | nil,
  GameServer.Lobbies.Lobby.t() | nil
) ::
  boolean()
```

Check if a user can edit a lobby (is host or lobby is hostless).

# `can_view_lobby?`

```elixir
@spec can_view_lobby?(
  GameServer.Accounts.User.t() | nil,
  GameServer.Lobbies.Lobby.t() | nil
) ::
  boolean()
```

Check if a user can view a lobby's details.
Users can view any lobby they can see in the list.

# `change_lobby`

```elixir
@spec change_lobby(GameServer.Lobbies.Lobby.t(), map()) :: Ecto.Changeset.t()
```

# `count_hidden_lobbies`

```elixir
@spec count_hidden_lobbies() :: non_neg_integer()
```

Returns the count of hidden lobbies.

# `count_hostless_lobbies`

```elixir
@spec count_hostless_lobbies() :: non_neg_integer()
```

Returns the count of hostless lobbies.

# `count_list_all_lobbies`

```elixir
@spec count_list_all_lobbies(map()) :: non_neg_integer()
```

Count ALL lobbies matching filters. For admin pagination.

# `count_list_lobbies`

```elixir
@spec count_list_lobbies(map()) :: non_neg_integer()
```

Count lobbies matching filters (excludes hidden ones unless admin list used). If metadata filters are supplied, they will be applied after fetching.

# `count_locked_lobbies`

```elixir
@spec count_locked_lobbies() :: non_neg_integer()
```

Returns the count of locked lobbies.

# `count_passworded_lobbies`

```elixir
@spec count_passworded_lobbies() :: non_neg_integer()
```

Returns the count of lobbies with passwords.

# `create_lobby`

```elixir
@spec create_lobby(GameServer.Types.lobby_create_attrs()) ::
  {:ok, GameServer.Lobbies.Lobby.t()} | {:error, Ecto.Changeset.t() | term()}
```

Creates a new lobby.

## Attributes

See `t:GameServer.Types.lobby_create_attrs/0` for available fields.

# `create_membership`

```elixir
@spec create_membership(%{lobby_id: integer(), user_id: integer()}) ::
  {:ok, GameServer.Accounts.User.t()}
  | {:error, :not_found | Ecto.Changeset.t() | term()}
```

# `delete_lobby`

```elixir
@spec delete_lobby(GameServer.Lobbies.Lobby.t()) ::
  {:ok, GameServer.Lobbies.Lobby.t()} | {:error, Ecto.Changeset.t() | term()}
```

# `delete_membership`

```elixir
@spec delete_membership(GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t()}
```

# `get_lobby`

```elixir
@spec get_lobby(integer()) :: GameServer.Lobbies.Lobby.t() | nil
```

# `get_lobby!`

```elixir
@spec get_lobby!(integer()) :: GameServer.Lobbies.Lobby.t()
```

# `get_lobby_members`

```elixir
@spec get_lobby_members(GameServer.Lobbies.Lobby.t() | integer() | String.t()) :: [
  GameServer.Accounts.User.t()
]
```

Gets all users currently in a lobby.

Returns a list of User structs.

## Examples

    iex> get_lobby_members(lobby)
    [%User{}, %User{}]

    iex> get_lobby_members(lobby_id)
    [%User{}]

# `join_lobby`

```elixir
@spec join_lobby(
  GameServer.Accounts.User.t(),
  GameServer.Lobbies.Lobby.t() | integer() | String.t(),
  map() | keyword()
) :: {:ok, GameServer.Accounts.User.t()} | {:error, term()}
```

# `kick_user`

```elixir
@spec kick_user(
  GameServer.Accounts.User.t(),
  GameServer.Lobbies.Lobby.t(),
  GameServer.Accounts.User.t()
) :: {:ok, GameServer.Accounts.User.t()} | {:error, term()}
```

Kick a user from a lobby. Only the host can kick users.
Returns {:ok, user} on success, {:error, reason} on failure.

# `leave_lobby`

```elixir
@spec leave_lobby(GameServer.Accounts.User.t()) :: {:ok, term()} | {:error, term()}
```

# `list_all_lobbies`

```elixir
@spec list_all_lobbies(map(), GameServer.Types.pagination_opts()) :: [
  GameServer.Lobbies.Lobby.t()
]
```

List ALL lobbies including hidden ones. For admin use only.
Accepts filters: %{
  title: string,
  is_hidden: boolean/string,
  is_locked: boolean/string,
  has_password: boolean/string,
  min_users: integer (filter by max_users >= val),
  max_users: integer (filter by max_users <= val)
}

# `list_lobbies`

```elixir
@spec list_lobbies(map(), GameServer.Types.lobby_list_opts()) :: [
  GameServer.Lobbies.Lobby.t()
]
```

List lobbies. Accepts optional search filters.

## Filters

  * `:title` - Filter by title (partial match)
  * `:is_passworded` - boolean or string 'true'/'false' (omit for any)
  * `:is_locked` - boolean or string 'true'/'false' (omit for any)
  * `:min_users` - Filter lobbies with max_users >= value
  * `:max_users` - Filter lobbies with max_users <= value
  * `:metadata_key` - Filter by metadata key
  * `:metadata_value` - Filter by metadata value (requires metadata_key)

## Options

See `t:GameServer.Types.lobby_list_opts/0` for available options.

# `list_lobbies_for_user`

```elixir
@spec list_lobbies_for_user(
  GameServer.Accounts.User.t() | nil,
  map(),
  GameServer.Types.lobby_list_opts()
) :: [GameServer.Lobbies.Lobby.t()]
```

List lobbies visible to a specific user.
Includes the user's own lobby even if it's hidden.

# `list_memberships_for_lobby`

```elixir
@spec list_memberships_for_lobby(integer() | String.t()) :: [
  GameServer.Accounts.User.t()
]
```

# `quick_join`

```elixir
@spec quick_join(
  GameServer.Accounts.User.t(),
  String.t() | nil,
  integer() | nil,
  map()
) ::
  {:ok, GameServer.Lobbies.Lobby.t()}
  | {:error, :already_in_lobby | Ecto.Changeset.t() | term()}
```

Attempt to find an open lobby matching the given criteria and join it, or
create a new lobby if none matches.

Signature: quick_join(user, title \ nil, max_users \ nil, metadata \ %{})

- If the user is already in a lobby returns {:error, :already_in_lobby}
- On successful join or creation returns {:ok, lobby}
- Propagates errors from join or create flows

# `subscribe_lobbies`

```elixir
@spec subscribe_lobbies() :: :ok | {:error, term()}
```

Subscribe to global lobby events (lobby created, updated, deleted).

# `subscribe_lobby`

```elixir
@spec subscribe_lobby(integer()) :: :ok | {:error, term()}
```

Subscribe to a specific lobby's events (membership changes, updates).

# `unsubscribe_lobby`

```elixir
@spec unsubscribe_lobby(integer()) :: :ok
```

Unsubscribe from a specific lobby's events.

# `update_lobby`

```elixir
@spec update_lobby(
  GameServer.Lobbies.Lobby.t(),
  GameServer.Types.lobby_update_attrs()
) ::
  {:ok, GameServer.Lobbies.Lobby.t()} | {:error, Ecto.Changeset.t() | term()}
```

Updates an existing lobby.

## Attributes

See `t:GameServer.Types.lobby_update_attrs/0` for available fields.

# `update_lobby_by_host`

```elixir
@spec update_lobby_by_host(
  GameServer.Accounts.User.t(),
  GameServer.Lobbies.Lobby.t(),
  GameServer.Types.lobby_update_attrs()
) ::
  {:ok, GameServer.Lobbies.Lobby.t()}
  | {:error, :not_host | :too_small | Ecto.Changeset.t() | term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
