defmodule GameServer.Leaderboards.Record do
  @moduledoc """
  Ecto schema for the `leaderboard_records` table.

  A record represents a single user's score entry in a leaderboard.
  Each user can have at most one record per leaderboard.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GameServer.Accounts.User
  alias GameServer.Leaderboards.Leaderboard

  schema "leaderboard_records" do
    belongs_to :leaderboard, Leaderboard, type: :string
    belongs_to :user, User

    field :score, :integer, default: 0
    field :metadata, :map, default: %{}

    # Virtual field for rank (computed in queries)
    field :rank, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(leaderboard_id user_id score)a
  @optional_fields ~w(metadata)a

  @doc """
  Changeset for creating a new record.
  """
  def changeset(record, attrs) do
    record
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:leaderboard_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:leaderboard_id, :user_id])
  end

  @doc """
  Changeset for updating an existing record's score.
  """
  def update_changeset(record, attrs) do
    record
    |> cast(attrs, [:score, :metadata])
    |> validate_required([:score])
  end
end
