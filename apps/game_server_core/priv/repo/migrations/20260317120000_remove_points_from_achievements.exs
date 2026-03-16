defmodule GameServer.Repo.Migrations.RemovePointsFromAchievements do
  use Ecto.Migration

  def change do
    alter table(:achievements) do
      remove :points, :integer, default: 0
    end
  end
end
