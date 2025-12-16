defmodule GameServer.Schedule.Lock do
  @moduledoc """
  Schema for schedule job locks.

  Used to ensure only one instance executes a scheduled job
  in a distributed environment.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "schedule_locks" do
    field :job_name, :string
    field :period_key, :string
    field :executed_at, :utc_datetime
  end

  @doc false
  def changeset(lock, attrs) do
    lock
    |> cast(attrs, [:job_name, :period_key, :executed_at])
    |> validate_required([:job_name, :period_key])
    |> unique_constraint([:job_name, :period_key])
  end
end
