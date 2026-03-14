defmodule GameServer.Lobbies.Lobby do
  @moduledoc """
  Lobby struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - Lobby ID (integer)
  - `title` - Display title (string)
  - `host_id` - ID of the host user (integer, optional for hostless lobbies)
  - `hostless` - Whether the lobby is hostless (boolean)
  - `max_users` - Maximum number of users (integer)
  - `is_hidden` - Whether the lobby is hidden from listings (boolean)
  - `is_locked` - Whether the lobby is locked (boolean)
  - `slowdown` - Rate-limit slowdown in milliseconds (integer, default 0)
  - `metadata` - Arbitrary lobby metadata (map)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          host_id: integer() | nil,
          hostless: boolean(),
          max_users: integer(),
          is_hidden: boolean(),
          is_locked: boolean(),
          slowdown: integer(),
          metadata: map(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :title,
    :host_id,
    :hostless,
    :max_users,
    :is_hidden,
    :is_locked,
    :slowdown,
    :metadata,
    :inserted_at,
    :updated_at
  ]
end
