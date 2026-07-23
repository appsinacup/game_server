# `GameServer.Accounts.AvatarMirror`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/accounts/avatar_mirror.ex#L1)

Oban worker that mirrors a user's external (OAuth provider) avatar into our
own object storage, so avatars render from our storage/CDN instead of
hotlinking the provider.

Enqueued **once** — the first time a user gets a provider avatar while nothing
is stored yet (see `GameServer.Accounts.maybe_mirror_avatar/2`). We never
re-mirror: a repeated fetch is wasteful and can trip a provider's rate limits,
so if the download fails the provider URL simply stays as the fallback.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
