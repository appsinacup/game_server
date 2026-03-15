defmodule GameServer.Repo.Migrations.CreateAchievements do
  use Ecto.Migration

  def change do
    create table(:achievements) do
      add :slug, :string, null: false
      add :title, :string, null: false
      add :description, :string, default: ""
      add :icon_url, :string
      add :points, :integer, default: 0
      add :sort_order, :integer, default: 0
      add :hidden, :boolean, default: false
      add :progress_target, :integer, default: 1
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:achievements, [:slug])

    create table(:user_achievements) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :achievement_id, references(:achievements, on_delete: :delete_all), null: false
      add :progress, :integer, default: 0
      add :unlocked_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_achievements, [:user_id, :achievement_id])
    create index(:user_achievements, [:user_id])
    create index(:user_achievements, [:achievement_id])
  end
end
