defmodule GameServer.Repo.Migrations.MakeEmailNullable do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :email, :citext, null: true
    end
  end
end
