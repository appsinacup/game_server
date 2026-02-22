# `GameServer.Notifications.FriendNotifier`

Subscribes to the global `"friends"` PubSub topic and automatically creates
notifications for key friend events:

- **Incoming friend request** → notifies the target user
- **Friend request accepted** → notifies the requester

This GenServer runs as part of the supervision tree and creates persistent
notifications via `Notifications.admin_create_notification/3` so they are
delivered even when the recipient is offline.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
