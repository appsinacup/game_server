# `GameServer.Storage`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/storage.ex#L1)

Object storage for user uploads (avatars, and future user-generated content).

A thin facade over a configured backend so game code never depends on where
bytes live:

  * `GameServer.Storage.Local` — local disk, the default (great for dev and
    single-node deploys).
  * `GameServer.Storage.S3` — any S3-compatible service (AWS S3, Cloudflare
    R2, Backblaze B2, MinIO, DigitalOcean Spaces).

Select the backend with `STORAGE_ADAPTER` (`local` | `s3`); see the deployment
docs for the full `STORAGE_*` variable list.

## Direct uploads

Clients never stream bytes through the app. The server issues an upload ticket
and the client uploads straight to the backend:

    key = Storage.build_key("avatars", user.id, "me.png")
    {:ok, ticket} = Storage.presigned_upload(key, content_type: "image/png")
    # -> client PUTs the file to ticket.url, then tells the server `key` is ready

The ticket shape is identical for local disk and S3, so the client code does
not change between environments.

# `adapter`

```elixir
@spec adapter() :: module()
```

The configured backend module (defaults to `GameServer.Storage.Local`).

# `build_key`

```elixir
@spec build_key(String.t(), String.t(), String.t()) :: String.t()
```

Build a collision-resistant object key: `<namespace>/<owner_id>/<random><ext>`.

The extension is taken (lower-cased) from `filename`; everything else is
server-chosen so a client can't overwrite another object.

# `cache_control`

```elixir
@spec cache_control(GameServer.Storage.Adapter.key()) :: String.t()
```

The `Cache-Control` header for `key`, from the first matching prefix policy
(or `default_cache_control` when none match). Used by the local serve route
and set as S3 object metadata at upload.

# `delete`

```elixir
@spec delete(GameServer.Storage.Adapter.key()) :: :ok | {:error, term()}
```

# `exists?`

```elixir
@spec exists?(GameServer.Storage.Adapter.key()) :: boolean()
```

# `get`

```elixir
@spec get(GameServer.Storage.Adapter.key()) :: {:ok, binary()} | {:error, term()}
```

# `list_objects`

```elixir
@spec list_objects(keyword()) :: [GameServer.Storage.Adapter.object()]
```

One page of stored objects. Opts: `:prefix`, `:offset`, `:limit` (admin use).

# `presigned_upload`

```elixir
@spec presigned_upload(
  GameServer.Storage.Adapter.key(),
  keyword()
) :: {:ok, GameServer.Storage.Adapter.presigned()} | {:error, term()}
```

An upload ticket for the client (see the module doc).

# `put`

```elixir
@spec put(GameServer.Storage.Adapter.key(), iodata(), keyword()) ::
  {:ok, GameServer.Storage.Adapter.key()} | {:error, term()}
```

# `url`

```elixir
@spec url(
  GameServer.Storage.Adapter.key(),
  keyword()
) :: String.t()
```

A readable URL for `key` (public or signed, backend-dependent).

# `usage`

```elixir
@spec usage(keyword()) :: %{count: non_neg_integer(), bytes: non_neg_integer()}
```

Total object count and byte size. Opts: `:prefix`.

# `validate_upload`

```elixir
@spec validate_upload(String.t(), non_neg_integer(), keyword()) ::
  :ok | {:error, :unsupported_content_type | :too_large}
```

Validate an upload's content type and size before issuing a ticket.

Options: `:content_types` (allow-list, defaults to common images),
`:max_bytes` (defaults to `LIMIT_MAX_UPLOAD_BYTES`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
