defmodule GameServer.Groups.GroupMember do
  @moduledoc """
  Ecto schema for the `group_members` join table.

  Tracks which users belong to which groups and their role within the group.

  ## Roles

  - `"admin"` – can kick members, rename group, change settings, approve
    join requests, promote/demote members
  - `"member"` – regular participant
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GameServer.Accounts.User
  alias GameServer.Groups.Group

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :group_id,
             :user_id,
             :role,
             :inserted_at,
             :updated_at
           ]}

  schema "group_members" do
    belongs_to :group, Group
    belongs_to :user, User

    field :role, :string, default: "member"

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(group_id user_id)a
  @optional_fields ~w(role)a

  def changeset(member, attrs) do
    member
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:role, ["admin", "member"])
    |> unique_constraint([:group_id, :user_id])
  end
end
