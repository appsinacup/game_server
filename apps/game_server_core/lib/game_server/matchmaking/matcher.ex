defmodule GameServer.Matchmaking.Matcher do
  @moduledoc """
  Match-forming logic for a group of tickets that share the same
  `match_params`.

  A match is formed when:
    * the group has at least `min_players` tickets, and
    * the oldest ticket has waited at least `timeout_ms`, or
    * the group has reached `max_players` tickets.

  Tickets are consumed in FIFO order. A single group can produce multiple
  matches in one sweep.
  """

  alias GameServer.Types

  @doc """
  Forms all possible matches from a sorted list of tickets.

  Returns `{matches, remaining}` where `matches` is a list of ticket lists
  and `remaining` are the tickets that could not be matched yet.
  """
  @spec form_matches([Types.matchmaking_ticket()]) ::
          {[[Types.matchmaking_ticket()]], [Types.matchmaking_ticket()]}
  def form_matches(tickets) do
    tickets
    |> Enum.sort_by(& &1.queued_at)
    |> do_form_matches([], [])
  end

  defp do_form_matches([], matches, remaining), do: {Enum.reverse(matches), remaining}

  defp do_form_matches([first | _] = tickets, matches, remaining) do
    min = first.min_players
    max = first.max_players
    timeout_ms = first.timeout_ms
    elapsed = DateTime.diff(DateTime.utc_now(), first.queued_at, :millisecond)

    cond do
      length(tickets) >= min and (length(tickets) >= max or elapsed >= timeout_ms) ->
        {match, rest} = Enum.split(tickets, max)
        do_form_matches(rest, [match | matches], remaining)

      true ->
        {Enum.reverse(matches), tickets ++ remaining}
    end
  end
end
