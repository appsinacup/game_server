defmodule GameServer.Tournaments.Tournament do
  @moduledoc """
  A bracket tournament occurrence.

  Recurring tournaments share a `slug` (one row per occurrence, like
  leaderboard seasons); `recur` holds the cron expression that spawns the next
  occurrence. `team_size` is advisory — core only ever tracks entry leaders.
  """

  use GameServer.Schema
  import Ecto.Changeset

  @states ~w(scheduled registration running finished cancelled)
  @deadline_policies ~w(forfeit_both advance_first_slot random)

  schema "tournaments" do
    field :slug, :string
    field :title, :string
    field :description, :string, default: ""
    field :category, :string
    field :state, :string, default: "scheduled"
    field :registration_opens_at, :utc_datetime
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :recur, :string
    field :max_entries, :integer
    field :team_size, :integer, default: 1
    field :bracket_size, :integer, default: 8
    field :round_window_sec, :integer
    field :deadline_policy, :string, default: "forfeit_both"
    field :metadata, :map, default: %{}

    has_many :entries, GameServer.Tournaments.Entry

    timestamps(type: :utc_datetime)
  end

  def states, do: @states
  def deadline_policies, do: @deadline_policies

  @required ~w(slug title starts_at round_window_sec)a
  @optional ~w(description category state registration_opens_at ends_at recur max_entries
               team_size bracket_size deadline_policy metadata)a

  def changeset(tournament, attrs) do
    tournament
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9_-]*$/,
      message: "only lowercase letters, digits, _ and -"
    )
    |> validate_inclusion(:state, @states)
    |> validate_inclusion(:deadline_policy, @deadline_policies)
    |> validate_number(:team_size, greater_than: 0)
    |> validate_number(:round_window_sec, greater_than: 0)
    |> validate_number(:max_entries, greater_than: 1)
    |> validate_bracket_size()
    |> validate_windows()
    |> GameServer.Limits.validate_metadata_size(:metadata)
  end

  defp validate_bracket_size(changeset) do
    validate_change(changeset, :bracket_size, fn :bracket_size, size ->
      if is_integer(size) and size >= 2 and Bitwise.band(size, size - 1) == 0,
        do: [],
        else: [bracket_size: "must be a power of two >= 2"]
    end)
  end

  defp validate_windows(changeset) do
    reg = get_field(changeset, :registration_opens_at)
    starts = get_field(changeset, :starts_at)
    ends = get_field(changeset, :ends_at)

    cond do
      reg && starts && DateTime.compare(reg, starts) == :gt ->
        add_error(changeset, :registration_opens_at, "must not be after starts_at")

      starts && ends && DateTime.compare(starts, ends) != :lt ->
        add_error(changeset, :ends_at, "must be after starts_at")

      true ->
        changeset
    end
  end
end
