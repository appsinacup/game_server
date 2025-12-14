defmodule GameServer.Repo.Migrations.AddUsersTokensInsertedAtIndex do
  use Ecto.Migration

  def change do
    # Helps queries like "count users active since" which filter tokens by inserted_at
    create index(:users_tokens, [:inserted_at, :user_id])
  end
end
