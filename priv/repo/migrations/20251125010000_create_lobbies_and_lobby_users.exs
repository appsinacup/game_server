defmodule GameServer.Repo.Migrations.CreateLobbiesAndLobbyUsers do
  use Ecto.Migration

  def change do
    create table(:lobbies) do
      add :name, :string, null: false
      add :title, :string
      add :host_id, references(:users, on_delete: :nilify_all)
      add :hostless, :boolean, default: false, null: false
      add :max_users, :integer, default: 8, null: false
      add :is_private, :boolean, default: false, null: false
      add :is_hidden, :boolean, default: false, null: false
      add :is_locked, :boolean, default: false, null: false
      add :password_hash, :string
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:lobbies, [:name])
    create index(:lobbies, [:host_id])
    create index(:lobbies, [:is_hidden])

    create table(:lobby_users) do
      add :lobby_id, references(:lobbies, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :joined_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # ensure a user can only be in one lobby at a time
    create unique_index(:lobby_users, [:user_id])
    create unique_index(:lobby_users, [:lobby_id, :user_id])
    create index(:lobby_users, [:lobby_id])
  end
end
