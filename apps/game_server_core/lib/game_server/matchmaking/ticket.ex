defmodule GameServer.Matchmaking.Ticket do
  @moduledoc """
  Ecto schema for a matchmaking ticket.

  A ticket represents one matchmaking request from a user. Tickets with
  the same `match_params` are grouped and matched together.
  """

  use GameServer.Schema

  import Ecto.Changeset

  alias GameServer.Accounts.User
  alias GameServer.Matchmaking.Constants

  @statuses [
    Constants.status_queued(),
    Constants.status_matched(),
    Constants.status_cancelled()
  ]

  schema "matchmaking_tickets" do
    field :status, :string, default: Constants.status_queued()
    field :match_params, :map, default: %{}
    field :min_players, :integer
    field :max_players, :integer
    field :timeout_ms, :integer
    field :queued_at, :utc_datetime_usec
    field :matched_at, :utc_datetime_usec
    field :match_id, :binary_id

    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  @required [
    :user_id,
    :status,
    :match_params,
    :min_players,
    :max_players,
    :timeout_ms,
    :queued_at
  ]

  @doc false
  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [
      :user_id,
      :status,
      :match_params,
      :min_players,
      :max_players,
      :timeout_ms,
      :queued_at,
      :matched_at,
      :match_id
    ])
    |> validate_required(@required)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:min_players, greater_than: 0)
    |> validate_number(:max_players, greater_than: 0)
    |> validate_number(:timeout_ms, greater_than: 0)
    |> validate_max_gte_min()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_max_gte_min(changeset) do
    min = get_field(changeset, :min_players)
    max = get_field(changeset, :max_players)

    if is_integer(min) and is_integer(max) and max >= min do
      changeset
    else
      add_error(changeset, :max_players, "must be greater than or equal to min_players")
    end
  end
end
