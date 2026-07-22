defmodule GameServer.Inventory do
  @moduledoc """
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
  """

  import Ecto.Query

  alias GameServer.Inventory.Item
  alias GameServer.Repo

  @type user_id :: Ecto.UUID.t()
  @type item :: String.t()

  @topic_prefix "inventory:user:"

  # ── Reads ───────────────────────────────────────────────────────────────

  @doc "Quantity of one item a user holds (0 when they have none)."
  @spec quantity(user_id(), item()) :: non_neg_integer()
  def quantity(user_id, item) do
    Repo.one(from i in Item, where: i.user_id == ^user_id and i.item == ^item, select: i.quantity) ||
      0
  end

  @doc "All held items for a user, as a `%{item => quantity}` map."
  @spec inventory(user_id()) :: %{item() => non_neg_integer()}
  def inventory(user_id) do
    from(i in Item, where: i.user_id == ^user_id and i.quantity > 0, select: {i.item, i.quantity})
    |> Repo.all()
    |> Map.new()
  end

  # ── Mutations ───────────────────────────────────────────────────────────

  @doc "Add `qty` of `item` to a user's inventory. Returns `{:ok, new_quantity}`."
  @spec grant_item(user_id(), item(), pos_integer(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def grant_item(user_id, item, qty, opts \\ []) when is_integer(qty) and qty > 0 do
    change_quantity(user_id, item, qty, opts)
  end

  @doc """
  Remove `qty` of `item`, atomically. `{:error, :insufficient_items}` if the user
  doesn't hold enough — the stack never goes negative.
  """
  @spec consume_item(user_id(), item(), pos_integer(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, :insufficient_items | term()}
  def consume_item(user_id, item, qty, opts \\ []) when is_integer(qty) and qty > 0 do
    change_quantity(user_id, item, -qty, opts)
  end

  defp change_quantity(user_id, item, delta, _opts) do
    if valid_item?(item) do
      case apply_delta(user_id, item, delta) do
        {:ok, new_qty} ->
          broadcast(user_id, item, new_qty, delta)
          change = %{user_id: user_id, item: item, quantity: new_qty, delta: delta}

          GameServer.Async.run(fn ->
            GameServer.Hooks.internal_call(:after_inventory_changed, [change])
          end)

          {:ok, new_qty}

        err ->
          err
      end
    else
      {:error, :invalid_item}
    end
  end

  defp apply_delta(user_id, item, delta) when delta > 0 do
    on_conflict = from(i in Item, update: [inc: [quantity: ^delta]])

    %Item{}
    |> Item.changeset(%{user_id: user_id, item: item, quantity: delta})
    |> Repo.insert(on_conflict: on_conflict, conflict_target: [:user_id, :item])
    |> case do
      {:ok, _} -> {:ok, quantity(user_id, item)}
      {:error, changeset} -> {:error, {:item_error, changeset}}
    end
  end

  defp apply_delta(user_id, item, delta) when delta < 0 do
    amount = -delta

    {count, _} =
      Repo.update_all(
        from(i in Item,
          where: i.user_id == ^user_id and i.item == ^item and i.quantity >= ^amount
        ),
        inc: [quantity: delta]
      )

    case count do
      1 -> {:ok, quantity(user_id, item)}
      0 -> {:error, :insufficient_items}
    end
  end

  @doc "Set (overwrite) the per-stack metadata for a user's item."
  @spec set_metadata(user_id(), item(), map()) :: {:ok, map()} | {:error, term()}
  def set_metadata(user_id, item, metadata) when is_map(metadata) do
    on_conflict = from(i in Item, update: [set: [metadata: ^metadata]])

    %Item{}
    |> Item.changeset(%{user_id: user_id, item: item, quantity: 0, metadata: metadata})
    |> Repo.insert(on_conflict: on_conflict, conflict_target: [:user_id, :item])
    |> case do
      {:ok, _} -> {:ok, metadata}
      {:error, changeset} -> {:error, {:item_error, changeset}}
    end
  end

  defp valid_item?(item), do: is_binary(item) and byte_size(item) in 1..64

  # ── Realtime ─────────────────────────────────────────────────────────────

  @doc "Subscribe the calling process to a user's live inventory updates."
  @spec subscribe(user_id()) :: :ok | {:error, term()}
  def subscribe(user_id), do: Phoenix.PubSub.subscribe(GameServer.PubSub, topic(user_id))

  @doc "Stop receiving a user's inventory updates."
  @spec unsubscribe(user_id()) :: :ok
  def unsubscribe(user_id), do: Phoenix.PubSub.unsubscribe(GameServer.PubSub, topic(user_id))

  defp topic(user_id), do: @topic_prefix <> user_id

  defp broadcast(user_id, item, quantity, delta) do
    Phoenix.PubSub.broadcast(
      GameServer.PubSub,
      topic(user_id),
      {:inventory_updated, %{item: item, quantity: quantity, delta: delta}}
    )
  end

  # ── Admin reads ──────────────────────────────────────────────────────────

  @doc false
  @spec list_items(keyword()) :: [Item.t()]
  def list_items(opts \\ []) do
    item_query(opts)
    |> order_by([i], asc: i.item)
    |> paginate(opts)
    |> Repo.all()
  end

  @doc false
  @spec count_items(keyword()) :: non_neg_integer()
  def count_items(opts \\ []) do
    Repo.aggregate(item_query(opts), :count, :id)
  end

  defp item_query(opts) do
    Item
    |> maybe_filter(:user_id, Keyword.get(opts, :user_id))
    |> maybe_filter(:item, Keyword.get(opts, :item))
  end

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, :user_id, value), do: where(query, [q], q.user_id == ^value)
  defp maybe_filter(query, :item, value), do: where(query, [q], q.item == ^value)

  defp paginate(query, opts) do
    page = max(Keyword.get(opts, :page, 1), 1)
    page_size = Keyword.get(opts, :page_size, 25)
    query |> limit(^page_size) |> offset(^((page - 1) * page_size))
  end
end
