# `Gamend.Storage`
[🔗](https://github.com/appsinacup/gamend/blob/v1.0.7/lib/gamend/storage.ex#L1)

Object storage for user uploads (avatars, and future user-generated content).

A thin facade over a configured backend so game code never depends on where
bytes live:

  * `Gamend.Storage.Local` — local disk, the default (great for dev and
    single-node deploys).
  * `Gamend.Storage.S3` — any S3-compatible service (AWS S3, Cloudflare
    R2, Backblaze B2, MinIO, DigitalOcean Spaces).

Select the backend with `GAMEND_STORAGE_ADAPTER` (`local` | `s3`); see the
settings docs for the full `GAMEND_STORAGE_*` variable list.

## What may be stored

Uploaded bytes come from users, so nothing about them is trusted:

  * the *key* is server-chosen (`build_key/3`), never taken from the client -
    that is what fixes the extension, and with it the content type the object
    is served as;
  * the declared content type must be in the allow-list (`validate_upload/3`),
    and the bytes must actually be that format (`sniff_content_type/1`);
  * size is capped per object (`max_upload_bytes`) and per owner prefix
    (`max_upload_bytes_per_owner`).

We never decode an image server-side, so there is no image-parser attack
surface here; the risk being defended against is serving attacker-chosen bytes
under an attacker-chosen type from our own origin.

## Direct uploads

Clients never stream bytes through the app. The server issues an upload ticket
and the client uploads straight to the backend:

    key = Storage.build_key("avatars", user.id, "me.png")
    {:ok, ticket} = Storage.presigned_upload(key, content_type: "image/png")
    # -> client PUTs the file to ticket.url, then tells the server `key` is ready

The ticket shape is identical for local disk and S3, so the client code does
not change between environments.

## What is checked, and where

The two backends do not offer the same guarantees at upload time, so the
checks are deliberately split:

  * **At ticket time** (both backends) the declared content type must be one
    we accept, and the key - including its extension - is server-chosen.
  * **At upload time** (local only) the size cap, the owner quota and
    `sniff_content_type/1` all run, because the bytes pass through us.
  * **At confirm time** (both backends) size and magic bytes are re-checked
    against the *stored* object, and a failing one is deleted.

That last step is not redundant. An S3 presigned PUT goes straight to the
bucket, so nothing in this application sees those bytes and ExAws does not
sign the content type - confirm is the only point at which the server can
still refuse. Anything that persists an object's URL must therefore go through
`GamendWeb.Uploads.confirm/5` rather than trusting a key it was handed.

# `adapter`

```elixir
@spec adapter() :: module()
```

The configured backend module (defaults to `Gamend.Storage.Local`).

# `build_key`

```elixir
@spec build_key(String.t(), String.t(), String.t()) :: String.t()
```

Build a collision-resistant object key: `<namespace>/<owner_id>/<random><ext>`.

The extension is taken (lower-cased) from `filename`; everything else is
server-chosen so a client can't overwrite another object.

# `cache_control`

```elixir
@spec cache_control(Gamend.Storage.Adapter.key()) :: String.t()
```

The `Cache-Control` header for `key`, from the first matching prefix policy
(or `default_cache_control` when none match). Used by the local serve route
and set as S3 object metadata at upload.

# `delete`

```elixir
@spec delete(Gamend.Storage.Adapter.key()) :: :ok | {:error, term()}
```

# `delete_prefix`

```elixir
@spec delete_prefix(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
```

Deletes every object under `prefix`. Returns how many were removed.

# `exists?`

```elixir
@spec exists?(Gamend.Storage.Adapter.key()) :: boolean()
```

# `extension_for`

```elixir
@spec extension_for(String.t()) :: String.t()
```

File extension for a declared image content type ("" when unknown).

# `get`

```elixir
@spec get(Gamend.Storage.Adapter.key()) :: {:ok, binary()} | {:error, term()}
```

# `list_objects`

```elixir
@spec list_objects(keyword()) :: [Gamend.Storage.Adapter.object()]
```

One page of stored objects. Opts: `:prefix`, `:offset`, `:limit` (admin use).

# `presigned_upload`

```elixir
@spec presigned_upload(Gamend.Storage.Adapter.key(), keyword()) ::
  {:ok, Gamend.Storage.Adapter.presigned()} | {:error, term()}
```

An upload ticket for the client (see the module doc).

# `put`

```elixir
@spec put(Gamend.Storage.Adapter.key(), iodata(), keyword()) ::
  {:ok, Gamend.Storage.Adapter.key()} | {:error, term()}
```

# `sniff_content_type`

```elixir
@spec sniff_content_type(binary()) :: String.t() | nil
```

The image content type `data` actually is, read from its magic bytes
(`nil` when it is not one of the formats we accept).

A declared `Content-Type` is only a header; this is what the bytes say.

# `stat`

```elixir
@spec stat(Gamend.Storage.Adapter.key()) ::
  {:ok, Gamend.Storage.Adapter.stat()} | {:error, term()}
```

Size and stored content type of `key`, without downloading it.

# `url`

```elixir
@spec url(Gamend.Storage.Adapter.key(), keyword()) :: String.t()
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
