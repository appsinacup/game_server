defmodule GameServer.Notifications.Notification do
  @moduledoc """
  Ecto schema representing a notification sent from one user to another.

  Notifications are persisted in the database and remain until the recipient
  explicitly deletes them. Fields:

  - `sender_id` – the user who sent the notification (must be a friend)
  - `recipient_id` – the user who receives the notification
  - `title` – required short summary
  - `content` – optional longer body text
  - `metadata` – optional arbitrary key/value map
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GameServer.Accounts.User

  @derive {Jason.Encoder,
           only: [
             :id,
             :sender_id,
             :recipient_id,
             :title,
             :content,
             :metadata,
             :inserted_at
           ]}

  schema "notifications" do
    belongs_to :sender, User
    belongs_to :recipient, User

    field :title, :string
    field :content, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @typedoc "A notification record."
  @type t :: %__MODULE__{
          id: integer() | nil,
          sender_id: integer() | nil,
          recipient_id: integer() | nil,
          title: String.t() | nil,
          content: String.t() | nil,
          metadata: map(),
          inserted_at: DateTime.t() | nil
        }

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:title, :content, :metadata])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:content, max: 10_000)
  end
end
