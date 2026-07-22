defmodule GameServer.Repo.Migrations.CreateInventoryItems do
  use Ecto.Migration

  def change do
    create table(:inventory_items) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :item, :string, null: false
      add :quantity, :bigint, null: false, default: 0
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:inventory_items, [:user_id, :item])
    create index(:inventory_items, [:item])
  end
end
