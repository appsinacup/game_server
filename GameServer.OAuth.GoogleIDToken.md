# `GameServer.OAuth.GoogleIDToken`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/oauth/google_id_token.ex#L1)

Verifies Google OpenID Connect `id_token`s for native/mobile sign-in flows.

This module uses Google's `tokeninfo` endpoint to validate the token and
extract the claims required by the server.

It is intentionally separate from the authorization-code exchange flow used
by the web OAuth callbacks.

# `claims`

```elixir
@type claims() :: map()
```

# `verify`

```elixir
@spec verify(
  String.t(),
  keyword()
) :: {:ok, claims()} | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
