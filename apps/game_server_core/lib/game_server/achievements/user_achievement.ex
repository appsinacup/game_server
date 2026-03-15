defmodule GameServer.Achievements.UserAchievement do
  @moduledoc """
  Ecto schema for the `user_achievements` table.

  Tracks a user's progress toward (and unlock status of) an achievement.

  ## Fields
  - `user_id` — the user
  - `achievement_id` — the achievement
  - `progress` — current progress (0..progress_target)
  - `unlocked_at` — nil if not yet unlocked, timestamp when unlocked
  - `metadata` — arbitrary JSON data
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :user_id,
             :achievement_id,
             :progress,
             :unlocked_at,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "user_achievements" do
    belongs_to :user, GameServer.Accounts.User
    belongs_to :achievement, GameServer.Achievements.Achievement

    field :progress, :integer, default: 0
    field :unlocked_at, :utc_datetime
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_achievement, attrs) do
    user_achievement
    |> cast(attrs, [:progress, :unlocked_at, :metadata])
    |> validate_required([])
    |> validate_number(:progress, greater_than_or_equal_to: 0)
  end
end
