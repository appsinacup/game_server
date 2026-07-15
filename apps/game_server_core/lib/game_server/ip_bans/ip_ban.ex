defmodule GameServer.IpBans.IpBan do
  @moduledoc """
  A persisted IP ban. `expires_at` is `nil` for permanent bans.
  """

  use GameServer.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          ip: String.t() | nil,
          expires_at: DateTime.t() | nil
        }

  schema "ip_bans" do
    field :ip, :string
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ip_ban, attrs) do
    ip_ban
    |> cast(attrs, [:ip, :expires_at])
    |> validate_required([:ip])
    |> validate_length(:ip, max: 64)
    |> unique_constraint(:ip)
  end
end
