# `GameServer.Realtime`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/realtime.ex#L1)

Pushing game-defined realtime events to a player's socket.

Core's own events (`updated`, `notification`, `member_joined`, …) are fixed
and documented in `GameServerWeb.RealtimeEvents`. This is the escape hatch a
plugin uses for events core knows nothing about — a quest counter, a boss
spawn — without needing its own channel:

    GameServer.Realtime.push_to_user(user.id, "quest_progress", %{id: 7, step: 2})

Delivery rides the user's existing `user:<id>` channel, so the client needs
no new subscription. The payload is JSON; protobuf mapping is reserved for
core events, whose schemas ship with the clients.

The event name must be declared by the plugin's `realtime_events/0` callback
(see `GameServer.Hooks.Declarations`), for the same reason notification codes
are checked: an undeclared event reaches clients that have no idea it exists,
and never appears in the admin runtime page.

# `push_to_user`

```elixir
@spec push_to_user(Ecto.UUID.t(), String.t(), map()) ::
  :ok | {:error, :undeclared_event}
```

Pushes `event` with `payload` to one user's socket.

Returns `:ok`, or `{:error, :undeclared_event}` when the plugin has not
declared the event name.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
