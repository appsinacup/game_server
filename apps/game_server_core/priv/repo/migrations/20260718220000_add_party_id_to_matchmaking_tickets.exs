defmodule GameServer.Repo.Migrations.AddPartyIdToMatchmakingTickets do
  use Ecto.Migration

  def change do
    alter table(:matchmaking_tickets) do
      # Nil for solo queuers. Party tickets share one id and are matched as an
      # indivisible unit; nilify_all so a disbanded party leaves its tickets
      # behind as solos rather than deleting them mid-sweep.
      add :party_id, references(:parties, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:matchmaking_tickets, [:party_id, :status])
  end
end
