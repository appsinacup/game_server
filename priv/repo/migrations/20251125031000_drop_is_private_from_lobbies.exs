defmodule GameServer.Repo.Migrations.DropIsPrivateFromLobbies do
  use Ecto.Migration

  def change do
    alter table(:lobbies) do
      remove :is_private
    end
  end
end
