defmodule GameServer.Achievements.UserAchievement do
  @moduledoc """
  UserAchievement struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - Record ID (integer)
  - `user_id` - User ID (integer)
  - `achievement_id` - Achievement ID (integer)
  - `progress` - Current progress towards unlock (integer, default 0)
  - `unlocked_at` - When the achievement was unlocked (DateTime, nil if locked)
  - `metadata` - Arbitrary per-user metadata (map)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer(),
          user_id: integer(),
          achievement_id: integer(),
          progress: non_neg_integer(),
          unlocked_at: DateTime.t() | nil,
          metadata: map(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :user_id,
    :achievement_id,
    :progress,
    :unlocked_at,
    :metadata,
    :inserted_at,
    :updated_at
  ]
end
