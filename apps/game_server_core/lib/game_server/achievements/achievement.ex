defmodule GameServer.Achievements.Achievement do
  @moduledoc """
  Ecto schema for the `achievements` table.

  An achievement is a goal or milestone that players can unlock.

  ## Fields
  - `slug` — unique identifier (e.g., "first_lobby_join")
  - `title` — display name
  - `description` — human-readable description
  - `icon_url` — optional icon path/URL
  - `points` — point value for this achievement
  - `sort_order` — display ordering (lower = first)
  - `hidden` — if true, not shown until unlocked
  - `progress_target` — number of steps to complete (1 = one-shot, >1 = incremental)
  - `metadata` — arbitrary JSON data
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :title,
             :description,
             :icon_url,
             :points,
             :sort_order,
             :hidden,
             :progress_target,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "achievements" do
    field :slug, :string
    field :title, :string
    field :description, :string, default: ""
    field :icon_url, :string
    field :points, :integer, default: 0
    field :sort_order, :integer, default: 0
    field :hidden, :boolean, default: false
    field :progress_target, :integer, default: 1
    field :metadata, :map, default: %{}

    has_many :user_achievements, GameServer.Achievements.UserAchievement

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(slug title)a
  @optional_fields ~w(description icon_url points sort_order hidden progress_target metadata)a

  @doc false
  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:points, greater_than_or_equal_to: 0)
    |> validate_number(:progress_target, greater_than: 0)
    |> unique_constraint(:slug)
  end
end
