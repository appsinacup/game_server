defmodule GameServer.Repo.Migrations.AddAdminAndMetadataToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_admin, :boolean, default: false, null: false
      add :metadata, :map, default: %{}, null: false
    end
  end
end
