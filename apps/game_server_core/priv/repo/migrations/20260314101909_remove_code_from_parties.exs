defmodule GameServer.Repo.Migrations.RemoveCodeFromParties do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:parties, [:code])

    alter table(:parties) do
      remove :code, :string, size: 6
    end
  end
end
