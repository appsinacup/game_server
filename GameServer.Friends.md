# `GameServer.Friends`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/friends.ex#L1)

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
@type user_id() :: Ecto.UUID.t()
```

# `accept_friend_request`

```elixir
@spec accept_friend_request(Ecto.UUID.t(), GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
```

Accept a friend request (only the target may accept). Returns {:ok, friendship}.

# `any_blocked?`

```elixir
@spec any_blocked?(user_id(), [user_id()]) :: boolean()
```

Returns true if `user_id` is on a block with any of `other_ids`, in either
direction. One query, regardless of how many others are checked.

# `block_friend_request`

```elixir
@spec block_friend_request(Ecto.UUID.t(), GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
```

Block an incoming request (only the target may block). Returns {:ok, friendship} with status "blocked".

# `block_user`

```elixir
@spec block_user(GameServer.Accounts.User.t(), user_id()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
```

Block an arbitrary user, with or without any prior friendship between them.

Blocked rows are stored in a canonical direction — `target_id` is the
blocker, `requester_id` is the blocked user — so `list_blocked_for_user/2`
stays correct. Any existing row between the pair (in either direction) is
replaced, so blocking supersedes a pending request or an active friendship.

Returns `{:ok, friendship}`, or `{:error, :cannot_block_self}`.

# `blocked?`

```elixir
@spec blocked?(user_id(), user_id()) :: boolean()
```

Check if either user has blocked the other.

Returns `true` if a friendship row with status `"blocked"` exists in either
direction between the two user IDs.

# `blocked_pairs`

```elixir
@spec blocked_pairs([user_id()]) :: MapSet.t({user_id(), user_id()})
```

Returns the set of blocked pairs among `user_ids`, as a `MapSet` of
`{lower_id, higher_id}` tuples.

Order-independent by construction, so callers can test a pair without
knowing who blocked whom. Resolves an entire candidate group in one query,
which is what makes per-pair filtering cheap in matchmaking.

# `cancel_request`

```elixir
@spec cancel_request(Ecto.UUID.t(), GameServer.Accounts.User.t()) ::
  {:ok, :cancelled} | {:error, :not_found | :not_authorized | term()}
```

Cancel an outgoing friend request (only the requester may cancel).

# `count_all_blocks`

```elixir
@spec count_all_blocks(keyword()) :: non_neg_integer()
```

Count every block across all users, honouring the same filters as `list_all_blocks/1`.

# `count_blocked_for_user`

```elixir
@spec count_blocked_for_user(user_id()) :: non_neg_integer()
```

Count blocked friendships for a user (number of blocked rows where user is target).

# `count_blocked_users`

```elixir
@spec count_blocked_users(user_id()) :: non_neg_integer()
```

Count the users `user_id` has blocked.

# `count_friends_for_user`

```elixir
@spec count_friends_for_user(user_id()) :: non_neg_integer()
```

Count accepted friends for a given user (distinct other user ids).

# `count_incoming_requests`

```elixir
@spec count_incoming_requests(user_id()) :: non_neg_integer()
```

Count incoming pending friend requests for a user.

# `count_outgoing_requests`

```elixir
@spec count_outgoing_requests(user_id()) :: non_neg_integer()
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
  

# `delete_block`

```elixir
@spec delete_block(Ecto.UUID.t()) :: {:ok, :unblocked} | {:error, :not_found}
```

Remove a block by its friendship id, regardless of who created it.

For admin use — `unblock_user/2` is the player-facing path and only lets the
blocker lift their own block.

# `friend_ids`

```elixir
@spec friend_ids(user_id()) :: [user_id()]
```

Return a list of user IDs that are accepted friends of the given user.

This is used internally (e.g. for broadcasting online-status changes)
and does *not* paginate – it returns all friend IDs.

# `friends?`

```elixir
@spec friends?(user_id(), user_id()) :: boolean()
```

Check whether two users are friends (accepted friendship in either direction).

# `get_by_pair`

```elixir
@spec get_by_pair(user_id(), user_id()) :: GameServer.Friends.Friendship.t() | nil
```

Get friendship between two users (ordered requester->target) if exists

# `get_friendship`

```elixir
@spec get_friendship(Ecto.UUID.t()) :: GameServer.Friends.Friendship.t() | nil
```

Get friendship by id (returns nil when not found)

# `get_friendship!`

```elixir
@spec get_friendship!(Ecto.UUID.t()) :: GameServer.Friends.Friendship.t()
```

Get friendship by id

# `list_all_blocks`

```elixir
@spec list_all_blocks(keyword()) :: [GameServer.Friends.Friendship.t()]
```

List every block across all users, newest first, for admin views.

## Options

  * `:user_id` - only blocks where this user is the blocker or the blocked
  * `:page`, `:page_size` - see `t:GameServer.Types.pagination_opts/0`

# `list_blocked_for_user`

```elixir
@spec list_blocked_for_user(user_id(), GameServer.Types.pagination_opts()) :: [
  GameServer.Friends.Friendship.t()
]
```

List blocked friendships for a user (Friendship structs where the user is the blocker / target).

# `list_blocked_users`

```elixir
@spec list_blocked_users(user_id(), GameServer.Types.pagination_opts()) :: [
  GameServer.Accounts.User.t()
]
```

List the users `user_id` has blocked, as `User` structs.

The blacklist proper — unlike `list_blocked_for_user/2`, which returns the
underlying friendship rows.

See `t:GameServer.Types.pagination_opts/0` for available options.

# `list_friends_for_user`

```elixir
@spec list_friends_for_user(Ecto.UUID.t(), GameServer.Types.pagination_opts()) :: [
  GameServer.Accounts.User.t()
]
```

List accepted friends for a given user id - returns list of User structs.

## Options

See `t:GameServer.Types.pagination_opts/0` for available options.

# `list_friends_with_friendship`

```elixir
@spec list_friends_with_friendship(Ecto.UUID.t(), GameServer.Types.pagination_opts()) ::
  [
    %{friendship_id: Ecto.UUID.t(), user: GameServer.Accounts.User.t()}
  ]
```

List accepted friendships for a user along with the other user and friendship id.

Returns a list of maps: %{friendship_id: integer(), user: %User{}}

# `list_incoming_requests`

```elixir
@spec list_incoming_requests(Ecto.UUID.t(), GameServer.Types.pagination_opts()) :: [
  GameServer.Friends.Friendship.t()
]
```

List incoming pending friend requests for a user (Friendship structs).

## Options

See `t:GameServer.Types.pagination_opts/0` for available options.

# `list_outgoing_requests`

```elixir
@spec list_outgoing_requests(Ecto.UUID.t(), GameServer.Types.pagination_opts()) :: [
  GameServer.Friends.Friendship.t()
]
```

List outgoing pending friend requests for a user (Friendship structs).

## Options

See `t:GameServer.Types.pagination_opts/0` for available options.

# `pair_key`

```elixir
@spec pair_key(user_id(), user_id()) :: {user_id(), user_id()}
```

Normalizes a user pair into the order-independent key used by `blocked_pairs/1`.

# `reject_friend_request`

```elixir
@spec reject_friend_request(Ecto.UUID.t(), GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
```

Reject a friend request (only the target may reject). Returns {:ok, friendship}.

# `remove_friend`

```elixir
@spec remove_friend(Ecto.UUID.t(), Ecto.UUID.t()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
```

Remove a friendship (either direction) - only participating users may call this.

# `subscribe_user`

```elixir
@spec subscribe_user(user_id()) :: :ok
```

# `unblock_friendship`

```elixir
@spec unblock_friendship(Ecto.UUID.t(), GameServer.Accounts.User.t()) ::
  {:ok, :unblocked} | {:error, term()}
```

Unblock a previously-blocked friendship (only the user who blocked may unblock). Returns {:ok, :unblocked} on success.

# `unblock_user`

```elixir
@spec unblock_user(GameServer.Accounts.User.t(), user_id()) ::
  {:ok, :unblocked} | {:error, term()}
```

Unblock a user previously blocked via `block_user/2`.

Returns `{:ok, :unblocked}`, or `{:error, :not_found}` when no block exists.

# `unsubscribe_user`

```elixir
@spec unsubscribe_user(user_id()) :: :ok
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
