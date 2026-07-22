defmodule GameServer.Inventory.Item do
  @moduledoc """
  A user's stack of one item. Items are free-form string codes
  (`"health_potion"`, `"sword"`, `"card_374"`) — the game decides which exist.
  `metadata` holds per-stack properties.
  """

  use GameServer.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [:id, :user_id, :item, :quantity, :metadata, :inserted_at, :updated_at]}

  schema "inventory_items" do
    belongs_to :user, GameServer.Accounts.User
    field :item, :string
    field :quantity, :integer, default: 0
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:user_id, :item, :quantity, :metadata])
    |> validate_required([:user_id, :item])
    |> validate_length(:item, min: 1, max: 64)
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :item], name: :inventory_items_user_id_item_index)
  end
end
