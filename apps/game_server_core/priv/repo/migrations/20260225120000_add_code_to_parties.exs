defmodule GameServer.Repo.Migrations.AddCodeToParties do
  use Ecto.Migration

  def change do
    alter table(:parties) do
      add :code, :string, size: 6
    end

    create unique_index(:parties, [:code])
  end
end
