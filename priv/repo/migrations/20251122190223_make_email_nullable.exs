defmodule GameServer.Repo.Migrations.MakeEmailNullable do
  use Ecto.Migration

  def change do
    if repo().__adapter__() == Ecto.Adapters.Postgres do
      # PostgreSQL supports ALTER COLUMN
      alter table(:users) do
        modify :email, :citext, null: true
      end
    end

    # For SQLite and other databases, email is already nullable from creation
  end
end
