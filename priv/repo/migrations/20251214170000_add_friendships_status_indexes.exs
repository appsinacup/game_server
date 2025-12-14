defmodule GameServer.Repo.Migrations.AddFriendshipsStatusIndexes do
  use Ecto.Migration

  def change do
    create index(:friendships, [:requester_id, :status])
    create index(:friendships, [:target_id, :status])
  end
end
