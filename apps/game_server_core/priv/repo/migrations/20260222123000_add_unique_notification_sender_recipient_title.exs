defmodule GameServer.Repo.Migrations.AddUniqueNotificationSenderRecipientTitle do
  use Ecto.Migration

  def change do
    create unique_index(:notifications, [:sender_id, :recipient_id, :title])
  end
end
