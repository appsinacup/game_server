defmodule GameServer.Groups.GroupInvite do
  @moduledoc """
  GroupInvite struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - Invite ID (integer)
  - `group_id` - ID of the group (integer)
  - `sender_id` - ID of the user who sent the invite (integer)
  - `recipient_id` - ID of the invited user (integer)
  - `status` - Invite status: "pending", "accepted", "declined", or "cancelled" (string)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer(),
          group_id: integer(),
          sender_id: integer(),
          recipient_id: integer(),
          status: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :group_id,
    :sender_id,
    :recipient_id,
    :status,
    :inserted_at,
    :updated_at
  ]
end
