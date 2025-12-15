defmodule GameServer.Repo.Migrations.CreateKvEntries do
  use Ecto.Migration

  def change do
    create table(:kv_entries) do
      add :key, :string, null: false
      add :value, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:kv_entries, [:key])
  end
end
