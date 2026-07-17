defmodule GameServer.Repo.Migrations.AddUsernameToUsers do
  use Ecto.Migration

  import Ecto.Query

  def up do
    alter table(:users) do
      add :username, :string
    end

    create unique_index(:users, [:username])

    flush()
    backfill_usernames()

    # SQLite can't ALTER COLUMN; there the NOT NULL guarantee stays
    # app-level (username_changeset validate_required).
    if repo().__adapter__() == Ecto.Adapters.Postgres do
      execute "ALTER TABLE users ALTER COLUMN username SET NOT NULL"
    end
  end

  def down do
    alter table(:users) do
      remove :username
    end
  end

  defp backfill_usernames do
    rows =
      repo().all(
        from(u in "users", where: is_nil(u.username), select: {u.id, u.display_name}),
        log: false
      )

    Enum.each(rows, fn {id, display_name} ->
      username = free_username(%{"display_name" => display_name})

      {1, _} =
        repo().update_all(from(u in "users", where: u.id == ^id), set: [username: username])
    end)
  end

  # The migration is the only writer, so a check-then-set is race-free here.
  defp free_username(attrs, attempt \\ 1) do
    candidate = GameServer.Accounts.UsernameGenerator.generate(attrs, attempt)

    if repo().exists?(from(u in "users", where: u.username == ^candidate)) do
      free_username(attrs, attempt + 1)
    else
      candidate
    end
  end
end
