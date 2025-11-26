defmodule GameServer.Friends.Friendship do
  use Ecto.Schema
  import Ecto.Changeset

  alias GameServer.Accounts.User

  @statuses ["pending", "accepted", "rejected", "blocked"]

  schema "friendships" do
    belongs_to :requester, User
    belongs_to :target, User

    field :status, :string, default: "pending"

    timestamps()
  end

  @doc false
  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:requester_id, :target_id, :status])
    |> validate_required([:requester_id, :target_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_requester_target_diff()
    |> unique_constraint([:requester_id, :target_id], name: :unique_requester_target)
  end

  defp validate_requester_target_diff(changeset) do
    requester = get_field(changeset, :requester_id)
    target = get_field(changeset, :target_id)

    if requester && target && requester == target do
      add_error(changeset, :target_id, "cannot friend yourself")
    else
      changeset
    end
  end
end
