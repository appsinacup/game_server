defmodule GameServer.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :content, :text, null: false
      add :metadata, :map, default: %{}, null: false
      add :sender_id, references(:users, on_delete: :delete_all), null: false
      add :chat_type, :string, null: false
      add :chat_ref_id, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:sender_id])
    create index(:chat_messages, [:chat_type, :chat_ref_id])
    create index(:chat_messages, [:chat_type, :chat_ref_id, :inserted_at])

    create table(:chat_read_cursors) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :chat_type, :string, null: false
      add :chat_ref_id, :integer, null: false
      add :last_read_message_id, references(:chat_messages, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_read_cursors, [:user_id, :chat_type, :chat_ref_id],
             name: :chat_read_cursors_user_type_ref
           )

    create index(:chat_read_cursors, [:user_id])
  end
end
