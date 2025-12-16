defmodule GameServer.Repo.Migrations.AddPrefixSearchIndexes do
  use Ecto.Migration

  def change do
    create index(:users, ["lower(display_name)"])
    create index(:lobbies, ["lower(title)"])
  end
end
