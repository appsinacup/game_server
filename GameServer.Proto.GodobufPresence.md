# `GameServer.Proto.GodobufPresence`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/proto/godobuf_presence.ex#L1)

Fixes proto3-optional presence checks in godobuf-generated GDScript.

godobuf emits scalar `has_x()` as `value != null`, but scalar fields are
initialised to their type default and are never nil, so an absent optional
field reads as present-with-default. The decoder does track real presence via
`data[tag].state == FILLED` (godobuf itself uses that for oneof fields), so
every null-check `has_x()` body is rewritten to the state check.

Ported from `clients/fix_godobuf_presence.py` so `mix host.proto.gen` is
self-contained for downstream projects, which do not have that script.

# `fix`

```elixir
@spec fix(String.t()) :: {String.t(), non_neg_integer()}
```

Rewrites GDScript source, returning `{source, rewritten_count}`.

# `fix_file!`

```elixir
@spec fix_file!(Path.t()) :: non_neg_integer()
```

Rewrites the file in place. Returns the number of `has_()` bodies changed.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
