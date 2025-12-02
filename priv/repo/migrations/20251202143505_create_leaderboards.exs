defmodule GameServer.Repo.Migrations.CreateLeaderboards do
  use Ecto.Migration

  def change do
    create table(:leaderboards) do
      add :slug, :string, null: false
      add :title, :string, null: false
      add :description, :string
      add :sort_order, :string, null: false, default: "desc"
      add :operator, :string, null: false, default: "best"
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:leaderboards, [:slug])
    create index(:leaderboards, [:ends_at])

    create table(:leaderboard_records) do
      add :leaderboard_id, references(:leaderboards, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :score, :bigint, null: false, default: 0
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:leaderboard_records, [:leaderboard_id, :user_id])
    create index(:leaderboard_records, [:leaderboard_id, :score])
  end
end
