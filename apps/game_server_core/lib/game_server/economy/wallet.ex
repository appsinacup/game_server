defmodule GameServer.Economy.Wallet do
  @moduledoc """
  A user's balance of one currency. Currencies are free-form string codes
  (`"gold"`, `"gems"`, `"energy"`) — the game decides which exist.
  """

  use GameServer.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder, only: [:id, :user_id, :currency, :balance, :inserted_at, :updated_at]}

  schema "wallets" do
    belongs_to :user, GameServer.Accounts.User
    field :currency, :string
    field :balance, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [:user_id, :currency, :balance])
    |> validate_required([:user_id, :currency])
    |> validate_length(:currency, min: 1, max: 64)
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :currency], name: :wallets_user_id_currency_index)
  end
end
