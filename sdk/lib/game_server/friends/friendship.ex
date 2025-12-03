defmodule GameServer.Friends.Friendship do
  @moduledoc """
  Friendship struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - Friendship ID (integer)
  - `requester_id` - ID of the user who sent the request (integer)
  - `target_id` - ID of the user who received the request (integer)
  - `requester` - Preloaded requester User struct (optional)
  - `target` - Preloaded target User struct (optional)
  - `status` - One of: "pending", "accepted", "rejected", "blocked"
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer() | nil,
          requester_id: integer() | nil,
          target_id: integer() | nil,
          requester: GameServer.Accounts.User.t() | nil,
          target: GameServer.Accounts.User.t() | nil,
          status: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :requester_id,
    :target_id,
    :requester,
    :target,
    :status,
    :inserted_at,
    :updated_at
  ]
end
