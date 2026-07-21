# `GameServer.Groups.Invites`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/groups/invites.ex#L1)

Group invitations: creating, accepting, declining, cancelling, and
listing/counting pending invites.

Public API is re-exported by `GameServer.Groups`.

# `accept_invite`

```elixir
@spec accept_invite(Ecto.UUID.t(), Ecto.UUID.t()) ::
  {:ok, GameServer.Groups.GroupMember.t()} | {:error, atom()}
```

Accept a pending group invite by **invite_id**.
The user must be the recipient of the invite.
Works for all group types (public, private, hidden).

# `cancel_invite`

```elixir
@spec cancel_invite(Ecto.UUID.t(), Ecto.UUID.t()) :: :ok | {:error, atom()}
```

Cancel (delete) a group invitation that the current user sent.
Only the sender can cancel their own invitation.

# `count_invitations`

```elixir
@spec count_invitations(Ecto.UUID.t()) :: non_neg_integer()
```

Count pending invitations for a user.

# `count_sent_invitations`

```elixir
@spec count_sent_invitations(Ecto.UUID.t()) :: non_neg_integer()
```

Count group invitations sent by a user.

# `decline_invite`

```elixir
@spec decline_invite(Ecto.UUID.t(), Ecto.UUID.t()) :: :ok | {:error, atom()}
```

Decline a pending group invite by **invite_id**.
Only the recipient can decline. The invite is marked as `"declined"`
(not deleted) so the sender can see the outcome.

# `invite_to_group`

```elixir
@spec invite_to_group(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
  {:ok, GameServer.Groups.GroupInvite.t()}
  | {:ok, :request_approved}
  | {:error, atom()}
```

Invite a user to a group. Creates a `GroupInvite` record and sends
an informational notification. The invite record is independent of the
notification — deleting notifications does not affect pending invites.

If the target user already has a pending join request for this group,
the request is automatically approved instead of creating an invite.
In that case, returns `{:ok, :request_approved}`.

# `list_invitations`

```elixir
@spec list_invitations(
  Ecto.UUID.t(),
  keyword()
) :: [map()]
```

List pending group invitations for a user.

# `list_sent_invitations`

```elixir
@spec list_sent_invitations(
  Ecto.UUID.t(),
  keyword()
) :: [map()]
```

List group invitations sent by a user.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
