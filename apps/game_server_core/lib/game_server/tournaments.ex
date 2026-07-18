defmodule GameServer.Tournaments do
  @moduledoc """
  Bracket tournaments: registration → seeded single-elimination draw → timed
  rounds → champions. See TOURNAMENT_DESIGN.md.

  Core owns the structure (registration, seeding, rounds, deadlines,
  advancement, recurrence). Gameplay and judgment belong to the game: when a
  match becomes playable the `tournament_match_ready` hook fires, the game
  plays it however it wants (a lobby, solo runs, anything) and reports the
  verdict with `resolve_match/2`. Unresolved matches past their deadline fire
  `tournament_match_expired` for the game to adjudicate; the tournament's
  `deadline_policy` applies only if it doesn't.

  Realtime: entry leaders receive `{:tournament_event, event, payload}` on the
  `"tournaments:user:<user_id>"` PubSub topic (forwarded by the user channel
  as `tournament_*` events).
  """

  import Bitwise
  import Ecto.Query, warn: false
  require Logger

  alias GameServer.Accounts.User
  alias GameServer.Repo
  alias GameServer.Tournaments.Bracket
  alias GameServer.Tournaments.Entry
  alias GameServer.Tournaments.Match
  alias GameServer.Tournaments.Tournament

  alias Crontab.CronExpression.Parser, as: CronParser
  alias Crontab.Scheduler, as: CronScheduler

  @pubsub GameServer.PubSub

  # ── CRUD (admin / hooks) ──────────────────────────────────────────────────

  @spec create_tournament(map()) :: {:ok, Tournament.t()} | {:error, Ecto.Changeset.t()}
  def create_tournament(attrs) do
    %Tournament{}
    |> Tournament.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_tournament(Tournament.t(), map()) ::
          {:ok, Tournament.t()} | {:error, Ecto.Changeset.t()}
  def update_tournament(%Tournament{} = tournament, attrs) do
    tournament
    |> Tournament.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_tournament(Tournament.t()) :: {:ok, Tournament.t()} | {:error, term()}
  def delete_tournament(%Tournament{} = tournament), do: Repo.delete(tournament)

  @doc "Cancels a tournament (terminal, no hooks fired, no recurrence spawn)."
  @spec cancel_tournament(Tournament.t()) :: {:ok, Tournament.t()} | {:error, term()}
  def cancel_tournament(%Tournament{} = tournament) do
    with {:ok, cancelled} <- update_state(tournament, "cancelled") do
      broadcast_tournament(cancelled, "tournament_updated")
      {:ok, cancelled}
    end
  end

  @spec change_tournament(Tournament.t(), map()) :: Ecto.Changeset.t()
  def change_tournament(%Tournament{} = tournament, attrs \\ %{}),
    do: Tournament.changeset(tournament, attrs)

  @spec get_tournament(Ecto.UUID.t()) :: Tournament.t() | nil
  def get_tournament(id) when is_binary(id), do: Repo.get(Tournament, id)

  @spec get_tournament!(Ecto.UUID.t()) :: Tournament.t()
  def get_tournament!(id) when is_binary(id), do: Repo.get!(Tournament, id)

  @doc """
  The current occurrence for a slug: the latest one that is not finished or
  cancelled, falling back to the most recent row.
  """
  @spec get_tournament_by_slug(String.t()) :: Tournament.t() | nil
  def get_tournament_by_slug(slug) when is_binary(slug) do
    from(t in Tournament,
      where: t.slug == ^slug,
      order_by: [
        asc: fragment("CASE WHEN ? IN ('finished','cancelled') THEN 1 ELSE 0 END", t.state),
        desc: t.starts_at,
        desc: t.id
      ],
      limit: 1
    )
    |> Repo.one()
  end

  @spec list_tournaments(keyword()) :: [Tournament.t()]
  def list_tournaments(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = min(Keyword.get(opts, :page_size, 25), 100)

    base_tournaments_query(opts)
    |> order_by([t], desc: t.starts_at, desc: t.id)
    |> limit(^page_size)
    |> offset(^(max(page - 1, 0) * page_size))
    |> Repo.all()
  end

  @spec count_tournaments(keyword()) :: non_neg_integer()
  def count_tournaments(opts \\ []) do
    base_tournaments_query(opts) |> Repo.aggregate(:count) || 0
  end

  defp base_tournaments_query(opts) do
    Tournament
    |> maybe_filter(:state, Keyword.get(opts, :state))
    |> maybe_filter(:category, Keyword.get(opts, :category))
    |> maybe_filter(:slug, Keyword.get(opts, :slug))
  end

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, field, value), do: where(query, [t], field(t, ^field) == ^value)

  # ── Registration ──────────────────────────────────────────────────────────

  @doc """
  Registers `user` as an entry leader. Runs the `before_tournament_register`
  pipeline (games gate/charge entry there) and fires
  `after_tournament_register` on success.
  """
  @spec join_tournament(User.t(), Tournament.t()) ::
          {:ok, Entry.t()} | {:error, term()}
  def join_tournament(%User{} = user, %Tournament{} = tournament) do
    tournament = advance_lifecycle(tournament)

    cond do
      tournament.state != "registration" ->
        {:error, :registration_closed}

      get_entry(tournament.id, user.id) != nil ->
        {:error, :already_registered}

      tournament.max_entries != nil and count_entries(tournament.id) >= tournament.max_entries ->
        {:error, :tournament_full}

      true ->
        with {:ok, _} <-
               GameServer.Hooks.internal_call(:before_tournament_register, [user, tournament]),
             {:ok, entry} <- insert_entry(tournament, user) do
          GameServer.Async.run(fn ->
            GameServer.Hooks.internal_call(:after_tournament_register, [user, tournament])
          end)

          broadcast_tournament(tournament, "tournament_updated")
          {:ok, entry}
        end
    end
  end

  defp insert_entry(tournament, user) do
    %Entry{}
    |> Entry.changeset(%{tournament_id: tournament.id, leader_id: user.id})
    |> Repo.insert()
    |> case do
      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if Keyword.has_key?(errors, :tournament_id),
          do: {:error, :already_registered},
          else: {:error, changeset}

      ok ->
        ok
    end
  end

  @doc "Withdraws `user`'s entry. Only before the draw; `before_tournament_leave` can veto."
  @spec leave_tournament(User.t(), Tournament.t()) :: {:ok, Tournament.t()} | {:error, term()}
  def leave_tournament(%User{} = user, %Tournament{} = tournament) do
    tournament = advance_lifecycle(tournament)
    entry = get_entry(tournament.id, user.id)

    cond do
      entry == nil ->
        {:error, :not_registered}

      tournament.state not in ["scheduled", "registration"] ->
        {:error, :already_drawn}

      true ->
        with {:ok, _} <-
               GameServer.Hooks.internal_call(:before_tournament_leave, [user, tournament]) do
          {:ok, _} = Repo.delete(entry)
          broadcast_tournament(tournament, "tournament_updated")
          {:ok, tournament}
        end
    end
  end

  @spec get_entry(Ecto.UUID.t(), Ecto.UUID.t()) :: Entry.t() | nil
  def get_entry(tournament_id, leader_id) do
    Repo.get_by(Entry, tournament_id: tournament_id, leader_id: leader_id)
  end

  @spec list_entries(Ecto.UUID.t()) :: [Entry.t()]
  def list_entries(tournament_id) do
    from(e in Entry, where: e.tournament_id == ^tournament_id, order_by: [asc: e.inserted_at])
    |> Repo.all()
  end

  @spec count_entries(Ecto.UUID.t()) :: non_neg_integer()
  def count_entries(tournament_id) do
    from(e in Entry, where: e.tournament_id == ^tournament_id) |> Repo.aggregate(:count)
  end

  # ── Lifecycle ─────────────────────────────────────────────────────────────

  @doc """
  Applies any due state transition to one tournament and returns the current
  row. Called lazily from API paths and periodically from `tick/0`.
  """
  @spec advance_lifecycle(Tournament.t(), DateTime.t()) :: Tournament.t()
  def advance_lifecycle(%Tournament{} = tournament, now \\ DateTime.utc_now()) do
    case tournament.state do
      "scheduled" ->
        if past?(tournament.registration_opens_at, now) do
          case update_state(tournament, "registration") do
            {:ok, t} ->
              broadcast_tournament(t, "tournament_updated")
              advance_lifecycle(t, now)

            _ ->
              tournament
          end
        else
          tournament
        end

      "registration" ->
        if past?(tournament.starts_at, now), do: draw(tournament, now), else: tournament

      "running" ->
        cond do
          all_brackets_decided?(tournament) ->
            finish_tournament(tournament)

          tournament.ends_at != nil and past?(tournament.ends_at, now) ->
            finish_tournament(tournament)

          true ->
            tournament
        end

      _terminal ->
        tournament
    end
  end

  # nil registration_opens_at = registration opens as soon as the row exists
  defp past?(nil, _now), do: true
  defp past?(%DateTime{} = at, now), do: DateTime.compare(at, now) != :gt

  defp update_state(tournament, state) do
    tournament |> Ecto.Changeset.change(state: state) |> Repo.update()
  end

  @doc """
  Periodic driver, called by `GameServer.Tournaments.Ticker`. Runs every
  transition, match-ready firing, deadline sweep, and recurrence spawn that is
  due. Serialized cluster-wide so hooks fire once.
  """
  @spec tick(DateTime.t()) :: :ok
  def tick(now \\ DateTime.utc_now()) do
    GameServer.Lock.serialize(:tournaments_tick, "global", fn ->
      from(t in Tournament, where: t.state in ["scheduled", "registration", "running"])
      |> Repo.all()
      |> Enum.each(fn tournament ->
        tournament = advance_lifecycle(tournament, now)

        if tournament.state == "running" do
          fire_due_readies(tournament, now)
          sweep_deadlines(tournament, now)
        end
      end)

      spawn_missed_recurrences(now)
    end)

    :ok
  end

  # ── Draw ──────────────────────────────────────────────────────────────────

  defp draw(%Tournament{} = tournament, now) do
    GameServer.Lock.serialize(:tournament_draw, tournament.id, fn ->
      # Re-read inside the lock: a concurrent caller must not draw twice.
      case Repo.get(Tournament, tournament.id) do
        %Tournament{state: "registration"} = tournament ->
          {:ok, tournament} = Repo.transaction(fn -> do_draw(tournament, now) end)
          after_draw(tournament, now)
          tournament

        other ->
          other || tournament
      end
    end)
    |> case do
      {:ok, %Tournament{} = t} -> t
      _ -> Repo.get(Tournament, tournament.id) || tournament
    end
  end

  defp do_draw(tournament, now) do
    entries =
      from(e in Entry,
        where: e.tournament_id == ^tournament.id and e.state == "registered",
        order_by: [asc: e.inserted_at, asc: e.id]
      )
      |> Repo.all()

    if length(entries) < 2 do
      # Nothing to play: a lone entry wins uncontested, an empty field just ends.
      Enum.each(entries, fn entry -> update_entry(entry, %{state: "winner"}) end)
      {:ok, tournament} = update_state(tournament, "finished")
      tournament
    else
      entries
      |> Enum.chunk_every(tournament.bracket_size)
      |> Enum.with_index()
      |> Enum.each(fn {chunk, bracket_index} ->
        draw_bracket(tournament, chunk, bracket_index, now)
      end)

      {:ok, tournament} = update_state(tournament, "running")
      tournament
    end
  end

  defp draw_bracket(tournament, chunk, bracket_index, _now) do
    size = bracket_size_for(length(chunk), tournament.bracket_size)
    order = standard_seed_order(size)

    {:ok, _} =
      %Bracket{}
      |> Bracket.changeset(%{tournament_id: tournament.id, index: bracket_index, size: size})
      |> Repo.insert()

    # Registration order is seed rank; `order` maps rank to slot.
    chunk
    |> Enum.with_index()
    |> Enum.each(fn {entry, rank} ->
      slot = Enum.find_index(order, &(&1 == rank + 1))
      update_entry(entry, %{seed: slot, bracket_index: bracket_index, state: "active"})
    end)

    occupant = fn slot ->
      case Enum.at(order, slot) do
        nil -> nil
        rank -> Enum.at(chunk, rank - 1)
      end
    end

    for round <- 1..bracket_rounds(size), slot <- 0..(round_matches(size, round) - 1) do
      {a, b} = if round == 1, do: {occupant.(2 * slot), occupant.(2 * slot + 1)}, else: {nil, nil}

      {:ok, _} =
        %Match{}
        |> Match.changeset(%{
          tournament_id: tournament.id,
          bracket_index: bracket_index,
          round: round,
          slot: slot,
          a_entry_id: a && a.id,
          b_entry_id: b && b.id,
          deadline: round_deadline(tournament, round)
        })
        |> Repo.insert()
    end
  end

  defp after_draw(%Tournament{state: "running"} = tournament, now) do
    broadcast_tournament(tournament, "tournament_updated")

    from(m in Match, where: m.tournament_id == ^tournament.id and m.round == 1)
    |> Repo.all()
    |> Enum.each(fn match ->
      resolve_round1_bye(tournament, match)
    end)

    fire_due_readies(tournament, now)
  end

  defp after_draw(%Tournament{state: "finished"} = tournament, _now) do
    do_finish_side_effects(tournament)
  end

  defp after_draw(_tournament, _now), do: :ok

  defp resolve_round1_bye(tournament, match) do
    case {match.a_entry_id, match.b_entry_id} do
      {nil, nil} -> internal_resolve(tournament, match, :no_winner, %{"bye" => true})
      {a, nil} -> internal_resolve(tournament, match, a, %{"bye" => true})
      {nil, b} -> internal_resolve(tournament, match, b, %{"bye" => true})
      _ -> :ok
    end
  end

  @doc "Unix-independent deadline for `round`, anchored to `starts_at`."
  @spec round_deadline(Tournament.t(), pos_integer()) :: DateTime.t()
  def round_deadline(%Tournament{} = tournament, round) do
    DateTime.add(tournament.starts_at, round * tournament.round_window_sec, :second)
  end

  @doc "When `round` becomes playable (its window start)."
  @spec round_opens_at(Tournament.t(), pos_integer()) :: DateTime.t()
  def round_opens_at(%Tournament{} = tournament, round) do
    DateTime.add(tournament.starts_at, (round - 1) * tournament.round_window_sec, :second)
  end

  # ── Match readiness ───────────────────────────────────────────────────────

  defp fire_due_readies(tournament, now) do
    from(m in Match,
      where:
        m.tournament_id == ^tournament.id and is_nil(m.resolved_at) and is_nil(m.ready_at) and
          not is_nil(m.a_entry_id) and not is_nil(m.b_entry_id)
    )
    |> Repo.all()
    |> Enum.each(&maybe_fire_ready(tournament, &1, now))
  end

  defp maybe_fire_ready(tournament, match, now) do
    window_open? = DateTime.compare(round_opens_at(tournament, match.round), now) != :gt

    if window_open? and match.ready_at == nil and match.resolved_at == nil and
         match.a_entry_id != nil and match.b_entry_id != nil do
      case match |> Match.changeset(%{ready_at: now}) |> Repo.update() do
        {:ok, match} ->
          payload = match_payload(tournament, match)

          GameServer.Async.run(fn ->
            GameServer.Hooks.internal_call(:tournament_match_ready, [payload])
          end)

          broadcast_match(tournament, match, "tournament_match_ready")

        _ ->
          :ok
      end
    end

    :ok
  end

  # ── Resolution ────────────────────────────────────────────────────────────

  @doc """
  Records the verdict for a match: the winning entry's id, or `:no_winner`
  (double forfeit — the next round's seat stays empty and cascades as a bye).

  First write wins; anything later returns `{:error, :already_resolved}`. The
  `before_tournament_result` pipeline can veto, leaving the match open.
  """
  @spec resolve_match(Ecto.UUID.t(), Ecto.UUID.t() | :no_winner) ::
          {:ok, Match.t()} | {:error, term()}
  def resolve_match(match_id, winner) when is_binary(match_id) do
    with %Match{} = match <- Repo.get(Match, match_id) || {:error, :not_found},
         %Tournament{} = tournament <- Repo.get(Tournament, match.tournament_id),
         :ok <- validate_resolution(match, winner),
         {:ok, _} <-
           GameServer.Hooks.internal_call(:before_tournament_result, [
             match_payload(tournament, match),
             winner
           ]) do
      internal_resolve(tournament, match, winner, %{})
    else
      {:error, _} = err -> err
      nil -> {:error, :not_found}
    end
  end

  defp validate_resolution(%Match{resolved_at: %DateTime{}}, _winner),
    do: {:error, :already_resolved}

  defp validate_resolution(_match, :no_winner), do: :ok

  defp validate_resolution(%Match{} = match, winner) when is_binary(winner) do
    if winner in Enum.filter([match.a_entry_id, match.b_entry_id], &is_binary/1),
      do: :ok,
      else: {:error, :invalid_winner}
  end

  defp validate_resolution(_match, _winner), do: {:error, :invalid_winner}

  # Writes the verdict and advances the bracket. Serialized per match so a
  # concurrent resolve can't double-write; re-reads inside the lock.
  defp internal_resolve(tournament, match, winner, extra_metadata) do
    GameServer.Lock.serialize(:tournament_match, match.id, fn ->
      case Repo.get(Match, match.id) do
        %Match{resolved_at: nil} = match -> do_resolve(tournament, match, winner, extra_metadata)
        %Match{} -> {:error, :already_resolved}
        nil -> {:error, :not_found}
      end
    end)
    |> case do
      {:ok, inner} -> inner
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_resolve(tournament, match, winner, extra_metadata) do
    winner_id = if winner == :no_winner, do: nil, else: winner
    now = DateTime.utc_now()

    {:ok, match} =
      Repo.transaction(fn ->
        {:ok, match} =
          match
          |> Match.changeset(%{
            winner_entry_id: winner_id,
            resolved_at: now,
            metadata: Map.merge(match.metadata || %{}, extra_metadata)
          })
          |> Repo.update()

        update_resolved_entries(tournament, match)
        advance_winner(tournament, match)
        match
      end)

    unless extra_metadata["bye"] do
      payload = match_payload(tournament, match)

      GameServer.Async.run(fn ->
        GameServer.Hooks.internal_call(:after_tournament_match, [payload])
      end)
    end

    broadcast_match(tournament, match, "tournament_match_resolved")

    # Champion decided / brackets emptied out? Close the tournament.
    _ = advance_lifecycle(tournament)

    {:ok, match}
  end

  defp update_resolved_entries(tournament, match) do
    final_round? = final_round?(tournament, match)

    for entry_id <- [match.a_entry_id, match.b_entry_id], entry_id != nil do
      entry = Repo.get(Entry, entry_id)

      cond do
        entry == nil ->
          :ok

        entry.id == match.winner_entry_id ->
          update_entry(entry, %{
            wins: entry.wins + 1,
            state: if(final_round?, do: "winner", else: entry.state)
          })

        true ->
          update_entry(entry, %{state: "eliminated"})
      end
    end
  end

  defp advance_winner(tournament, match) do
    unless final_round?(tournament, match) do
      next_slot = div(match.slot, 2)

      next =
        Repo.get_by(Match,
          tournament_id: match.tournament_id,
          bracket_index: match.bracket_index,
          round: match.round + 1,
          slot: next_slot
        )

      if next && next.resolved_at == nil do
        side = if rem(match.slot, 2) == 0, do: :a_entry_id, else: :b_entry_id
        {:ok, next} = next |> Match.changeset(%{side => match.winner_entry_id}) |> Repo.update()

        maybe_bye_resolve(tournament, next)
      end
    end

    :ok
  end

  # A nil side is settled when its feeder match is resolved (round-1 nil sides
  # are settled by definition). One settled-nil side = bye; two = cascade.
  defp maybe_bye_resolve(tournament, match) do
    a_settled = match.a_entry_id != nil or feeder_resolved?(match, 0)
    b_settled = match.b_entry_id != nil or feeder_resolved?(match, 1)

    if a_settled and b_settled do
      case {match.a_entry_id, match.b_entry_id} do
        {nil, nil} ->
          internal_resolve(tournament, match, :no_winner, %{"bye" => true})

        {a, nil} ->
          internal_resolve(tournament, match, a, %{"bye" => true})

        {nil, b} ->
          internal_resolve(tournament, match, b, %{"bye" => true})

        _both ->
          maybe_fire_ready(tournament, match, DateTime.utc_now())
      end
    end

    :ok
  end

  defp feeder_resolved?(%Match{round: 1}, _side), do: true

  defp feeder_resolved?(match, side) do
    feeder =
      Repo.get_by(Match,
        tournament_id: match.tournament_id,
        bracket_index: match.bracket_index,
        round: match.round - 1,
        slot: 2 * match.slot + side
      )

    feeder != nil and feeder.resolved_at != nil
  end

  defp final_round?(tournament, match) do
    case Repo.get_by(Bracket, tournament_id: tournament.id, index: match.bracket_index) do
      nil -> false
      bracket -> match.round >= bracket_rounds(bracket.size)
    end
  end

  @doc """
  Deep-merges `map` into the match's metadata (game scratch space).

  Serialized per match and merged recursively so concurrent writers touching
  different nested keys (e.g. each player's run under `"runs"`) never clobber
  each other.
  """
  @spec update_match_metadata(Ecto.UUID.t(), map()) :: {:ok, Match.t()} | {:error, term()}
  def update_match_metadata(match_id, map) when is_binary(match_id) and is_map(map) do
    GameServer.Lock.serialize(:tournament_match, match_id, fn ->
      case Repo.get(Match, match_id) do
        nil ->
          {:error, :not_found}

        match ->
          match
          |> Match.changeset(%{metadata: deep_merge(match.metadata || %{}, map)})
          |> Repo.update()
      end
    end)
    |> case do
      {:ok, inner} -> inner
      {:error, reason} -> {:error, reason}
    end
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, l, r -> deep_merge(l, r) end)
  end

  defp deep_merge(_left, right), do: right

  # ── Deadlines ─────────────────────────────────────────────────────────────

  # Two-phase: first tick past the deadline fires tournament_match_expired
  # (the game adjudicates); a later tick applies deadline_policy if the match
  # is still open.
  defp sweep_deadlines(tournament, now) do
    from(m in Match,
      where: m.tournament_id == ^tournament.id and is_nil(m.resolved_at) and m.deadline < ^now
    )
    |> Repo.all()
    |> Enum.each(&sweep_deadline_match(tournament, &1, now))
  end

  defp sweep_deadline_match(tournament, match, now) do
    cond do
      match.expired_at == nil -> mark_expired(tournament, match, now)
      DateTime.compare(match.expired_at, now) == :lt -> apply_deadline_policy(tournament, match)
      true -> :ok
    end
  end

  defp mark_expired(tournament, match, now) do
    case match |> Match.changeset(%{expired_at: now}) |> Repo.update() do
      {:ok, match} ->
        payload = match_payload(tournament, match)

        GameServer.Async.run(fn ->
          GameServer.Hooks.internal_call(:tournament_match_expired, [payload])
        end)

      _ ->
        :ok
    end
  end

  defp apply_deadline_policy(tournament, match) do
    present = Enum.filter([match.a_entry_id, match.b_entry_id], & &1)

    verdict =
      case {tournament.deadline_policy, present} do
        {_policy, []} -> :no_winner
        {"forfeit_both", _} -> :no_winner
        {"advance_first_slot", [first | _]} -> first
        {"random", present} -> Enum.random(present)
      end

    internal_resolve(tournament, match, verdict, %{"deadline_policy" => true})
  end

  # ── Finish & standings ────────────────────────────────────────────────────

  defp all_brackets_decided?(tournament) do
    open =
      from(m in Match, where: m.tournament_id == ^tournament.id and is_nil(m.resolved_at))
      |> Repo.aggregate(:count)

    brackets =
      from(b in Bracket, where: b.tournament_id == ^tournament.id) |> Repo.aggregate(:count)

    brackets > 0 and open == 0
  end

  defp finish_tournament(%Tournament{state: "running"} = tournament) do
    case update_state(tournament, "finished") do
      {:ok, tournament} ->
        do_finish_side_effects(tournament)
        tournament

      _ ->
        tournament
    end
  end

  defp finish_tournament(tournament), do: tournament

  defp do_finish_side_effects(tournament) do
    standings = standings(tournament)

    GameServer.Async.run(fn ->
      GameServer.Hooks.internal_call(:after_tournament_finished, [tournament, standings])
    end)

    broadcast_tournament(tournament, "tournament_finished")
    spawn_next_occurrence(tournament)
  end

  @doc "Final (or current) placements: champions first, then by wins."
  @spec standings(Tournament.t()) :: map()
  def standings(%Tournament{} = tournament) do
    entries =
      list_entries(tournament.id)
      |> Enum.sort_by(fn e -> {if(e.state == "winner", do: 0, else: 1), -e.wins} end)

    %{
      champions: Enum.filter(entries, &(&1.state == "winner")),
      entries:
        entries
        |> Enum.with_index(1)
        |> Enum.map(fn {e, placement} ->
          %{
            entry_id: e.id,
            leader_id: e.leader_id,
            wins: e.wins,
            state: e.state,
            bracket_index: e.bracket_index,
            placement: placement
          }
        end)
    }
  end

  # ── Recurrence ────────────────────────────────────────────────────────────

  # Next occurrence: same slug/config, windows shifted to the next cron
  # occurrence of starts_at after now.
  defp spawn_next_occurrence(%Tournament{recur: recur} = tournament)
       when is_binary(recur) and recur != "" do
    with {:ok, cron} <- CronParser.parse(recur),
         false <- future_occurrence_exists?(tournament),
         {:ok, next_naive} <-
           CronScheduler.get_next_run_date(cron, NaiveDateTime.utc_now()) do
      next_starts = DateTime.from_naive!(next_naive, "Etc/UTC") |> DateTime.truncate(:second)

      reg_lead =
        case tournament.registration_opens_at do
          nil -> nil
          reg -> DateTime.diff(tournament.starts_at, reg, :second)
        end

      span =
        case tournament.ends_at do
          nil -> nil
          ends -> DateTime.diff(ends, tournament.starts_at, :second)
        end

      attrs = %{
        slug: tournament.slug,
        title: tournament.title,
        description: tournament.description,
        category: tournament.category,
        state: "scheduled",
        registration_opens_at: reg_lead && DateTime.add(next_starts, -reg_lead, :second),
        starts_at: next_starts,
        ends_at: span && DateTime.add(next_starts, span, :second),
        recur: tournament.recur,
        max_entries: tournament.max_entries,
        team_size: tournament.team_size,
        bracket_size: tournament.bracket_size,
        round_window_sec: tournament.round_window_sec,
        deadline_policy: tournament.deadline_policy,
        metadata: tournament.metadata
      }

      case create_tournament(attrs) do
        {:ok, next} ->
          Logger.info("tournaments: spawned #{next.slug} occurrence starts_at=#{next.starts_at}")
          {:ok, next}

        {:error, reason} ->
          Logger.warning(
            "tournaments: failed to spawn #{tournament.slug} next: #{inspect(reason)}"
          )

          :ok
      end
    else
      _ -> :ok
    end
  end

  defp spawn_next_occurrence(_tournament), do: :ok

  defp future_occurrence_exists?(tournament) do
    from(t in Tournament,
      where:
        t.slug == ^tournament.slug and t.id != ^tournament.id and
          t.state in ["scheduled", "registration", "running"]
    )
    |> Repo.exists?()
  end

  # Safety net: a recurring slug whose latest occurrence is terminal (e.g. the
  # finish-time spawn failed or the node died) still gets its next occurrence.
  defp spawn_missed_recurrences(_now) do
    from(t in Tournament,
      where: not is_nil(t.recur) and t.recur != "" and t.state in ["finished", "cancelled"]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.slug)
    |> Enum.each(fn {_slug, occurrences} ->
      latest =
        occurrences
        |> Enum.sort_by(&{DateTime.to_unix(&1.starts_at), &1.id}, :desc)
        |> hd()

      unless future_occurrence_exists?(latest), do: spawn_next_occurrence(latest)
    end)
  end

  # ── Queries for API/admin ─────────────────────────────────────────────────

  @spec get_match(Ecto.UUID.t()) :: Match.t() | nil
  def get_match(match_id) when is_binary(match_id), do: Repo.get(Match, match_id)

  @spec list_brackets(Ecto.UUID.t()) :: [Bracket.t()]
  def list_brackets(tournament_id) do
    from(b in Bracket, where: b.tournament_id == ^tournament_id, order_by: [asc: b.index])
    |> Repo.all()
  end

  @spec list_matches(Ecto.UUID.t()) :: [Match.t()]
  def list_matches(tournament_id) do
    from(m in Match,
      where: m.tournament_id == ^tournament_id,
      order_by: [asc: m.bracket_index, asc: m.round, asc: m.slot]
    )
    |> Repo.all()
  end

  @doc "The caller's current unresolved match (their entry filled in a slot), if any."
  @spec my_match(Tournament.t(), Ecto.UUID.t()) :: Match.t() | nil
  def my_match(%Tournament{} = tournament, user_id) when is_binary(user_id) do
    case get_entry(tournament.id, user_id) do
      nil ->
        nil

      entry ->
        from(m in Match,
          where:
            m.tournament_id == ^tournament.id and is_nil(m.resolved_at) and
              (m.a_entry_id == ^entry.id or m.b_entry_id == ^entry.id),
          order_by: [asc: m.round],
          limit: 1
        )
        |> Repo.one()
    end
  end

  # ── Pure bracket math (ported from polyglot's Weekend Gauntlet) ───────────

  @doc "Rounds needed to win a bracket of `size` slots (2→1, 4→2, 8→3)."
  @spec bracket_rounds(pos_integer()) :: pos_integer()
  def bracket_rounds(size) when is_integer(size) and size >= 2,
    do: trunc(:math.log2(size))

  @doc "Matches in `round` of a bracket of `size` slots."
  @spec round_matches(pos_integer(), pos_integer()) :: pos_integer()
  def round_matches(size, round), do: div(size, 1 <<< round)

  @doc "The match a slot reaches in `round` (standard folding)."
  @spec match_index(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def match_index(slot, round) when is_integer(slot) and is_integer(round),
    do: div(slot, 1 <<< round)

  @doc "Smallest power of two seating `n` entries, min 2, capped at `max`."
  @spec bracket_size_for(pos_integer(), pos_integer()) :: pos_integer()
  def bracket_size_for(n, max) when is_integer(n) and is_integer(max) do
    size = max(2, next_pow2(n))
    min(size, max)
  end

  defp next_pow2(n), do: 1 <<< ceil(:math.log2(max(n, 2)))

  @doc """
  Standard single-elimination seeding order for a power-of-two `size`:
  slot `i` holds this seed rank (1-based); top seeds are spread apart.
  """
  @spec standard_seed_order(pos_integer()) :: [pos_integer()]
  def standard_seed_order(1), do: [1]

  def standard_seed_order(size) when is_integer(size) and size > 1 do
    div(size, 2)
    |> standard_seed_order()
    |> Enum.flat_map(fn s -> [s, size + 1 - s] end)
  end

  # ── Payloads & broadcasts ─────────────────────────────────────────────────

  @doc "The match struct with tournament and both entries preloaded (hook payload)."
  @spec match_payload(Tournament.t(), Match.t()) :: Match.t()
  def match_payload(tournament, match) do
    %{match | tournament: tournament}
    |> Repo.preload([:a_entry, :b_entry])
  end

  defp broadcast_tournament(tournament, event) do
    payload = %{tournament_id: tournament.id, slug: tournament.slug, state: tournament.state}

    for %Entry{leader_id: leader_id} <- list_entries(tournament.id) do
      broadcast_user(leader_id, event, payload)
    end

    :ok
  end

  defp broadcast_match(tournament, match, event) do
    payload = %{
      tournament_id: tournament.id,
      slug: tournament.slug,
      match_id: match.id,
      round: match.round,
      deadline: match.deadline,
      winner_entry_id: match.winner_entry_id
    }

    for entry_id <- [match.a_entry_id, match.b_entry_id], entry_id != nil do
      case Repo.get(Entry, entry_id) do
        %Entry{leader_id: leader_id} -> broadcast_user(leader_id, event, payload)
        nil -> :ok
      end
    end

    :ok
  end

  defp broadcast_user(user_id, event, payload) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "tournaments:user:#{user_id}",
      {:tournament_event, event, payload}
    )
  end

  defp update_entry(entry, attrs) do
    {:ok, _} = entry |> Entry.changeset(attrs) |> Repo.update()
  end
end
