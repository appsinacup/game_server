defmodule GameServer.KV.Entry do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "kv_entries" do
    field :key, :string
    belongs_to :user, GameServer.Accounts.User
    field :value, :map
    field :metadata, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:key, :user_id, :value, :metadata])
    |> validate_required([:key, :value, :metadata])
    |> validate_length(:key, min: 1, max: 512)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:key, name: :kv_entries_unique_key_user_null)
    |> unique_constraint(:key, name: :kv_entries_unique_user_key_user_present)
  end
end
