defmodule GameServer.Repo.Migrations.CreateOauthSessions do
  use Ecto.Migration

  def change do
    create table(:oauth_sessions) do
      add :session_id, :string, null: false
      add :provider, :string
      add :status, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:oauth_sessions, [:session_id])
  end
end
