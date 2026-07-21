# `GameServer.Schema`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/schema.ex#L1)

Shared schema base: `use GameServer.Schema` instead of `use Ecto.Schema`.

Sets UUIDv7 primary and foreign keys (see `GameServer.UUIDv7`) so ids are
time-ordered but not enumerable.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
