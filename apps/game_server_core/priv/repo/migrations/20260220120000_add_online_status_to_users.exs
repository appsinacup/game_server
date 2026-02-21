defmodule GameServer.Repo.Migrations.AddOnlineStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_online, :boolean, default: false, null: false
      add :last_seen_at, :utc_datetime
    end
  end
end
