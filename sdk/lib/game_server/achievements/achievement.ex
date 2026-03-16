defmodule GameServer.Achievements.Achievement do
  @moduledoc """
  Achievement struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - Achievement ID (integer)
  - `slug` - Unique identifier (string)
  - `title` - Display title (string)
  - `description` - Optional description (string)
  - `icon_url` - Optional icon URL (string)
  - `sort_order` - Display ordering (integer, default 0)
  - `hidden` - Whether hidden from public listings until unlocked (boolean)
  - `progress_target` - Number of increments required to unlock (integer, default 1)
  - `metadata` - Arbitrary metadata (map)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer(),
          slug: String.t(),
          title: String.t(),
          description: String.t() | nil,
          icon_url: String.t() | nil,
          sort_order: integer(),
          hidden: boolean(),
          progress_target: pos_integer(),
          metadata: map(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :slug,
    :title,
    :description,
    :icon_url,
    :sort_order,
    :hidden,
    :progress_target,
    :metadata,
    :inserted_at,
    :updated_at
  ]
end
