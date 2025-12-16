defmodule GameServer.Repo.Migrations.MigrateMembershipToUsers do
  use Ecto.Migration

  def change do
    # add lobby_id column to users (nullable)
    alter table(:users) do
      add :lobby_id, references(:lobbies, on_delete: :nilify_all)
    end

    create index(:users, [:lobby_id])
  end
end
