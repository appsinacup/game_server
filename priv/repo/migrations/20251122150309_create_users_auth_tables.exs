defmodule GameServer.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    # Only create citext extension for PostgreSQL
    if repo().__adapter__() == Ecto.Adapters.Postgres do
      execute "CREATE EXTENSION IF NOT EXISTS citext", ""
    end

    create table(:users) do
      # Use citext for PostgreSQL, string for others
      # Make email nullable for SQLite since we can't alter columns later
      add :email, if(repo().__adapter__() == Ecto.Adapters.Postgres, do: :citext, else: :string),
        null: true

      add :hashed_password, :string
      add :confirmed_at, :utc_datetime
      add :discord_id, :string
      add :apple_id, :string
      add :google_id, :string
      add :facebook_id, :string
      add :device_id, :string
      add :steam_id, :string

      add :display_name, :string
      add :profile_url, :string

      add :is_admin, :boolean, default: false, null: false
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:discord_id])
    create unique_index(:users, [:apple_id])
    create unique_index(:users, [:google_id])
    create unique_index(:users, [:facebook_id])
    create unique_index(:users, [:device_id], where: "device_id IS NOT NULL")
    create unique_index(:users, [:steam_id])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
