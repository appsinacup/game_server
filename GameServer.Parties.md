# `GameServer.Parties`

Context module for party management.

A party is a pre-lobby grouping mechanism. Players form a party before
creating or joining a lobby together.

## Usage

    # Create a party (user becomes leader and first member)
    {:ok, party} = GameServer.Parties.create_party(user, %{max_size: 4})

    # Leader invites a friend or shared-group member by user_id
    {:ok, _notification} = GameServer.Parties.invite_to_party(leader, target_user_id)

    # Target accepts the invite
    {:ok, party} = GameServer.Parties.accept_party_invite(target, party_id)

    # Or declines
    :ok = GameServer.Parties.decline_party_invite(target, party_id)

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

# `accept_party_invite`

```elixir
@spec accept_party_invite(GameServer.Accounts.User.t(), integer()) ::
  {:ok, GameServer.Parties.Party.t()} | {:error, atom()}
```

Accept a party invite. Joins the party and marks the invite as accepted.

Returns `{:error, :no_invite}` if no pending invite exists for that party.
Returns `{:error, :already_in_party}` if the user is already in another party.

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

# `broadcast_member_presence`

```elixir
@spec broadcast_member_presence(integer(), tuple()) :: :ok | {:error, term()}
```

Broadcast a member presence event (online/offline) to a party's PubSub topic.

# `cancel_party_invite`

```elixir
@spec cancel_party_invite(GameServer.Accounts.User.t(), integer()) ::
  :ok | {:error, atom()}
```

Cancel a previously sent party invite. Only the original sender (leader) can cancel.

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

# `decline_party_invite`

```elixir
@spec decline_party_invite(GameServer.Accounts.User.t(), integer()) ::
  :ok | {:error, atom()}
```

Decline a party invite. Marks the invite as declined.

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

# `invite_to_party`

```elixir
@spec invite_to_party(GameServer.Accounts.User.t(), integer()) ::
  {:ok, GameServer.Parties.PartyInvite.t()} | {:error, atom()}
```

Invite a user to join the party. Only the party leader may invite.

The target user must be a friend of the leader, or share at least one group
with the leader. A `PartyInvite` record is created and an informational
notification is sent. The invite is independent of the notification —
deleting notifications does not affect pending invites.

Returns `{:error, :not_in_party}` if the caller is not in a party.
Returns `{:error, :not_leader}` if the caller is not the party leader.
Returns `{:error, :not_connected}` if the target is not a friend or shared group member.
Returns `{:error, :already_in_party}` if the target is already in a party.
Returns `{:error, :already_invited}` if a pending invite already exists.

# `join_lobby_with_party`

```elixir
@spec join_lobby_with_party(GameServer.Accounts.User.t(), integer(), map()) ::
  {:ok, map()} | {:error, term()}
```

The party leader joins an existing lobby, and all party members join it
atomically. The party is kept intact.

The lobby must have enough free slots for the entire party.

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

# `list_party_invitations`

```elixir
@spec list_party_invitations(GameServer.Accounts.User.t()) :: [map()]
```

List pending party invites for the given user.

# `list_sent_party_invitations`

```elixir
@spec list_sent_party_invitations(GameServer.Accounts.User.t()) :: [map()]
```

List pending party invites sent by the given leader.

Returns invitations the leader has sent that have not yet been accepted or declined.

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
