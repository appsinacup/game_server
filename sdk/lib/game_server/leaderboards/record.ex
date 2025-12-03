defmodule GameServer.Leaderboards.Record do
  @moduledoc """
  Leaderboard record struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - Record ID (integer)
  - `leaderboard_id` - Associated leaderboard ID (integer)
  - `user_id` - User ID (integer)
  - `score` - The score value (integer)
  - `rank` - Virtual field for computed rank (integer)
  - `metadata` - Arbitrary record metadata (map)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer(),
          leaderboard_id: integer(),
          user_id: integer(),
          score: integer(),
          rank: integer() | nil,
          metadata: map(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :leaderboard_id,
    :user_id,
    :score,
    :rank,
    :metadata,
    :inserted_at,
    :updated_at
  ]
end
