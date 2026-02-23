defmodule GameServer.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups) do
      add :name, :string, null: false
      add :title, :string, null: false
      add :description, :string
      add :type, :string, null: false, default: "public"
      add :max_members, :integer, null: false, default: 100
      add :metadata, :map, default: %{}
      add :creator_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:groups, [:name])
    create index(:groups, [:type])
    create index(:groups, [:creator_id])

    create table(:group_members) do
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:group_members, [:group_id, :user_id])
    create index(:group_members, [:user_id])
    create index(:group_members, [:group_id])

    create table(:group_join_requests) do
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:group_join_requests, [:group_id, :user_id])
    create index(:group_join_requests, [:user_id])
    create index(:group_join_requests, [:group_id, :status])
  end
end
