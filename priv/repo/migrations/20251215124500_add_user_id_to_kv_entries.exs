defmodule GameServer.Repo.Migrations.AddUserIdToKvEntries do
  use Ecto.Migration

  def change do
    alter table(:kv_entries) do
      add :user_id, references(:users, on_delete: :delete_all)
    end

    # Replace the global unique key constraint with global/per-user partial uniques.
    drop_if_exists index(:kv_entries, [:key])

    create index(:kv_entries, [:key])
    create index(:kv_entries, [:user_id])

    # Both SQLite and Postgres allow multiple NULLs in unique constraints.
    # We want global uniqueness for rows where user_id is NULL, and per-user uniqueness otherwise.
    create unique_index(:kv_entries, [:key],
             where: "user_id IS NULL",
             name: :kv_entries_unique_key_user_null
           )

    create unique_index(:kv_entries, [:user_id, :key],
             where: "user_id IS NOT NULL",
             name: :kv_entries_unique_user_key_user_present
           )
  end
end
