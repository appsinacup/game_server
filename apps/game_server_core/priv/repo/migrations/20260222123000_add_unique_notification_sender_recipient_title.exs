defmodule GameServer.Repo.Migrations.AddUniqueNotificationSenderRecipientTitle do
  use Ecto.Migration

  def up do
    execute("""
    DELETE FROM notifications
    WHERE id IN (
      SELECT id
      FROM (
        SELECT
          id,
          ROW_NUMBER() OVER (
            PARTITION BY sender_id, recipient_id, title
            ORDER BY inserted_at DESC, id DESC
          ) AS row_num
        FROM notifications
      ) ranked
      WHERE ranked.row_num > 1
    )
    """)

    create_if_not_exists(
      unique_index(:notifications, [:sender_id, :recipient_id, :title],
        name: :notifications_sender_id_recipient_id_title_index
      )
    )
  end

  def down do
    drop_if_exists(
      index(:notifications, [:sender_id, :recipient_id, :title],
        name: :notifications_sender_id_recipient_id_title_index
      )
    )
  end
end
