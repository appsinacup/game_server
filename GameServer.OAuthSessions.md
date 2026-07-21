# `GameServer.OAuthSessions`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/oauth_sessions.ex#L1)

Helpers for creating and retrieving short-lived OAuth sessions.

# `create_session`

```elixir
@spec create_session(String.t(), map()) ::
  {:ok, GameServer.OAuthSession.t()} | {:error, Ecto.Changeset.t()}
```

# `get_session`

```elixir
@spec get_session(String.t()) :: GameServer.OAuthSession.t() | nil
```

# `update_session`

```elixir
@spec update_session(String.t(), map()) ::
  {:ok, GameServer.OAuthSession.t()} | {:error, Ecto.Changeset.t()} | :not_found
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
