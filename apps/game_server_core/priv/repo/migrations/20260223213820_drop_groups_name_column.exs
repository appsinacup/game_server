defmodule GameServer.Repo.Migrations.DropGroupsNameColumn do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:groups, [:name])

    alter table(:groups) do
      remove :name, :string, null: false
    end

    create_if_not_exists unique_index(:groups, [:title])
  end
end
