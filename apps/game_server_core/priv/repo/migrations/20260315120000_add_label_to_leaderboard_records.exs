defmodule GameServer.Repo.Migrations.AddLabelToLeaderboardRecords do
  use Ecto.Migration

  def up do
    if repo().__adapter__() == Ecto.Adapters.Postgres do
      # Postgres supports ALTER COLUMN natively
      alter table(:leaderboard_records) do
        add :label, :string
        modify :user_id, :bigint, null: true
      end
    else
      # SQLite doesn't support ALTER COLUMN, so we rebuild the table.
      execute """
      CREATE TABLE leaderboard_records_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        leaderboard_id INTEGER NOT NULL REFERENCES leaderboards(id) ON DELETE CASCADE,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        score INTEGER NOT NULL DEFAULT 0,
        metadata TEXT NOT NULL DEFAULT '{}',
        label TEXT,
        inserted_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      """

      execute """
      INSERT INTO leaderboard_records_new (id, leaderboard_id, user_id, score, metadata, inserted_at, updated_at)
      SELECT id, leaderboard_id, user_id, score, metadata, inserted_at, updated_at
      FROM leaderboard_records
      """

      execute "DROP TABLE leaderboard_records"
      execute "ALTER TABLE leaderboard_records_new RENAME TO leaderboard_records"

      # Re-create original indexes
      create unique_index(:leaderboard_records, [:leaderboard_id, :user_id])
      create index(:leaderboard_records, [:leaderboard_id, :score])
    end

    # Label uniqueness index (works on both adapters)
    create unique_index(:leaderboard_records, [:leaderboard_id, :label],
             name: :leaderboard_records_leaderboard_id_label_index
           )
  end

  def down do
    drop_if_exists index(:leaderboard_records, [:leaderboard_id, :label],
                     name: :leaderboard_records_leaderboard_id_label_index
                   )

    if repo().__adapter__() == Ecto.Adapters.Postgres do
      alter table(:leaderboard_records) do
        remove :label
        modify :user_id, :bigint, null: false
      end
    else
      execute """
      CREATE TABLE leaderboard_records_old (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        leaderboard_id INTEGER NOT NULL REFERENCES leaderboards(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        score INTEGER NOT NULL DEFAULT 0,
        metadata TEXT NOT NULL DEFAULT '{}',
        inserted_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      """

      # Only copy user-based records (label records would violate NOT NULL)
      execute """
      INSERT INTO leaderboard_records_old (id, leaderboard_id, user_id, score, metadata, inserted_at, updated_at)
      SELECT id, leaderboard_id, user_id, score, metadata, inserted_at, updated_at
      FROM leaderboard_records
      WHERE user_id IS NOT NULL
      """

      execute "DROP TABLE leaderboard_records"
      execute "ALTER TABLE leaderboard_records_old RENAME TO leaderboard_records"

      create unique_index(:leaderboard_records, [:leaderboard_id, :user_id])
      create index(:leaderboard_records, [:leaderboard_id, :score])
    end
  end
end
