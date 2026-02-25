# `GameServer.Parties`

Context module for party management.

A party is a pre-lobby grouping mechanism. Players form a party before
creating or joining a lobby together.

## Usage

    # Create a party (user becomes leader and first member)
    {:ok, party} = GameServer.Parties.create_party(user, %{max_size: 4})

    # Join a party by ID
    {:ok, user} = GameServer.Parties.join_party(user, party_id)

    # Leave a party (if leader leaves, party is disbanded)
    {:ok, _} = GameServer.Parties.leave_party(user)

    # Party leader creates a lobby — all members join atomically
    {:ok, lobby} = GameServer.Parties.create_lobby_with_party(user, lobby_attrs)

    # Party leader joins an existing lobby — all members join atomically
    {:ok, lobby} = GameServer.Parties.join_lobby_with_party(user, lobby_id, opts)

## PubSub Events

This module broadcasts the following events:

- `"party:<party_id>"` topic:
  - `{:party_member_joined, party_id, user_id}`
  - `{:party_member_left, party_id, user_id}`
  - `{:party_disbanded, party_id}`
  - `{:party_updated, party}`

# `admin_delete_party`

```elixir
@spec admin_delete_party(integer()) ::
  {:ok, GameServer.Parties.Party.t()} | {:error, term()}
```

Admin delete of a party. Clears all members' party_id and deletes the party.

# `admin_update_party`

```elixir
@spec admin_update_party(GameServer.Parties.Party.t(), map()) ::
  {:ok, GameServer.Parties.Party.t()} | {:error, Ecto.Changeset.t()}
```

Admin update of a party (max_size, metadata).

# `change_party`

```elixir
@spec change_party(GameServer.Parties.Party.t()) :: Ecto.Changeset.t()
```

Return a changeset for the given party (for edit forms).

# `count_all_parties`

```elixir
@spec count_all_parties(map()) :: non_neg_integer()
```

Count all parties matching the given filters.

# `count_all_party_members`

```elixir
@spec count_all_party_members() :: non_neg_integer()
```

Count total members across all parties.

# `count_party_members`

```elixir
@spec count_party_members(integer()) :: non_neg_integer()
```

Count members in a party.

# `create_lobby_with_party`

```elixir
@spec create_lobby_with_party(GameServer.Accounts.User.t(), map()) ::
  {:ok, map()} | {:error, term()}
```

The party leader creates a new lobby, and all party members join it
atomically. The party is kept intact.

The lobby's `max_users` must be >= party member count.

# `create_party`

```elixir
@spec create_party(GameServer.Accounts.User.t(), map()) ::
  {:ok, GameServer.Parties.Party.t()} | {:error, term()}
```

Create a new party. The user becomes the leader and first member.

Returns `{:error, :already_in_party}` if the user is already in a party.

# `get_party`

```elixir
@spec get_party(integer()) :: GameServer.Parties.Party.t() | nil
```

Get a party by ID. Returns nil if not found.

# `get_party!`

```elixir
@spec get_party!(integer()) :: GameServer.Parties.Party.t()
```

Get a party by ID. Raises if not found.

# `get_party_members`

```elixir
@spec get_party_members(GameServer.Parties.Party.t() | integer()) :: [
  GameServer.Accounts.User.t()
]
```

Get all members of a party.

# `get_user_party`

```elixir
@spec get_user_party(GameServer.Accounts.User.t()) ::
  GameServer.Parties.Party.t() | nil
```

Get the party the user is currently in, or nil.

# `join_lobby_with_party`

```elixir
@spec join_lobby_with_party(GameServer.Accounts.User.t(), integer(), map()) ::
  {:ok, map()} | {:error, term()}
```

The party leader joins an existing lobby, and all party members join it
atomically. The party is kept intact.

The lobby must have enough free slots for the entire party.

# `join_party`

```elixir
@spec join_party(GameServer.Accounts.User.t(), integer()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, term()}
```

Join an existing party by ID.

Returns `{:error, :already_in_party}` if the user is already in a party.
Returns `{:error, :party_not_found}` if the party doesn't exist.
Returns `{:error, :party_full}` if the party is at capacity.

# `join_party_by_code`

```elixir
@spec join_party_by_code(GameServer.Accounts.User.t(), String.t()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, term()}
```

Join an existing party by its shareable code.

If the user is currently in another party, they will automatically leave it
first (disbanding it if they are the leader).

Returns `{:error, :party_not_found}` if no party matches the code.
Returns `{:error, :party_full}` if the party is at capacity.

# `kick_member`

```elixir
@spec kick_member(GameServer.Accounts.User.t(), integer()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, term()}
```

Kick a member from the party. Only the leader can kick.

# `leave_party`

```elixir
@spec leave_party(GameServer.Accounts.User.t()) ::
  {:ok, :left | :disbanded} | {:error, term()}
```

Leave the current party.

If the user is the party leader, the party is disbanded (all members removed,
party deleted). Regular members are simply removed.

# `list_all_parties`

```elixir
@spec list_all_parties(
  map(),
  keyword()
) :: [GameServer.Parties.Party.t()]
```

List all parties with optional filters and pagination.

# `subscribe_parties`

```elixir
@spec subscribe_parties() :: :ok | {:error, term()}
```

Subscribe to all party events (create/delete).

# `subscribe_party`

```elixir
@spec subscribe_party(integer()) :: :ok | {:error, term()}
```

Subscribe to events for a specific party.

# `unsubscribe_party`

```elixir
@spec unsubscribe_party(integer()) :: :ok
```

Unsubscribe from a party's events.

# `update_party`

```elixir
@spec update_party(GameServer.Accounts.User.t(), map()) ::
  {:ok, GameServer.Parties.Party.t()} | {:error, term()}
```

Update party settings. Only the leader can update.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
