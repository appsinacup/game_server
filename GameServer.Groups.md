# `GameServer.Groups`

Context module for group management: creating, updating, listing, joining,
leaving, kicking, promoting/demoting members, and handling join requests.

Groups are persistent communities (unlike ephemeral lobbies). They support
three visibility types:

- **public** – anyone can join directly
- **private** – anyone can request to join; an admin must approve
- **hidden** – only invited users can join (via notifications / invite API)

## Usage

    # Create a group (creator becomes admin)
    {:ok, group} = Groups.create_group(user_id, %{"title" => "Cool Group"})

    # List public/private groups (hidden excluded)
    groups = Groups.list_groups(%{}, page: 1, page_size: 25)

    # Join a public group
    {:ok, member} = Groups.join_group(user_id, group.id)

    # Request to join a private group
    {:ok, request} = Groups.request_join(user_id, group.id)

    # Admin approves a join request
    {:ok, member} = Groups.approve_join_request(admin_id, request.id)

## PubSub Events

- `"groups"` topic:
  - `{:group_created, group}`
  - `{:group_updated, group}`
  - `{:group_deleted, group_id}`

- `"group:<group_id>"` topic:
  - `{:member_joined, group_id, user_id}`
  - `{:member_left, group_id, user_id}`
  - `{:member_kicked, group_id, user_id}`
  - `{:member_promoted, group_id, user_id}`
  - `{:member_demoted, group_id, user_id}`
  - `{:group_updated, group}`
  - `{:join_request_created, group_id, user_id}`
  - `{:join_request_approved, group_id, user_id}`
  - `{:join_request_rejected, group_id, user_id}`
  - `{:group_notification, group_id, sender_id}`

# `accept_invite`

```elixir
@spec accept_invite(integer(), integer()) ::
  {:ok, GameServer.Groups.GroupMember.t()} | {:error, atom()}
```

Accept a group invite (for hidden groups). The user must have a group_invite
notification containing the group_id.

# `admin?`

```elixir
@spec admin?(integer(), integer()) :: boolean()
```

Check if user is an admin of the group.

# `admin_delete_group`

```elixir
@spec admin_delete_group(integer()) ::
  {:ok, GameServer.Groups.Group.t()} | {:error, term()}
```

Admin-level delete (no membership check, for server admins).

# `admin_update_group`

```elixir
@spec admin_update_group(GameServer.Groups.Group.t(), map()) ::
  {:ok, GameServer.Groups.Group.t()} | {:error, Ecto.Changeset.t()}
```

Admin-level update, bypasses membership checks.

# `approve_join_request`

```elixir
@spec approve_join_request(integer(), integer()) ::
  {:ok, GameServer.Groups.GroupMember.t()} | {:error, atom()}
```

Approve a pending join request. Admin only.

# `cancel_invite`

```elixir
@spec cancel_invite(integer(), integer()) :: :ok | {:error, atom()}
```

Cancel (delete) a group invitation that the current user sent.
Only the sender can cancel their own invitation.

# `cancel_join_request`

```elixir
@spec cancel_join_request(integer(), integer()) ::
  {:ok, GameServer.Groups.GroupJoinRequest.t()} | {:error, atom()}
```

Cancel (delete) a pending join request. Only the requesting user can cancel.

# `change_group`

```elixir
@spec change_group(GameServer.Groups.Group.t(), map()) :: Ecto.Changeset.t()
```

Return a changeset for tracking group changes (admin edit forms).

# `count_all_groups`

```elixir
@spec count_all_groups(map()) :: non_neg_integer()
```

Count ALL groups matching filters (admin).

# `count_all_members`

```elixir
@spec count_all_members() :: non_neg_integer()
```

Total member count across all groups.

# `count_group_members`

```elixir
@spec count_group_members(integer()) :: non_neg_integer()
```

Count members in a group.

# `count_groups_by_type`

```elixir
@spec count_groups_by_type(String.t()) :: non_neg_integer()
```

Count groups by type.

# `count_invitations`

```elixir
@spec count_invitations(integer()) :: non_neg_integer()
```

Count pending invitations for a user.

# `count_join_requests`

