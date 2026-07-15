defmodule GameServer.UUIDv7 do
  @moduledoc """
  UUIDv7 Ecto type used for all primary and foreign keys.

  UUIDv7 embeds a 48-bit unix-millisecond timestamp in the most significant
  bits, so freshly inserted rows sort (and index) in insertion order like the
  old integer ids did, while remaining unguessable — random ids prevent
  enumeration of API resources.

  Cast/dump/load are delegated to `Ecto.UUID`, so storage behavior matches
  `:binary_id` on both SQLite and Postgres; only generation differs (v7
  instead of v4).
  """

  use Ecto.Type
  import Bitwise

  @impl true
  def type, do: Ecto.UUID.type()

  @impl true
  defdelegate cast(value), to: Ecto.UUID

  @impl true
  defdelegate load(value), to: Ecto.UUID

  @impl true
  defdelegate dump(value), to: Ecto.UUID

  @impl true
  def autogenerate, do: generate()

  @impl true
  def embed_as(format), do: Ecto.UUID.embed_as(format)

  @impl true
  def equal?(a, b), do: Ecto.UUID.equal?(a, b)

  @doc """
  Generates a UUIDv7 string (time-ordered, RFC 9562).

  Uses the 12 `rand_a` bits as a per-millisecond sequence counter (RFC 9562
  §6.2 method 1) so ids generated on the same node within one millisecond
  still sort in generation order — code that orders by id (chat cursors,
  pagination) keeps working under bursts.
  """
  @spec generate() :: Ecto.UUID.t()
  def generate do
    <<_::10, rand_b::62>> = :crypto.strong_rand_bytes(9)
    {ms, seq} = next_ms_and_seq()
    raw = <<ms::48, 7::4, seq::12, 2::2, rand_b::62>>
    Ecto.UUID.load!(raw)
  end

  # Packs {ms, 12-bit seq} into one atomic integer (ms <<< 12 ||| seq) and
  # advances it with a CAS loop: same-ms calls increment seq; a seq overflow
  # borrows the next millisecond, preserving strict monotonicity per node.
  defp next_ms_and_seq do
    ref = seq_atomic()
    now = System.system_time(:millisecond)
    prev = :atomics.get(ref, 1)
    candidate = max(now <<< 12, prev + 1)

    case :atomics.compare_exchange(ref, 1, prev, candidate) do
      :ok -> {candidate >>> 12, candidate &&& 0xFFF}
      _actual -> next_ms_and_seq()
    end
  end

  defp seq_atomic do
    case :persistent_term.get({__MODULE__, :seq}, nil) do
      nil ->
        ref = :atomics.new(1, signed: false)
        :persistent_term.put({__MODULE__, :seq}, ref)
        :persistent_term.get({__MODULE__, :seq})

      ref ->
        ref
    end
  end

  @doc """
  Casts a value to a UUID string, returning `nil` when invalid.

  Convenience for boundary code (channel topics, URL params) that previously
  used `Integer.parse/1` to validate ids.
  """
  @spec cast_or_nil(term()) :: Ecto.UUID.t() | nil
  def cast_or_nil(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end
end
