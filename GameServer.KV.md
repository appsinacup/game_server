# `GameServer.KV`

Generic key/value storage.

This is intentionally minimal and un-opinionated.

If you want namespacing, encode it in `key` (e.g. `"polyglot_pirates:key1"`).
If you want per-user values, pass `user_id: ...` to `get/2`, `put/4`, and `delete/2`.
If you want per-lobby values, pass `lobby_id: ...` to the same functions.
You can also pass both to scope a key to a user within a lobby.

This module uses the app cache (`GameServer.Cache`) as a best-effort read cache.
Writes update the cache and deletes evict it.

# `attrs`

```elixir
@type attrs() :: %{
  :key =&gt; String.t(),
  optional(:user_id) =&gt; pos_integer(),
  optional(:lobby_id) =&gt; pos_integer(),
  :value =&gt; value(),
  optional(:metadata) =&gt; metadata()
}
```

Attributes used when creating or updating entries.

Expected keys (atom keys recommended):
- `:key` — the entry key (`String.t()`)
  - `:user_id` — optional user id (`pos_integer()`)
  - `:lobby_id` — optional lobby id (`pos_integer()`)
- `:value` — the stored value (`value()`)
- `:metadata` — optional metadata (`metadata()`)

# `list_opts`

```elixir
@type list_opts() :: [
  page: pos_integer(),
  page_size: pos_integer(),
  user_id: pos_integer(),
  lobby_id: pos_integer(),
  global_only: boolean(),
  key: String.t()
]
```

Options accepted by `list_entries/1` and `count_entries/1`.

Keys (all optional):
- `:page` — page number (`pos_integer()`, defaults to `1`)
- `:page_size` — page size (`pos_integer()`, defaults to `50`)
- `:user_id` — filter by user id (`pos_integer()`)
- `:lobby_id` — filter by lobby id (`pos_integer()`)
- `:global_only` — when true, only return global entries (where `user_id` and `lobby_id` are `nil`) (`boolean()`)
- `:key` — substring filter (`String.t()`)

# `metadata`

```elixir
@type metadata() :: map()
```

Metadata stored alongside a value. Typically a small map with auxiliary fields.

# `payload`

```elixir
@type payload() :: %{value: value(), metadata: metadata()}
```

Payload returned by `get/1` and `get/2`.

# `value`

```elixir
@type value() :: map()
```

Value stored for a key. This is an arbitrary map and should contain JSON-serializable data.

# `count_entries`

```elixir
@spec count_entries(list_opts()) :: non_neg_integer()
```

Count the number of entries that match the optional filter.

Accepts the same options as `list_entries/1` (see `t:list_opts/0`). Returns a non-negative integer.

# `create_entry`

```elixir
@spec create_entry(attrs()) ::
  {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
```

Create a new `Entry` from `attrs` (expecting `key`, optional `user_id`/`lobby_id`,
`value`, `metadata`).
Returns `{:ok, entry}` or `{:error, changeset}`.

# `delete`

```elixir
@spec delete(
  String.t(),
  keyword()
) :: :ok
```

Delete the entry at `key`.

Pass `user_id: id` or `lobby_id: id` in `opts` to delete a scoped key. Returns `:ok`.

# `delete_entry`

```elixir
@spec delete_entry(pos_integer()) :: :ok
```

Delete an entry by its `id`.

Returns `:ok` whether or not the entry existed.

# `get`

```elixir
@spec get(
  String.t(),
  keyword()
) :: {:ok, payload()} | :error
```

Retrieve the value and metadata stored for `key`.

Pass `user_id: id` or `lobby_id: id` in `opts` to scope the lookup.
Returns `{:ok, %{value: map(), metadata: map()}}` when found, or `:error` when not present.

# `get_entry`

```elixir
@spec get_entry(pos_integer()) :: GameServer.KV.Entry.t() | nil
```

Fetch an `Entry` by its numeric `id`.
Returns the `Entry` struct or `nil` if not found.

# `list_entries`

```elixir
@spec list_entries(list_opts()) :: [GameServer.KV.Entry.t()]
```

List key/value entries with optional pagination and filtering.

Supported options: `:page`, `:page_size`, `:user_id`, `:lobby_id`, `:global_only`,
and `:key` (substring filter).
See `t:list_opts/0` for the expected option types.
Returns a list of `Entry` structs ordered by most recently updated.

# `put`

```elixir
@spec put(String.t(), value(), metadata()) ::
  {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
```

# `put`

```elixir
@spec put(String.t(), value(), metadata(), list_opts()) ::
  {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
```

Store `value` with optional `metadata` at `key`.

When using the 4-arity, supported options include `user_id: id` or `lobby_id: id` to scope
the entry.
Returns `{:ok, entry}` on success or `{:error, changeset}` on validation failure.

# `update_entry`

```elixir
@spec update_entry(pos_integer(), attrs()) ::
  {:ok, GameServer.KV.Entry.t()}
  | {:error, :not_found}
  | {:error, Ecto.Changeset.t()}
```

Update an existing entry by `id` with `attrs`.
Returns `{:ok, entry}`, `{:error, :not_found}` if missing, or `{:error, changeset}` on validation error.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
