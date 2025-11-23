defmodule GameServer.Repo.Migrations.AddGoogleIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :google_id, :string
    end

    create unique_index(:users, [:google_id])
  end
end
