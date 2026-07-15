defmodule GameServer.Payments.ReconciliationCursor do
  @moduledoc """
  Provider reconciliation checkpoint.
  """

  use GameServer.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @providers ~w(apple google steam stripe)

  schema "reconciliation_cursors" do
    field :provider, :string
    field :name, :string
    field :cursor, :map, default: %{}
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(cursor, attrs) do
    cursor
    |> cast(attrs, [:provider, :name, :cursor, :metadata])
    |> validate_required([:provider, :name, :cursor, :metadata])
    |> validate_inclusion(:provider, @providers)
    |> validate_length(:name, min: 1, max: 120)
    |> unique_constraint(:name, name: :reconciliation_cursors_provider_name_index)
  end
end
