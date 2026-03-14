defmodule GameServer.Parties.Party do
  @moduledoc """
  Party struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - Party ID (integer)
  - `leader_id` - ID of the party leader (integer)
  - `max_size` - Maximum party size (integer, default 4)
  - `metadata` - Arbitrary party metadata (map)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer(),
          leader_id: integer(),
          max_size: integer(),
          metadata: map(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :leader_id,
    :max_size,
    :metadata,
    :inserted_at,
    :updated_at
  ]
end
