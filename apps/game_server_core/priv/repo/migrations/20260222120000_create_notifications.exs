defmodule GameServer.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :sender_id, references(:users, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :content, :text
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:recipient_id])
    create index(:notifications, [:sender_id])
    create index(:notifications, [:recipient_id, :inserted_at])
  end
end