```elixir
@spec count_join_requests(integer()) :: non_neg_integer()
```

# `count_list_groups`

```elixir
@spec count_list_groups(map()) :: non_neg_integer()
```

Count groups matching public filters (excludes hidden).

# `count_sent_invitations`

```elixir
@spec count_sent_invitations(integer()) :: non_neg_integer()
```

Count group invitations sent by a user.

# `count_user_groups`

```elixir
@spec count_user_groups(integer()) :: non_neg_integer()
```

Count groups the user belongs to.

# `create_group`

```elixir
@spec create_group(integer(), map()) ::
  {:ok, GameServer.Groups.Group.t()} | {:error, Ecto.Changeset.t() | term()}
```

Create a new group. The creating user becomes an admin member automatically.

# `delete_group`

```elixir
@spec delete_group(integer(), integer()) ::
  {:ok, GameServer.Groups.Group.t()} | {:error, atom()}
```

Delete a group. Admin-only. Refuses if the group still has members — groups
are auto-deleted when the last member leaves.

# `demote_member`

```elixir
@spec demote_member(integer(), integer(), integer()) ::
  {:ok, GameServer.Groups.GroupMember.t()} | {:error, atom()}
```

Demote an admin to member. Only admins can demote other admins.

# `get_group`

```elixir
@spec get_group(integer()) :: GameServer.Groups.Group.t() | nil
```

Get a group by ID (cached).

# `get_group!`

```elixir
@spec get_group!(integer()) :: GameServer.Groups.Group.t()
```

Get a group by ID (raises if not found, cached).

# `get_group_by_title`

```elixir
@spec get_group_by_title(String.t()) :: GameServer.Groups.Group.t() | nil
```

Get a group by its unique title.

# `get_group_members`

```elixir
@spec get_group_members(integer()) :: [GameServer.Groups.GroupMember.t()]
```

Get all members of a group.

# `get_group_members_paginated`

```elixir
@spec get_group_members_paginated(
  integer(),
  keyword()
) :: [GameServer.Groups.GroupMember.t()]
```

Get paginated members of a group with user info.

# `get_membership`

```elixir
@spec get_membership(integer(), integer()) :: GameServer.Groups.GroupMember.t() | nil
```

Get a specific membership.

# `handle_user_deletion`

```elixir
@spec handle_user_deletion(integer()) :: :ok
```

Clean up group memberships before a user is deleted.

For each group the user belongs to:
- If the user is the sole admin and other members exist, promotes the oldest
  member to admin before removing the user's membership row.
- Removes the membership row.
- If the group has no members left after removal, deletes the group.

This must be called *before* `Repo.delete(user)` so that the membership
rows still exist (the DB cascade would silently delete them otherwise
without running the admin-transfer / empty-group logic).

# `invalidate_group_cache_public`

```elixir
@spec invalidate_group_cache_public(integer()) :: :ok
```

Public wrapper for cache invalidation (used by admin controller).

# `invite_to_group`

```elixir
@spec invite_to_group(integer(), integer(), integer()) ::
  {:ok, term()} | {:error, atom()}
```

Invite a user to a hidden group by sending a notification with metadata.
The notification system handles delivery; this creates the notification with
a special title so the client can recognise it as a group invite.

# `join_group`

```elixir
@spec join_group(integer(), integer()) ::
  {:ok, GameServer.Groups.GroupMember.t()} | {:error, atom()}
```

Join a public group directly. Returns error for private/hidden groups.

# `kick_member`

```elixir
@spec kick_member(integer(), integer(), integer()) ::
  {:ok, GameServer.Groups.GroupMember.t()} | {:error, atom()}
```

Kick a member from the group. Only admins can kick.

# `leave_group`

```elixir
@spec leave_group(integer(), integer()) ::
  {:ok, GameServer.Groups.GroupMember.t()} | {:error, atom()}
```

Leave a group.

# `list_all_groups`

```elixir
@spec list_all_groups(
  map(),
  keyword()
) :: [GameServer.Groups.Group.t()]
```

List ALL groups including hidden (admin only).

# `list_groups`

