defmodule GameServer.Repo.Migrations.AddMissingPerformanceIndexes do
  use Ecto.Migration

  def change do
    # User presence queries: StalePresenceSweeper (every 2 min), the online
    # count, and recently-active counts otherwise full-scan the users table.
    if repo().__adapter__() == Ecto.Adapters.Postgres do
      # Partial index over only online rows serves the sweeper + online count.
      create index(:users, [:last_seen_at],
               where: "is_online = true",
               name: :users_online_last_seen_index
             )
    else
      create index(:users, [:is_online, :last_seen_at])
    end

    # Recently-active count filters on last_seen_at regardless of online state.
    create index(:users, [:last_seen_at])

    # Re-add the leaderboard ranking index dropped by the SQLite table rebuild
    # in 20260315120000 (Postgres kept it via the ALTER path). Idempotent so it
    # is a no-op where it already exists.
    create_if_not_exists index(:leaderboard_records, [:leaderboard_id, :score, :updated_at])

    # Group prefix search lowercases the column, so the plain unique_index on
    # title can't serve it — mirror the users/lobbies lower() expression index.
    create index(:groups, ["lower(title)"])

    # Notifications unread-then-newest listing (filter recipient_id + read,
    # order by inserted_at) needs all three columns in one index.
    create index(:notifications, [:recipient_id, :read, :inserted_at])
  end
end
