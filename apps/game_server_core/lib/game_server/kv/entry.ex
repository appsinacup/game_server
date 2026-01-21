defmodule GameServer.KV.Entry do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "kv_entries" do
    field :key, :string
    belongs_to :user, GameServer.Accounts.User
    belongs_to :lobby, GameServer.Lobbies.Lobby
    field :value, :map
    field :metadata, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:key, :user_id, :lobby_id, :value, :metadata])
    |> validate_required([:key, :value, :metadata])
    |> validate_length(:key, min: 1, max: 512)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:lobby_id)
    |> unique_constraint(:key, name: :kv_entries_unique_key_user_null)
    |> unique_constraint(:key, name: :kv_entries_unique_user_key_user_present)
    |> unique_constraint(:key, name: :kv_entries_unique_lobby_key_lobby_present)
    |> unique_constraint(:key, name: :kv_entries_unique_user_lobby_key_present)
  end
end
