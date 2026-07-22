defmodule GameServer.Economy.LedgerEntry do
  @moduledoc """
  Append-only record of a single wallet change (grant, spend, transfer, admin
  adjustment). One row per balance mutation, keeping an auditable history.
  """

  use GameServer.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :user_id,
             :currency,
             :delta,
             :balance_after,
             :reason,
             :metadata,
             :inserted_at
           ]}

  schema "ledger_entries" do
    belongs_to :user, GameServer.Accounts.User
    field :currency, :string
    # +grant / -spend; balance_after is the wallet balance right after this row.
    field :delta, :integer
    field :balance_after, :integer
    field :reason, :string, default: "unspecified"
    field :idempotency_key, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :user_id,
      :currency,
      :delta,
      :balance_after,
      :reason,
      :idempotency_key,
      :metadata
    ])
    |> validate_required([:user_id, :currency, :delta, :balance_after])
    |> validate_length(:currency, min: 1, max: 64)
    |> validate_length(:reason, max: 64)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:idempotency_key, name: :ledger_entries_idempotency_key_index)
  end
end
