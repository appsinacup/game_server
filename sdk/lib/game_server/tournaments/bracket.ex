defmodule GameServer.Tournaments.Bracket do
  @moduledoc """
  Tournament bracket struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  A tournament with more entries than `bracket_size` is split into several
  parallel brackets, each crowning its own champion.

  ## Fields

  - `id` - Bracket ID (UUIDv7 string)
  - `tournament_id` - Owning tournament (UUIDv7 string)
  - `index` - 0-based bracket number within the tournament
  - `size` - Slots in this bracket (power of two)
  - `inserted_at` - Creation timestamp
  """

  @type t :: %__MODULE__{
          id: String.t(),
          tournament_id: String.t(),
          index: integer(),
          size: integer(),
          inserted_at: DateTime.t()
        }

  defstruct [:id, :tournament_id, :index, :size, :inserted_at]
end
