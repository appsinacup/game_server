defmodule GameServer.Repo.Migrations.AddScheduleLocks do
  use Ecto.Migration

  def change do
    create table(:schedule_locks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :job_name, :string, null: false
      add :period_key, :string, null: false
      add :executed_at, :utc_datetime, null: false
    end

    create unique_index(:schedule_locks, [:job_name, :period_key])
  end
end
