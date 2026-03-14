defmodule GameServer.Groups.Group do
  @moduledoc """
  Group struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - Group ID (integer)
  - `title` - Group title (string)
  - `description` - Group description (string)
  - `type` - Group type: `"public"`, `"private"`, or `"hidden"` (string)
  - `max_members` - Maximum number of members (integer, default 100)
  - `metadata` - Arbitrary group metadata (map)
  - `slowdown` - Rate-limit slowdown in milliseconds (integer, default 0)
  - `creator_id` - ID of the user who created the group (integer)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          description: String.t(),
          type: String.t(),
          max_members: integer(),
          metadata: map(),
          slowdown: integer(),
          creator_id: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :title,
    :description,
    :type,
    :max_members,
    :metadata,
    :slowdown,
    :creator_id,
    :inserted_at,
    :updated_at
  ]
end
