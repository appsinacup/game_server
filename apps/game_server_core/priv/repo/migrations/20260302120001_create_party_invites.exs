defmodule GameServer.Repo.Migrations.CreatePartyInvites do
  use Ecto.Migration

  def change do
    create table(:party_invites) do
      add :party_id, references(:parties, on_delete: :delete_all), null: false
      add :sender_id, references(:users, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:party_invites, [:party_id])
    create index(:party_invites, [:sender_id])
    create index(:party_invites, [:recipient_id])

    create unique_index(:party_invites, [:sender_id, :recipient_id],
             name: :party_invites_sender_id_recipient_id_index
           )
  end
end
