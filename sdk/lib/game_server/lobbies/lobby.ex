defmodule GameServer.Lobbies.Lobby do
  @moduledoc """
  Lobby struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - Lobby ID (integer)
  - `name` - Unique lobby name/slug (string)
  - `title` - Display title (string)
  - `host_id` - ID of the host user (integer, optional for hostless lobbies)
  - `hostless` - Whether the lobby is hostless (boolean)
  - `max_users` - Maximum number of users (integer)
  - `is_hidden` - Whether the lobby is hidden from listings (boolean)
  - `is_locked` - Whether the lobby is locked (boolean)
  - `metadata` - Arbitrary lobby metadata (map)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          title: String.t(),
          host_id: integer() | nil,
          hostless: boolean(),
          max_users: integer(),
          is_hidden: boolean(),
          is_locked: boolean(),
          metadata: map(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :name,
    :title,
    :host_id,
    :hostless,
    :max_users,
    :is_hidden,
    :is_locked,
    :metadata,
    :inserted_at,
    :updated_at
  ]
end
