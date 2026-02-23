defmodule GameServer.Groups.Group do
  @moduledoc """
  Ecto schema for the `groups` table.

  A group is a persistent community that users can join. Unlike lobbies (which
  are ephemeral game sessions), groups are long-lived and support admin roles,
  join-request workflows, and invitation flows.

  ## Fields

  - `name` – unique slug / identifier (lowercase, must be unique)
  - `title` – human-readable display title
  - `description` – optional longer description
  - `type` – visibility: `"public"`, `"private"`, or `"hidden"`
  - `max_members` – maximum number of members (default 100)
  - `metadata` – arbitrary server-managed key/value map
  - `creator_id` – the user who originally created the group
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GameServer.Accounts.User
  alias GameServer.Groups.GroupMember

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :title,
             :description,
             :type,
             :max_members,
             :metadata,
             :creator_id,
             :inserted_at,
             :updated_at
           ]}

  schema "groups" do
    field :name, :string
    field :title, :string
    field :description, :string
    field :type, :string, default: "public"
    field :max_members, :integer, default: 100
    field :metadata, :map, default: %{}

    belongs_to :creator, User
    has_many :members, GroupMember

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(name)a
  @optional_fields ~w(title description type max_members metadata)a

  def changeset(group, attrs) do
    group
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 80)
    |> maybe_default_title()
    |> validate_length(:title, min: 1, max: 80)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:type, ["public", "private", "hidden"])
    |> validate_number(:max_members, greater_than: 0, less_than_or_equal_to: 10_000)
    |> unique_constraint(:name)
  end

  defp maybe_default_title(changeset) do
    title = get_field(changeset, :title)
    name = get_field(changeset, :name)

    if (is_nil(title) or title == "") and name do
      put_change(changeset, :title, name)
    else
      changeset
    end
  end
end
