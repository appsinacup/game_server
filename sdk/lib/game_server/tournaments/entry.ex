defmodule GameServer.Tournaments.Entry do
  @moduledoc """
  Tournament entry struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  An entry is one side of the bracket. The server only tracks its leader —
  for team tournaments, team composition is game policy (hooks).

  ## Fields

  - `id` - Entry ID (UUIDv7 string)
  - `tournament_id` - Owning tournament (UUIDv7 string)
  - `leader_id` - The registrant (user id)
  - `seed` - Bracket slot assigned at the draw (nil before it)
  - `bracket_index` - Which bracket the entry landed in (nil before the draw)
  - `wins` - Matches won so far
  - `state` - `"registered"`, `"active"`, `"eliminated"` or `"winner"`
  - `metadata` - Game data, e.g. an entry-fee receipt (map)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: String.t(),
          tournament_id: String.t(),
          leader_id: String.t(),
          seed: integer() | nil,
          bracket_index: integer() | nil,
          wins: integer(),
          state: String.t(),
          metadata: map(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :tournament_id,
    :leader_id,
    :seed,
    :bracket_index,
    :wins,
    :state,
    :metadata,
    :inserted_at,
    :updated_at
  ]
end
