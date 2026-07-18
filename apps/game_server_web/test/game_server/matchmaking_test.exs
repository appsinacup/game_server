defmodule GameServer.MatchmakingTest do
  use GameServer.DataCase

  alias GameServer.AccountsFixtures
  alias GameServer.Lobbies
  alias GameServer.Matchmaking
  alias GameServer.Matchmaking.Matcher
  alias GameServer.Matchmaking.Ticket
  alias GameServer.Matchmaking.Worker

  defp user(online \\ true) do
    u = AccountsFixtures.user_fixture()
    {:ok, u} = u |> Ecto.Changeset.change(is_online: online) |> Repo.update()
    u
  end

  # Offline *and* past the prune grace period, which is what prune_offline/0
  # requires — a player who just dropped keeps their queue position.
  defp long_offline_user do
    seen =
      DateTime.utc_now()
      |> DateTime.add(-GameServer.Limits.get(:matchmaking_offline_grace_ms) - 1_000, :millisecond)
      |> DateTime.truncate(:second)

    AccountsFixtures.user_fixture()
    |> Ecto.Changeset.change(is_online: false, last_seen_at: seen)
    |> Repo.update!()
  end

  defp ticket!(user, params \\ %{"mode" => "duel"}, min \\ 2, max \\ 2) do
    {:ok, ticket} = Matchmaking.join(user, params, min, max)
    ticket
  end

  describe "join/4" do
    test "creates a queued ticket with normalized params" do
      {:ok, ticket} = Matchmaking.join(user(), %{mode: "duel", level: 3})

      assert ticket.status == "queued"
      assert ticket.match_params == %{"mode" => "duel", "level" => "3"}
      assert ticket.min_players == 2
      assert ticket.timeout_ms == GameServer.Limits.get(:matchmaking_timeout_ms)
    end

    test "rejects max_players below min_players" do
      assert {:error, changeset} = Matchmaking.join(user(), %{}, 4, 2)
      assert %{max_players: _} = errors_on(changeset)
    end

    test "rejects max_players above the limit" do
      too_many = GameServer.Limits.get(:max_matchmaking_players) + 1
      assert {:error, changeset} = Matchmaking.join(user(), %{}, 2, too_many)
      assert %{max_players: _} = errors_on(changeset)
    end

    test "rejects oversized match_params" do
      big = %{
        "blob" => String.duplicate("x", GameServer.Limits.get(:max_matchmaking_params_size))
      }

      assert {:error, changeset} = Matchmaking.join(user(), big)
      assert %{match_params: _} = errors_on(changeset)
    end
  end

  describe "cancel/1 and current_ticket/1" do
    test "cancel clears only the caller's queued tickets" do
      alice = user()
      bob = user()
      ticket!(alice)
      ticket!(bob)

      assert Matchmaking.cancel(alice.id) == 1
      assert Matchmaking.current_ticket(alice.id) == nil
      assert %Ticket{} = Matchmaking.current_ticket(bob.id)
    end

    test "cancel_ticket refuses non-queued and unknown ids" do
      ticket = ticket!(user())
      assert {:ok, cancelled} = Matchmaking.cancel_ticket(ticket.id)
      assert cancelled.status == "cancelled"

      assert {:error, :not_found} = Matchmaking.cancel_ticket(ticket.id)
      assert {:error, :not_found} = Matchmaking.cancel_ticket(Ecto.UUID.generate())
      assert {:error, :not_found} = Matchmaking.cancel_ticket("not-a-uuid")
    end
  end

  describe "Matcher.form_matches/1" do
    defp fake_ticket(min, max, timeout_ms, queued_seconds_ago) do
      %{
        user_id: Ecto.UUID.generate(),
        party_id: nil,
        min_players: min,
        max_players: max,
        timeout_ms: timeout_ms,
        queued_at: DateTime.add(DateTime.utc_now(), -queued_seconds_ago, :second)
      }
    end

    test "forms a match at max_players immediately" do
      tickets = for _ <- 1..3, do: fake_ticket(2, 3, 60_000, 0)
      {matches, remaining} = Matcher.form_matches(tickets)

      assert [match] = matches
      assert length(match) == 3
      assert remaining == []
    end

    test "holds below min_players even after the timeout" do
      {matches, remaining} = Matcher.form_matches([fake_ticket(2, 4, 0, 120)])
      assert matches == []
      assert length(remaining) == 1
    end

    test "forms a below-max match once the oldest ticket times out" do
      tickets = [fake_ticket(2, 4, 1_000, 60), fake_ticket(2, 4, 1_000, 59)]
      {matches, _} = Matcher.form_matches(tickets)
      assert [match] = matches
      assert length(match) == 2
    end

    test "waits for the timeout when between min and max" do
      tickets = [fake_ticket(2, 4, 60_000, 1), fake_ticket(2, 4, 60_000, 0)]
      {matches, remaining} = Matcher.form_matches(tickets)
      assert matches == []
      assert length(remaining) == 2
    end

    test "consumes FIFO and can form several matches per sweep" do
      tickets = for i <- 1..5, do: fake_ticket(2, 2, 60_000, 10 - i)
      {matches, remaining} = Matcher.form_matches(tickets)

      assert length(matches) == 2
      assert Enum.map(matches, &length/1) == [2, 2]
      assert length(remaining) == 1

      # FIFO: the oldest two form the first match
      [first_match | _] = matches
      sorted = Enum.sort_by(tickets, & &1.queued_at)
      assert first_match == Enum.take(sorted, 2)
    end
  end

  describe "Matcher.form_matches/2 with blocked pairs" do
    defp blocked_ticket(user_id, min, max, timeout_ms, queued_seconds_ago) do
      %{
        user_id: user_id,
        party_id: nil,
        min_players: min,
        max_players: max,
        timeout_ms: timeout_ms,
        queued_at: DateTime.add(DateTime.utc_now(), -queued_seconds_ago, :second)
      }
    end

    defp blocked_set(pairs) do
      MapSet.new(pairs, fn {a, b} -> GameServer.Friends.pair_key(a, b) end)
    end

    test "never places a blocked pair in the same match" do
      tickets = [
        blocked_ticket("a", 2, 2, 60_000, 10),
        blocked_ticket("b", 2, 2, 60_000, 9),
        blocked_ticket("c", 2, 2, 60_000, 8)
      ]

      {matches, _remaining} = Matcher.form_matches(tickets, blocked_set([{"a", "b"}]))

      # a skips b and matches c instead
      assert [match] = matches
      assert Enum.map(match, & &1.user_id) == ["a", "c"]
    end

    test "a blocked player does not stall the queue behind them" do
      tickets = [
        blocked_ticket("a", 2, 2, 60_000, 10),
        blocked_ticket("b", 2, 2, 60_000, 9),
        blocked_ticket("c", 2, 2, 60_000, 8),
        blocked_ticket("d", 2, 2, 60_000, 7)
      ]

      # a is blocked with everyone, so it can never be seated
      blocked = blocked_set([{"a", "b"}, {"a", "c"}, {"a", "d"}])

      {matches, remaining} = Matcher.form_matches(tickets, blocked)

      assert [match] = matches
      assert Enum.map(match, & &1.user_id) == ["b", "c"]
      # a stays queued alongside the unmatched d
      assert Enum.sort(Enum.map(remaining, & &1.user_id)) == ["a", "d"]
    end

    test "holds rather than forming a match that would violate a block" do
      tickets = [
        blocked_ticket("a", 2, 2, 60_000, 120),
        blocked_ticket("b", 2, 2, 60_000, 119)
      ]

      # only two players and they block each other: no match, even past timeout
      {matches, remaining} = Matcher.form_matches(tickets, blocked_set([{"a", "b"}]))

      assert matches == []
      assert length(remaining) == 2
    end

    test "an empty blocked set matches exactly as before" do
      tickets = for i <- 1..5, do: blocked_ticket("u#{i}", 2, 2, 60_000, 10 - i)

      assert Matcher.form_matches(tickets, MapSet.new()) == Matcher.form_matches(tickets)
    end
  end

  describe "claim/requeue/discard" do
    test "claim flips queued tickets and refuses partial claims" do
      alice = ticket!(user())
      bob = ticket!(user())

      assert Matchmaking.claim([alice, bob]) == :ok
      assert Repo.get!(Ticket, alice.id).status == "matched"

      # Cancelling one member makes a subsequent claim conflict and roll back.
      carol = ticket!(user())
      dave = ticket!(user())
      {:ok, _} = Matchmaking.cancel_ticket(dave.id)

      assert Matchmaking.claim([carol, dave]) == :conflict
      assert Repo.get!(Ticket, carol.id).status == "queued"
      assert Repo.get!(Ticket, dave.id).status == "cancelled"
    end

    test "requeue returns claimed tickets without a lobby to the queue" do
      ticket = ticket!(user())
      :ok = Matchmaking.claim([ticket])
      :ok = Matchmaking.requeue([ticket])

      reloaded = Repo.get!(Ticket, ticket.id)
      assert reloaded.status == "queued"
      assert reloaded.matched_at == nil
    end

    test "discard cancels claimed tickets instead of requeueing" do
      ticket = ticket!(user())
      :ok = Matchmaking.claim([ticket])
      :ok = Matchmaking.discard([ticket])

      assert Repo.get!(Ticket, ticket.id).status == "cancelled"
    end
  end

  describe "prune_offline/0" do
    test "cancels tickets of long-offline users only" do
      online = ticket!(user(true))
      offline = ticket!(long_offline_user())

      assert Matchmaking.prune_offline() == 1
      assert Repo.get!(Ticket, online.id).status == "queued"
      assert Repo.get!(Ticket, offline.id).status == "cancelled"
    end

    test "keeps a player who only just went offline" do
      recent = ticket!(user(false))

      assert Matchmaking.prune_offline() == 0
      assert Repo.get!(Ticket, recent.id).status == "queued"
    end
  end

  describe "list_tickets/1 and stats/0" do
    test "filters by status and user, paginates" do
      alice = user()
      ticket!(alice)
      cancelled = ticket!(user())
      {:ok, _} = Matchmaking.cancel_ticket(cancelled.id)

      assert length(Matchmaking.list_tickets(status: "queued")) == 1
      assert [t] = Matchmaking.list_tickets(user_id: alice.id)
      assert t.user_id == alice.id
      assert t.user.id == alice.id

      assert Matchmaking.count_tickets([]) == 2
      assert length(Matchmaking.list_tickets(page: 1, page_size: 1)) == 1
    end

    test "stats reports status counts and queue depths" do
      ticket!(user(), %{"mode" => "duel"})
      ticket!(user(), %{"mode" => "duel"}, 3, 4)
      ticket!(user(), %{"mode" => "ffa"})

      stats = Matchmaking.stats()
      assert stats.queued == 3

      assert [
               %{params: %{"mode" => "duel"}, waiting: 2},
               %{params: %{"mode" => "ffa"}, waiting: 1}
             ] =
               stats.queues
    end
  end

  describe "Worker.sweep/0 end to end" do
    test "matches two compatible tickets into a hidden locked lobby" do
      alice = user()
      bob = user()
      ticket!(alice)
      ticket!(bob)
      # a different queue must not be pulled in
      stranger = ticket!(user(), %{"mode" => "ffa"})

      Phoenix.PubSub.subscribe(GameServer.PubSub, "matchmaking:user:#{alice.id}")

      assert Worker.sweep() == 1

      alice_ticket = Matchmaking.list_tickets(user_id: alice.id) |> hd()
      assert alice_ticket.status == "matched"
      assert alice_ticket.match_id != nil

      lobby = Lobbies.get_lobby!(alice_ticket.match_id)
      assert lobby.is_hidden
      assert lobby.is_locked

      member_ids = lobby |> Lobbies.get_lobby_members() |> Enum.map(& &1.id) |> Enum.sort()
      assert member_ids == Enum.sort([alice.id, bob.id])

      assert Repo.get!(Ticket, stranger.id).status == "queued"

      assert_receive {:matchmaking_event, "matchmaking_found", payload}
      assert payload.lobby_id == lobby.id
      assert payload.match_params == %{"mode" => "duel"}
    end

    test "prunes long-offline users before matching" do
      ticket!(user(true))
      ticket!(long_offline_user())

      # Only one live player remains — no match forms.
      assert Worker.sweep() == 0
      assert Matchmaking.stats().queued == 1
    end

    test "a sweep with an empty queue is a no-op" do
      assert Worker.sweep() == 0
    end

    test "does not match players who have blocked each other" do
      alice = user()
      bob = user()
      {:ok, _} = GameServer.Friends.block_user(alice, bob.id)

      ticket!(alice)
      ticket!(bob)

      assert Worker.sweep() == 0
      assert Matchmaking.stats().queued == 2
    end

    test "matches a blocked player with someone else in the queue" do
      alice = user()
      bob = user()
      carol = user()
      {:ok, _} = GameServer.Friends.block_user(alice, bob.id)

      # alice queues first, so a naive FIFO pairing would seat her with bob
      ticket!(alice)
      ticket!(bob)
      ticket!(carol)

      assert Worker.sweep() == 1

      alice_ticket = Matchmaking.list_tickets(user_id: alice.id) |> hd()
      assert alice_ticket.status == "matched"

      member_ids =
        alice_ticket.match_id
        |> Lobbies.get_lobby!()
        |> Lobbies.get_lobby_members()
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert member_ids == Enum.sort([alice.id, carol.id])

      # bob is untouched and waits for the next tick
      assert Matchmaking.list_tickets(user_id: bob.id) |> hd() |> Map.get(:status) == "queued"
    end
  end

  describe "worker registration" do
    test "registers locally, not via :global" do
      # A :global name would make a second node's supervisor fail to boot on
      # {:error, {:already_started, _}}; cluster exclusivity comes from the
      # advisory lock inside sweep/0 instead.
      pid = start_supervised!(Worker)
      assert Process.whereis(Worker) == pid
      assert :global.whereis_name(Worker) == :undefined
    end
  end
end
