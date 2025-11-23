defmodule GameServer.Repo.Migrations.AddAppleAuthToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :apple_id, :string
    end

    create unique_index(:users, [:apple_id])
  end
end
