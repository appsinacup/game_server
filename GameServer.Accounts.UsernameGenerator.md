# `GameServer.Accounts.UsernameGenerator`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/accounts/username_generator.ex#L1)

Generates default usernames for new users.

OAuth signups get a slug of the provider display name ("Dragoș" →
`dragos-4821`); email and device signups get a random word from the
embedded list below (`sheep-4821`) — never anything derived from the
email address, which would let strangers guess it. The numeric suffix is
random, not a sequential discriminator, so there is no counter to
exhaust; callers retry with a higher `attempt` on collision, which widens
the suffix.

# `generate`

```elixir
@spec generate(map(), pos_integer()) :: String.t()
```

Generate a username candidate from registration attrs (string keys).

Uses `attrs["display_name"]` when it slugs to something usable, a random
word otherwise. Attempts beyond 3 widen the numeric suffix.

# `slug`

```elixir
@spec slug(term()) :: String.t() | nil
```

Best-effort ASCII slug of a display name in username format; `nil` when
too little survives transliteration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
