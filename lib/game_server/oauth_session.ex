defmodule GameServer.OAuthSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "oauth_sessions" do
    field :session_id, :string
    field :provider, :string
    field :status, :string
    field :data, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:session_id, :provider, :status, :data])
    |> validate_required([:session_id])
    |> unique_constraint(:session_id)
  end
end
