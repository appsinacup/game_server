defmodule GameServer.Repo.Migrations.AddDiscordFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :discord_id, :string
      add :discord_username, :string
      add :discord_avatar, :string
    end

    create unique_index(:users, [:discord_id])
  end
end
