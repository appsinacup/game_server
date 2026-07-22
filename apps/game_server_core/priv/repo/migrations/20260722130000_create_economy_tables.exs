defmodule GameServer.Repo.Migrations.CreateEconomyTables do
  use Ecto.Migration

  def change do
    create table(:wallets) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :currency, :string, null: false
      add :balance, :bigint, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wallets, [:user_id, :currency])

    create table(:ledger_entries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :currency, :string, null: false
      add :delta, :bigint, null: false
      add :balance_after, :bigint, null: false
      add :reason, :string, null: false, default: "unspecified"
      add :idempotency_key, :string
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:ledger_entries, [:user_id, :currency])
    create index(:ledger_entries, [:user_id, :inserted_at])

    # A grant/spend may carry an idempotency key so retries can't double-apply.
    create unique_index(:ledger_entries, [:idempotency_key], where: "idempotency_key IS NOT NULL")
  end
end
