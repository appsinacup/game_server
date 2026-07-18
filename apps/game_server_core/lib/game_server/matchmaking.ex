defmodule GameServer.Matchmaking do
  @moduledoc """
  Public API for the built-in matchmaking system.

  Matchmaking is ticket-based. Each call to `join/4` creates a ticket in
  the database. The periodic `GameServer.Matchmaking.Worker` groups queued
  tickets that share the same `match_params` and creates a hidden lobby
  for each match.

  Tickets are the source of truth in the database. The active queue is
  cached in `GameServer.Cache` for the duration of a worker tick.
  """

  import Ecto.Query

  alias GameServer.Accounts.User
  alias GameServer.Cache
  alias GameServer.Matchmaking.Constants
  alias GameServer.Matchmaking.Matcher
  alias GameServer.Matchmaking.Ticket
  alias GameServer.Repo

  @default_min_players 2
  @default_max_players 5
  @default_timeout_ms 30_000
  @cache_key "matchmaking:active_tickets"

  @doc """
  Adds a user to the matchmaking queue.

  `match_params` is a map of arbitrary string keys and values, for example
  `%{"mode" => "deathmatch", "map" => "dust2"}`. Only tickets with exactly
  the same parameters are matched together.

  `min_players` and `max_players` can be passed to override the defaults.
  """
  @spec join(User.t(), map(), pos_integer() | nil, pos_integer() | nil) ::
          {:ok, Ticket.t()} | {:error, Ecto.Changeset.t()}
  def join(%User{} = user, match_params, min_players \\ nil, max_players \\ nil) do
    now = DateTime.utc_now()

    attrs = %{
      user_id: user.id,
      status: Constants.status_queued(),
      match_params: normalize_params(match_params),
      min_players: min_players || @default_min_players,
      max_players: max_players || @default_max_players,
      timeout_ms: @default_timeout_ms,
      queued_at: now
    }

    %Ticket{}
    |> Ticket.changeset(attrs)
    |> Repo.insert()
    |> tap(&invalidate_cache/1)
  end

  @doc """
  Cancels all queued tickets for a user.
  """
  @spec cancel(Ecto.UUID.t()) :: :ok
  def cancel(user_id) do
    Ticket
    |> where([t], t.user_id == ^user_id and t.status == ^Constants.status_queued())
    |> Repo.update_all(set: [status: Constants.status_cancelled(), updated_at: DateTime.utc_now()])

    Cache.delete(@cache_key)
    :ok
  end

  @doc """
  Lists all queued tickets grouped by `match_params`.

  The result is cached for the duration of one worker tick to avoid
  repeated database reads.
  """
  @spec list_queued_by_params() :: %{map() => [Ticket.t()]}
  def list_queued_by_params do
    case Cache.fetch(@cache_key) do
      {:ok, grouped} ->
        grouped

      _ ->
        grouped =
          Ticket
          |> where(status: ^Constants.status_queued())
          |> order_by([t], asc: t.queued_at)
          |> preload(:user)
          |> Repo.all()
          |> Enum.group_by(& &1.match_params)

        Cache.put(@cache_key, grouped, ttl: :timer.seconds(2))
        grouped
    end
  end

  @doc """
  Marks a list of tickets as matched and associates them with a lobby.
  """
  @spec mark_matched([Ticket.t()], Ecto.UUID.t()) :: :ok
  def mark_matched(tickets, lobby_id) do
    ids = Enum.map(tickets, & &1.id)
    now = DateTime.utc_now()

    Ticket
    |> where([t], t.id in ^ids)
    |> Repo.update_all(set: [
      status: Constants.status_matched(),
      match_id: lobby_id,
      matched_at: now,
      updated_at: now
    ])

    Cache.delete(@cache_key)
    :ok
  end

  @doc """
  Cancels queued tickets for users that are no longer connected.
  Called by the worker as a safety sweep.
  """
  @spec prune_offline([Ecto.UUID.t()]) :: :ok
  def prune_offline(online_user_ids) do
    Ticket
    |> where([t], t.status == ^Constants.status_queued() and t.user_id not in ^online_user_ids)
    |> Repo.update_all(set: [status: Constants.status_cancelled(), updated_at: DateTime.utc_now()])

    Cache.delete(@cache_key)
    :ok
  end

  defp normalize_params(params) when is_map(params) do
    params
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
    |> Enum.into(%{})
  end

  defp normalize_params(_), do: %{}

  defp invalidate_cache({:ok, _}), do: Cache.delete(@cache_key)
  defp invalidate_cache({:error, _}), do: :ok
end
