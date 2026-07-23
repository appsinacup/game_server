# `GameServer.Inventory`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/inventory.ex#L1)

Player item stacks — the non-fungible companion to `GameServer.Economy`.

Items are free-form string codes (`"health_potion"`, `"sword"`, `"card_374"`);
each `(user, item)` pair holds a quantity and per-stack `metadata`. Grants and
consumes are atomic — a consume can never take a stack below zero.

## Usage (server-side / hooks)

    Inventory.grant_item(user_id, "health_potion", 3)
    case Inventory.consume_item(user_id, "health_potion", 1) do
      {:ok, remaining} -> :ok
      {:error, :insufficient_items} -> :none_left
    end

    Inventory.quantity(user_id, "health_potion")  #=> 2
    Inventory.inventory(user_id)                  #=> %{"health_potion" => 2}

Like the economy these are **server-authoritative**: expose them from hooks and
admin tools, never as a raw client "give me items" endpoint.

# `item`

```elixir
@type item() :: String.t()
```

# `user_id`

```elixir
@type user_id() :: Ecto.UUID.t()
```

# `consume_item`

```elixir
@spec consume_item(user_id(), item(), pos_integer(), keyword()) ::
  {:ok, non_neg_integer()} | {:error, :insufficient_items | term()}
```

Remove `qty` of `item`, atomically. `{:error, :insufficient_items}` if the user
doesn't hold enough — the stack never goes negative.

# `grant_item`

```elixir
@spec grant_item(user_id(), item(), pos_integer(), keyword()) ::
  {:ok, non_neg_integer()} | {:error, term()}
```

Add `qty` of `item` to a user's inventory. Returns `{:ok, new_quantity}`.

# `inventory`

```elixir
@spec inventory(user_id()) :: %{required(item()) =&gt; non_neg_integer()}
```

All held items for a user, as a `%{item => quantity}` map.

# `quantity`

```elixir
@spec quantity(user_id(), item()) :: non_neg_integer()
```

Quantity of one item a user holds (0 when they have none).

# `set_metadata`

```elixir
@spec set_metadata(user_id(), item(), map()) :: {:ok, map()} | {:error, term()}
```

Set (overwrite) the per-stack metadata for a user's item.

# `subscribe`

```elixir
@spec subscribe(user_id()) :: :ok | {:error, term()}
```

Subscribe the calling process to a user's live inventory updates.

# `unsubscribe`

```elixir
@spec unsubscribe(user_id()) :: :ok
```

Stop receiving a user's inventory updates.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
