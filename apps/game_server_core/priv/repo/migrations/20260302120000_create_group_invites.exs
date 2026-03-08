defmodule GameServer.Repo.Migrations.CreateGroupInvites do
  use Ecto.Migration

  def change do
    create table(:group_invites) do
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :sender_id, references(:users, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:group_invites, [:group_id])
    create index(:group_invites, [:sender_id])
    create index(:group_invites, [:recipient_id])

    create unique_index(:group_invites, [:recipient_id, :group_id],
             name: :group_invites_recipient_id_group_id_index
           )
  end
end
