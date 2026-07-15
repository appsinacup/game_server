defmodule GameServer.Payments.ProviderEvent do
  @moduledoc """
  Dedupe record for webhook and store notification events.
  """

  use GameServer.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @providers ~w(apple google steam stripe)

  schema "provider_events" do
    field :provider, :string
    field :event_id, :string
    field :event_type, :string
    field :processed_at, :utc_datetime
    field :payload, :map, default: %{}
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:provider, :event_id, :event_type, :processed_at, :payload, :metadata])
    |> validate_required([:provider, :event_id, :event_type, :payload, :metadata])
    |> validate_inclusion(:provider, @providers)
    |> validate_length(:event_id, min: 1, max: 255)
    |> validate_length(:event_type, min: 1, max: 255)
    |> unique_constraint(:event_id, name: :provider_events_provider_event_id_index)
  end
end
