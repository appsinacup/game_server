defmodule GameServer.Repo.Migrations.AddSlowdownToGroupsAndLobbies do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add :slowdown, :integer, default: 0, null: false
    end

    alter table(:lobbies) do
      add :slowdown, :integer, default: 0, null: false
    end
  end
end
