defmodule GameServer.Repo.Migrations.CreateLobbiesAndLobbyUsers do
  use Ecto.Migration

  def change do
    create table(:lobbies) do
      add :title, :string, null: true
      add :host_id, references(:users, on_delete: :nilify_all)
      add :hostless, :boolean, default: false, null: false
      add :max_users, :integer, default: 8, null: false
      add :is_hidden, :boolean, default: false, null: false
      add :is_locked, :boolean, default: false, null: false
      add :password_hash, :string
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:lobbies, [:title])
    create index(:lobbies, [:host_id])
    create index(:lobbies, [:is_hidden])
  end
end
