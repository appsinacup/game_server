defmodule GameServer.Repo.Migrations.AddReadToNotifications do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :read, :boolean, default: false, null: false
    end

    create index(:notifications, [:recipient_id, :read])
  end
end
