defmodule GameServer.Repo.Migrations.AddFacebookIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :facebook_id, :string
    end

    create unique_index(:users, [:facebook_id])
  end
end
