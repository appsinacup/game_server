# `GameServer.Friends`

Friends context - handles friend requests and relationships.

Basic semantics:
- A single `friendships` row represents a directed request from requester -> target.
- status: "pending" | "accepted" | "rejected" | "blocked"
- When a user accepts a pending incoming request, that request becomes `accepted`.
  If a reverse pending request exists, it will be removed to avoid duplicate rows.
- Listing friends returns the other user from rows with status `accepted` in either
  direction.

## Usage

    # Create a friend request (requester -> target)
    {:ok, friendship} = GameServer.Friends.create_request(requester_id, target_id)

    # Accept a pending incoming request (performed by the target)
    {:ok, accepted} = GameServer.Friends.accept_friend_request(friendship.id, %GameServer.Accounts.User{id: target_id})

    # List accepted friends for a user (paginated)
    friends = GameServer.Friends.list_friends_for_user(user_id, page: 1, page_size: 25)

    # Count accepted friends for a user
    count = GameServer.Friends.count_friends_for_user(user_id)

    # Remove a friendship (either direction)
    {:ok, _} = GameServer.Friends.remove_friend(user_id, friend_id)

# `user_id`

```elixir
@type user_id() :: integer()
```

# `accept_friend_request`

```elixir
@spec accept_friend_request(integer(), GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
```

Accept a friend request (only the target may accept). Returns {:ok, friendship}.

# `block_friend_request`

```elixir
@spec block_friend_request(integer(), GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
```

Block an incoming request (only the target may block). Returns {:ok, friendship} with status "blocked".

# `blocked?`

```elixir
@spec blocked?(user_id(), user_id()) :: boolean()
```

Check if either user has blocked the other.

Returns `true` if a friendship row with status `"blocked"` exists in either
direction between the two user IDs.

# `cancel_request`

```elixir
@spec cancel_request(integer(), GameServer.Accounts.User.t()) ::
  {:ok, :cancelled} | {:error, :not_found | :not_authorized | term()}
```

Cancel an outgoing friend request (only the requester may cancel).

# `count_blocked_for_user`

```elixir
@spec count_blocked_for_user(user_id() | GameServer.Accounts.User.t()) ::
  non_neg_integer()
```

Count blocked friendships for a user (number of blocked rows where user is target).

# `count_friends_for_user`

```elixir
@spec count_friends_for_user(user_id() | GameServer.Accounts.User.t()) ::
  non_neg_integer()
```

Count accepted friends for a given user (distinct other user ids).

# `count_incoming_requests`

```elixir
@spec count_incoming_requests(user_id() | GameServer.Accounts.User.t()) ::
  non_neg_integer()
```

Count incoming pending friend requests for a user.

# `count_outgoing_requests`

```elixir
@spec count_outgoing_requests(user_id() | GameServer.Accounts.User.t()) ::
  non_neg_integer()
```

Count outgoing pending friend requests for a user.

# `create_request`

```elixir
@spec create_request(GameServer.Accounts.User.t() | user_id(), user_id()) ::
  {:ok, GameServer.Friends.Friendship.t()}
  | {:error,
     :cannot_friend_self
     | :blocked
     | :already_friends
     | :already_requested
     | term()}
```

Create a friend request from requester -> target.
  If a reverse pending request exists (target -> requester) it will be accepted instead.
  Returns {:ok, friendship} on success or {:error, reason}.
  

# `friend_ids`

```elixir
@spec friend_ids(user_id()) :: [user_id()]
```

Return a list of user IDs that are accepted friends of the given user.

This is used internally (e.g. for broadcasting online-status changes)
and does *not* paginate – it returns all friend IDs.

# `get_by_pair`

```elixir
@spec get_by_pair(user_id(), user_id()) :: GameServer.Friends.Friendship.t() | nil
```

Get friendship between two users (ordered requester->target) if exists

# `get_friendship`

```elixir
@spec get_friendship(integer()) :: GameServer.Friends.Friendship.t() | nil
```

Get friendship by id (returns nil when not found)

# `get_friendship!`

```elixir
@spec get_friendship!(integer()) :: GameServer.Friends.Friendship.t()
```

Get friendship by id

# `list_blocked_for_user`

```elixir
@spec list_blocked_for_user(
  user_id() | GameServer.Accounts.User.t(),
  GameServer.Types.pagination_opts()
) :: [GameServer.Friends.Friendship.t()]
```

List blocked friendships for a user (Friendship structs where the user is the blocker / target).

# `list_friends_for_user`

```elixir
@spec list_friends_for_user(
  integer() | GameServer.Accounts.User.t(),
  GameServer.Types.pagination_opts()
) :: [GameServer.Accounts.User.t()]
```

List accepted friends for a given user id - returns list of User structs.

## Options

See `t:GameServer.Types.pagination_opts/0` for available options.

# `list_friends_with_friendship`

```elixir
@spec list_friends_with_friendship(
  integer() | GameServer.Accounts.User.t(),
  GameServer.Types.pagination_opts()
) :: [%{friendship_id: integer(), user: GameServer.Accounts.User.t()}]
```

List accepted friendships for a user along with the other user and friendship id.

Returns a list of maps: %{friendship_id: integer(), user: %User{}}

# `list_incoming_requests`

```elixir
@spec list_incoming_requests(
  integer() | GameServer.Accounts.User.t(),
  GameServer.Types.pagination_opts()
) :: [GameServer.Friends.Friendship.t()]
```

List incoming pending friend requests for a user (Friendship structs).

## Options

See `t:GameServer.Types.pagination_opts/0` for available options.

# `list_outgoing_requests`

```elixir
@spec list_outgoing_requests(
  integer() | GameServer.Accounts.User.t(),
  GameServer.Types.pagination_opts()
) :: [GameServer.Friends.Friendship.t()]
```

List outgoing pending friend requests for a user (Friendship structs).

## Options

See `t:GameServer.Types.pagination_opts/0` for available options.

# `reject_friend_request`

```elixir
@spec reject_friend_request(integer(), GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
```

Reject a friend request (only the target may reject). Returns {:ok, friendship}.

# `remove_friend`

```elixir
@spec remove_friend(integer(), integer()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
```

Remove a friendship (either direction) - only participating users may call this.

# `subscribe_user`

```elixir
@spec subscribe_user(user_id()) :: :ok
```

# `unblock_friendship`

```elixir
@spec unblock_friendship(integer(), GameServer.Accounts.User.t()) ::
  {:ok, :unblocked} | {:error, term()}
```

Unblock a previously-blocked friendship (only the user who blocked may unblock). Returns {:ok, :unblocked} on success.

# `unsubscribe_user`

```elixir
@spec unsubscribe_user(user_id()) :: :ok
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