```elixir
@spec list_groups(
  map(),
  keyword()
) :: [GameServer.Groups.Group.t()]
```

List groups visible to the public (excludes hidden).

## Filters

  * `:title` – prefix search on title (case-insensitive)
  * `:type` – exact match on type (`"public"` or `"private"`)
  * `:min_members` – groups with max_members >= value
  * `:max_members` – groups with max_members <= value
  * `:metadata_key` / `:metadata_value` – filter by metadata entry

## Options

  * `:page` – page number (default 1)
  * `:page_size` – results per page (default 25)

# `list_invitations`

```elixir
@spec list_invitations(
  integer(),
  keyword()
) :: [map()]
```

List pending group invitations for a user. These are notifications with
title `"group_invite"` and a metadata `group_id`.

# `list_join_requests`

```elixir
@spec list_join_requests(integer(), integer(), keyword()) ::
  {:ok, [GameServer.Groups.GroupJoinRequest.t()]} | {:error, atom()}
```

List pending join requests for a group (admin only).

# `list_sent_invitations`

```elixir
@spec list_sent_invitations(
  integer(),
  keyword()
) :: [map()]
```

List group invitations sent by a user.
Returns notifications where the user is the sender and the title is `"group_invite"`.

# `list_user_groups`

```elixir
@spec list_user_groups(
  integer(),
  keyword()
) :: [GameServer.Groups.Group.t()]
```

List groups the user belongs to.

# `list_user_groups_with_role`

```elixir
@spec list_user_groups_with_role(integer()) :: [
  {GameServer.Groups.Group.t(), String.t()}
]
```

List groups the user belongs to, together with the membership role.

# `list_user_pending_requests`

```elixir
@spec list_user_pending_requests(integer()) :: [
  GameServer.Groups.GroupJoinRequest.t()
]
```

List pending join requests sent by a user.

# `member?`

```elixir
@spec member?(integer(), integer()) :: boolean()
```

Check if user is a member (any role) of the group.

# `notify_group`

```elixir
@spec notify_group(integer(), integer(), String.t(), map()) ::
  {:ok, non_neg_integer()} | {:error, atom()}
```

Send a notification to all members of a group (except the sender).

Any group member can send a notification. The notification is created for
each member using a direct insert (bypassing the friends-only check).
The `group_id` / `group_name` are stored in metadata so the client can
recognise and route it.

## Options

  * `title` – notification title string (default: `"group_notification"`).
    The title is part of the unique constraint `(sender_id, recipient_id, title)`,
    so different titles create separate notification slots.

Because of the unique constraint on `(sender_id, recipient_id, title)`, a
new notification from the same sender to the same recipient with the same title
replaces the previous one (upsert). This prevents spam while keeping the latest
message.

Returns `{:ok, count}` with the number of notifications sent.

# `promote_member`

```elixir
@spec promote_member(integer(), integer(), integer()) ::
  {:ok, GameServer.Groups.GroupMember.t()} | {:error, atom()}
```

Promote a member to admin. Only admins can promote.

# `reject_join_request`

```elixir
@spec reject_join_request(integer(), integer()) ::
  {:ok, GameServer.Groups.GroupJoinRequest.t()} | {:error, atom()}
```

Reject a pending join request. Admin only.

# `request_join`

```elixir
@spec request_join(integer(), integer()) ::
  {:ok, GameServer.Groups.GroupJoinRequest.t()} | {:error, atom()}
```

Request to join a private group. Creates a pending join request.

# `subscribe_group`

```elixir
@spec subscribe_group(integer()) :: :ok | {:error, term()}
```

Subscribe to a specific group's events.

# `subscribe_groups`

```elixir
@spec subscribe_groups() :: :ok | {:error, term()}
```

Subscribe to global group events.

# `unsubscribe_group`

```elixir
@spec unsubscribe_group(integer()) :: :ok
```

Unsubscribe from a specific group's events.

# `update_group`

```elixir
@spec update_group(integer(), integer(), map()) ::
  {:ok, GameServer.Groups.Group.t()} | {:error, atom() | Ecto.Changeset.t()}
```

Update group settings. Only admins can update.
Cannot lower max_members below current member count.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
