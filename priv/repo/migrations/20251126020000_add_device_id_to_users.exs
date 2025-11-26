defmodule GameServer.Repo.Migrations.AddDeviceIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :device_id, :string
    end

    create unique_index(:users, [:device_id], where: "device_id IS NOT NULL")
  end
end
