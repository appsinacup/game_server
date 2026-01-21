defmodule GameServer.Repo.Migrations.AddLobbyIdToKvEntries do
  use Ecto.Migration

  def change do
    alter table(:kv_entries) do
      add :lobby_id, references(:lobbies, on_delete: :delete_all)
    end

    create index(:kv_entries, [:lobby_id])

    # Replace the global unique key constraint to ignore lobby-scoped entries.
    drop_if_exists index(:kv_entries, [:key], name: :kv_entries_unique_key_user_null)

    create unique_index(:kv_entries, [:key],
             where: "user_id IS NULL AND lobby_id IS NULL",
             name: :kv_entries_unique_key_user_null
           )

    # Per-user uniqueness (only when lobby_id is NULL).
    drop_if_exists index(:kv_entries, [:user_id, :key],
                     name: :kv_entries_unique_user_key_user_present
                   )

    create unique_index(:kv_entries, [:user_id, :key],
             where: "user_id IS NOT NULL AND lobby_id IS NULL",
             name: :kv_entries_unique_user_key_user_present
           )

    # Per-lobby uniqueness (only when user_id is NULL).
    create unique_index(:kv_entries, [:lobby_id, :key],
             where: "lobby_id IS NOT NULL AND user_id IS NULL",
             name: :kv_entries_unique_lobby_key_lobby_present
           )

    # Per-user + per-lobby uniqueness (both set).
    create unique_index(:kv_entries, [:user_id, :lobby_id, :key],
             where: "user_id IS NOT NULL AND lobby_id IS NOT NULL",
             name: :kv_entries_unique_user_lobby_key_present
           )
  end
end
