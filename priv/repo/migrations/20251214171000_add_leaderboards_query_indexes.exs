defmodule GameServer.Repo.Migrations.AddLeaderboardsQueryIndexes do
  use Ecto.Migration

  def change do
    # Speeds active/filtered leaderboard queries
    create index(:leaderboards, [:starts_at])
    create index(:leaderboards, [:slug, :ends_at])

    # Speeds record ordering by score with updated_at tie-breaker
    create index(:leaderboard_records, [:leaderboard_id, :score, :updated_at])
  end
end
