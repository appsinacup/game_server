defmodule GameServer.Parties.Party do
  @moduledoc """
  Ecto schema for the `parties` table.

  A party is a pre-lobby grouping mechanism. Players form a party before
  creating or joining a lobby together. The party leader controls when the
  party enters a lobby, and all members join atomically.

  Rules:
  - A party has a leader (creator) and members.
  - Members join via invite (notification-based).
  - The leader sets `max_size` (capacity).
  - If the leader leaves, the party is disbanded (deleted).
  - When the leader creates or joins a lobby, all party members join that
    lobby atomically (the lobby must have enough space).
  - A user can be in both a party and a lobby simultaneously.
  - A user can only be in one party at a time.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GameServer.Accounts.User

  @derive {Jason.Encoder,
           only: [
             :id,
             :leader_id,
             :max_size,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "parties" do
    field :max_size, :integer, default: 4
    field :metadata, :map, default: %{}

    belongs_to :leader, User
    has_many :members, User, foreign_key: :party_id

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(leader_id)a
  @optional_fields ~w(max_size metadata)a

  def changeset(party, attrs) do
    party
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:max_size, greater_than: 1, less_than_or_equal_to: 32)
    |> unique_constraint(:leader_id)
  end
end
