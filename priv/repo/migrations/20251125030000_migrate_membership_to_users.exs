defmodule GameServer.Repo.Migrations.MigrateMembershipToUsers do
  use Ecto.Migration

  def change do
    # add lobby_id column to users (nullable)
    alter table(:users) do
      add :lobby_id, references(:lobbies, on_delete: :nilify_all)
    end

    create index(:users, [:lobby_id])

    # drop the lobby_users join table since we'll store membership in users.lobby_id
    drop_if_exists table(:lobby_users)
  end
end
