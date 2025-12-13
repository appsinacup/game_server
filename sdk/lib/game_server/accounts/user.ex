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

  @doc """
  Builds an email change changeset for a user.

  This function exists in the real GameServer implementation.
  In the SDK it is provided as a stub so documentation references can resolve.
  """
  @spec email_changeset(t(), map(), keyword()) :: no_return()
  def email_changeset(_user, _attrs, _opts) do
    raise "#{__MODULE__}.email_changeset/3 is a stub - only available at runtime on GameServer"
  end

  @doc """
  Builds a password change changeset for a user.

  This function exists in the real GameServer implementation.
  In the SDK it is provided as a stub so documentation references can resolve.
  """
  @spec password_changeset(t(), map(), keyword()) :: no_return()
  def password_changeset(_user, _attrs, _opts) do
    raise "#{__MODULE__}.password_changeset/3 is a stub - only available at runtime on GameServer"
  end
end
