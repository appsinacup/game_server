# `GameServer.Storage.Adapter`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/storage/adapter.ex#L1)

Behaviour for object-storage backends.

Implemented by `GameServer.Storage.Local` (disk, the dev default) and
`GameServer.Storage.S3` (any S3-compatible service — AWS S3, Cloudflare R2,
Backblaze B2, MinIO, DigitalOcean Spaces). Callers go through the
`GameServer.Storage` facade, never an adapter directly.

# `key`

```elixir
@type key() :: String.t()
```

# `object`

```elixir
@type object() :: %{
  key: key(),
  size: non_neg_integer(),
  last_modified: DateTime.t() | nil
}
```

A stored object's metadata, as listed by the admin tools.

# `presigned`

```elixir
@type presigned() :: %{
  method: String.t(),
  url: String.t(),
  headers: %{optional(String.t()) =&gt; String.t()},
  key: key(),
  expires_in: pos_integer()
}
```

An upload ticket handed to a client so it can upload bytes directly to the
backend (S3/R2) or to the local upload endpoint — the client flow is identical
either way.

# `delete`

```elixir
@callback delete(key()) :: :ok | {:error, term()}
```

# `exists?`

```elixir
@callback exists?(key()) :: boolean()
```

# `get`

```elixir
@callback get(key()) :: {:ok, binary()} | {:error, term()}
```

# `list`

```elixir
@callback list(keyword()) :: [object()]
```

One page of objects. Opts: `:prefix`, `:offset`, `:limit`.

# `presigned_upload`

```elixir
@callback presigned_upload(
  key(),
  keyword()
) :: {:ok, presigned()} | {:error, term()}
```

# `put`

```elixir
@callback put(key(), iodata(), keyword()) :: {:ok, key()} | {:error, term()}
```

# `url`

```elixir
@callback url(
  key(),
  keyword()
) :: String.t()
```

# `usage`

```elixir
@callback usage(keyword()) :: %{count: non_neg_integer(), bytes: non_neg_integer()}
```

Total object count and byte size. Opts: `:prefix`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
