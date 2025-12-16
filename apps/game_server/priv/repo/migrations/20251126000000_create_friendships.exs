defmodule GameServer.Repo.Migrations.CreateFriendships do
  use Ecto.Migration

  def change do
    create table(:friendships) do
      add :requester_id, references(:users, on_delete: :delete_all), null: false
      add :target_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"

      timestamps()
    end

    create index(:friendships, [:requester_id])
    create index(:friendships, [:target_id])

    # Prevent duplicate direct requests (requester -> target)
    create unique_index(:friendships, [:requester_id, :target_id], name: :unique_requester_target)

    # Ensure users cannot friend themselves is enforced at the application
    # level (Ecto changeset). SQLite does not support ALTER TABLE ADD CONSTRAINT
    # in the same manner as Postgres, so we avoid adding DB-level check here
    # to keep cross-adapter compatibility.
  end
end
