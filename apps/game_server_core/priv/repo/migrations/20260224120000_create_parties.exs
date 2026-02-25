defmodule GameServer.Repo.Migrations.CreateParties do
  use Ecto.Migration

  def change do
    create table(:parties) do
      add :leader_id, references(:users, on_delete: :delete_all), null: false
      add :max_size, :integer, null: false, default: 4
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:parties, [:leader_id], unique: true)

    alter table(:users) do
      add :party_id, references(:parties, on_delete: :nilify_all)
    end

    create index(:users, [:party_id])
  end
end
