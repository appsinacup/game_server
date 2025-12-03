defmodule GameServer.Accounts.User do
  @moduledoc """
  User struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - User ID (integer)
  - `email` - User email (string)
  - `display_name` - Display name (string, optional)
  - `metadata` - Arbitrary user metadata (map)
  - `is_admin` - Whether the user is an admin (boolean)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer(),
          email: String.t(),
          display_name: String.t() | nil,
          metadata: map(),
          is_admin: boolean(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [:id, :email, :display_name, :metadata, :is_admin, :inserted_at, :updated_at]
end
