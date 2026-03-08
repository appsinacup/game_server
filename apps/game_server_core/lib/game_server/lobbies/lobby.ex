defmodule GameServer.Lobbies.Lobby do
  @moduledoc """
  Ecto schema for the `lobbies` table and changeset helpers.

  A lobby represents a game room with basic settings (title, host, capacity,
  visibility, lock/password and arbitrary metadata).
  """
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  alias GameServer.Accounts.User
  # membership via users.lobby_id

  @derive {Jason.Encoder,
           only: [
             :id,
             :title,
             :host_id,
             :hostless,
             :max_users,
             :is_hidden,
             :is_locked,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "lobbies" do
    field :title, :string
    field :hostless, :boolean, default: false
    field :max_users, :integer, default: 8
    field :is_hidden, :boolean, default: false
    field :is_locked, :boolean, default: false
    field :password_hash, :string
    field :metadata, :map, default: %{}
    field :slowdown, :integer, default: 0

    belongs_to :host, User

    has_many :memberships, User, foreign_key: :lobby_id
    has_many :users, User, foreign_key: :lobby_id

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(title)a
  @optional_fields ~w(host_id hostless max_users is_hidden is_locked password_hash metadata slowdown)a

  def changeset(lobby, attrs) do
    lobby
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:title, min: 1, max: GameServer.Limits.get(:max_lobby_title))
    |> validate_number(:max_users,
      greater_than: 0,
      less_than_or_equal_to: GameServer.Limits.get(:max_lobby_users)
    )
    |> validate_number(:slowdown, greater_than_or_equal_to: 0, less_than_or_equal_to: 3600)
    |> validate_length(:password_hash, max: 256)
    |> GameServer.Limits.validate_metadata_size(:metadata)
  end
end
