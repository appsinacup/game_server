defmodule GameServer.Tournaments.Entry do
  @moduledoc """
  One side of the bracket: a leader and their tournament progress.

  Core never tracks team rosters — for `team_size > 1` tournaments the team is
  game policy (hooks), optionally stored in `metadata`.
  """

  use GameServer.Schema
  import Ecto.Changeset

  @states ~w(registered active eliminated winner)

  schema "tournament_entries" do
    belongs_to :tournament, GameServer.Tournaments.Tournament
    belongs_to :leader, GameServer.Accounts.User

    field :seed, :integer
    field :bracket_index, :integer
    field :wins, :integer, default: 0
    field :state, :string, default: "registered"
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def states, do: @states

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:tournament_id, :leader_id, :seed, :bracket_index, :wins, :state, :metadata])
    |> validate_required([:tournament_id, :leader_id])
    |> validate_inclusion(:state, @states)
    |> unique_constraint([:tournament_id, :leader_id])
    |> GameServer.Limits.validate_metadata_size(:metadata)
  end
end
