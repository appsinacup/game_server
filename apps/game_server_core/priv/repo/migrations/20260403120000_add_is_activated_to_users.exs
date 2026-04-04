defmodule GameServer.Repo.Migrations.AddIsActivatedToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_activated, :boolean, default: true, null: false
    end
  end
end
