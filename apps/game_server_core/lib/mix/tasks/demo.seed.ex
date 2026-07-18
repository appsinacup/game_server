defmodule Mix.Tasks.Demo.Seed do
  @shortdoc "Seeds large volumes of demo data (leaderboard, group, tournament)"

  @moduledoc """
  Fills the database with enough demo data to exercise pagination and the
  list/detail pages at realistic sizes.

  Everything is namespaced with a `demo-seed` prefix so `--clean` can remove it
  again without touching real data.

  ## Usage

      mix demo.seed                       # all sets, 1000 rows each
      mix demo.seed --count 250           # smaller run
      mix demo.seed --only leaderboard    # one set (comma-separated)
      mix demo.seed --only group,tournament
      mix demo.seed --clean               # remove everything this task created

  ## Sets

    * `leaderboard` — a leaderboard with N scored records
    * `group`       — a public group with N members
    * `tournament`  — a tournament with N registered entries, still open

  All sets share one pool of N anonymous device accounts, so the same players
  appear across them (as they would in a real deployment).

  Rows are inserted in bulk rather than through the contexts: this is about
  volume, not about exercising business rules, and 1000 individual writes on
  SQLite is slow. The cache is flushed afterwards so pages read the new rows.
  """

  use Mix.Task

  import Ecto.Query

  alias GameServer.Accounts.User
  alias GameServer.Groups.Group
  alias GameServer.Groups.GroupMember
  alias GameServer.Leaderboards.Leaderboard
  alias GameServer.Leaderboards.Record
  alias GameServer.Repo
  alias GameServer.Tournaments.Entry
  alias GameServer.Tournaments.Tournament
  alias GameServer.UUIDv7

  @prefix "demo-seed"
  @leaderboard_slug "demo_seed_scores"
  @group_title "Demo Seed Group"
  @tournament_slug "demo-seed-cup"
  @default_count 1000
  @batch 500
  @all_sets ~w(leaderboard group tournament)

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, _} =
      OptionParser.parse(args, strict: [count: :integer, only: :string, clean: :boolean])

    if opts[:clean] do
      clean()
    else
      count = opts[:count] || @default_count
      sets = parse_sets(opts[:only])

      info("seeding #{count} rows per set: #{Enum.join(sets, ", ")}")
      users = ensure_users(count)

      Enum.each(sets, fn
        "leaderboard" -> seed_leaderboard(users)
        "group" -> seed_group(users)
        "tournament" -> seed_tournament(users)
      end)

      GameServer.Cache.delete_all()
      info("done — run `mix demo.seed --clean` to remove it again")
    end
  end

  defp parse_sets(nil), do: @all_sets

  defp parse_sets(only) do
    sets = only |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

    case sets -- @all_sets do
      [] ->
        sets

      unknown ->
        Mix.raise(
          "unknown set(s): #{Enum.join(unknown, ", ")} (known: #{Enum.join(@all_sets, ", ")})"
        )
    end
  end

  # ── Shared player pool ────────────────────────────────────────────────────

  defp ensure_users(count) do
    existing =
      from(u in User, where: like(u.device_id, ^"#{@prefix}-%"), select: {u.device_id, u.id})
      |> Repo.all()
      |> Map.new()

    missing =
      for i <- 1..count,
          device_id = device_id(i),
          not Map.has_key?(existing, device_id),
          do: {i, device_id}

    now = DateTime.utc_now(:second)

    missing
    |> Enum.map(fn {i, device_id} ->
      %{
        id: UUIDv7.generate(),
        device_id: device_id,
        username: username(i),
        display_name: display_name(i),
        is_admin: false,
        is_activated: true,
        metadata: %{},
        token_version: 0,
        inserted_at: now,
        updated_at: now
      }
    end)
    |> insert_batches(User)

    info("players: #{count} (#{length(missing)} new)")

    from(u in User,
      where: like(u.device_id, ^"#{@prefix}-%"),
      order_by: u.device_id,
      limit: ^count,
      select: u.id
    )
    |> Repo.all()
  end

  defp device_id(i), do: "#{@prefix}-#{pad(i)}"
  defp username(i), do: "#{@prefix}-#{pad(i)}"
  defp display_name(i), do: "Demo Player #{pad(i)}"
  defp pad(i), do: String.pad_leading(Integer.to_string(i), 5, "0")

  # ── Sets ──────────────────────────────────────────────────────────────────

  defp seed_leaderboard(user_ids) do
    leaderboard =
      upsert(Leaderboard, [slug: @leaderboard_slug], %{
        slug: @leaderboard_slug,
        title: "Demo Seed Scores",
        description: "Volume demo data.",
        sort_order: :desc,
        operator: :best,
        metadata: %{}
      })

    Repo.delete_all(from(r in Record, where: r.leaderboard_id == ^leaderboard.id))
    now = DateTime.utc_now(:second)

    user_ids
    |> Enum.map(fn user_id ->
      %{
        id: UUIDv7.generate(),
        leaderboard_id: leaderboard.id,
        user_id: user_id,
        score: :rand.uniform(1_000_000),
        metadata: %{},
        inserted_at: now,
        updated_at: now
      }
    end)
    |> insert_batches(Record)

    info("leaderboard: #{length(user_ids)} records -> /leaderboards/#{@leaderboard_slug}")
  end

  defp seed_group(user_ids) do
    [creator | members] = user_ids

    group =
      upsert(Group, [title: @group_title], %{
        title: @group_title,
        description: "Volume demo data.",
        type: "public",
        max_members: length(user_ids) + 10,
        creator_id: creator,
        metadata: %{}
      })

    Repo.delete_all(from(m in GroupMember, where: m.group_id == ^group.id))
    now = DateTime.utc_now(:second)

    rows =
      [%{user_id: creator, role: "admin"}] ++ Enum.map(members, &%{user_id: &1, role: "member"})

    rows
    |> Enum.map(fn row ->
      %{
        id: UUIDv7.generate(),
        group_id: group.id,
        user_id: row.user_id,
        role: row.role,
        inserted_at: now,
        updated_at: now
      }
    end)
    |> insert_batches(GroupMember)

    info("group: #{length(rows)} members -> /groups/#{group.id}")
  end

  defp seed_tournament(user_ids) do
    now = DateTime.utc_now(:second)

    tournament =
      upsert(Tournament, [slug: @tournament_slug], %{
        slug: @tournament_slug,
        title: "Demo Seed Cup",
        description: "Volume demo data — registration is open.",
        state: "registration",
        registration_opens_at: DateTime.add(now, -3600),
        starts_at: DateTime.add(now, 7 * 86_400),
        round_window_sec: 3600,
        bracket_size: 8,
        team_size: 1,
        deadline_policy: "forfeit_both",
        metadata: %{}
      })

    Repo.delete_all(from(e in Entry, where: e.tournament_id == ^tournament.id))

    user_ids
    |> Enum.map(fn user_id ->
      %{
        id: UUIDv7.generate(),
        tournament_id: tournament.id,
        leader_id: user_id,
        wins: 0,
        state: "registered",
        metadata: %{},
        inserted_at: now,
        updated_at: now
      }
    end)
    |> insert_batches(Entry)

    info("tournament: #{length(user_ids)} entries -> /tournaments/#{tournament.id}")
  end

  # ── Clean ─────────────────────────────────────────────────────────────────

  defp clean do
    lb = Repo.get_by(Leaderboard, slug: @leaderboard_slug)
    group = Repo.get_by(Group, title: @group_title)
    tournament = Repo.get_by(Tournament, slug: @tournament_slug)

    if lb, do: Repo.delete_all(from(r in Record, where: r.leaderboard_id == ^lb.id))
    if group, do: Repo.delete_all(from(m in GroupMember, where: m.group_id == ^group.id))
    if tournament, do: Repo.delete_all(from(e in Entry, where: e.tournament_id == ^tournament.id))

    if lb, do: Repo.delete(lb)
    if group, do: Repo.delete(group)
    if tournament, do: Repo.delete(tournament)

    {users, _} = Repo.delete_all(from(u in User, where: like(u.device_id, ^"#{@prefix}-%")))

    GameServer.Cache.delete_all()
    info("removed demo data (#{users} players)")
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  # insert_all rejects oversized statements, so rows go in batches.
  defp insert_batches([], _schema), do: :ok

  defp insert_batches(rows, schema) do
    rows
    |> Enum.chunk_every(@batch)
    |> Enum.each(&Repo.insert_all(schema, &1))
  end

  defp upsert(schema, lookup, attrs) do
    case Repo.get_by(schema, lookup) do
      nil ->
        now = DateTime.utc_now(:second)

        attrs =
          attrs
          |> Map.put(:id, UUIDv7.generate())
          |> Map.put_new(:inserted_at, now)
          |> Map.put_new(:updated_at, now)

        Repo.insert_all(schema, [attrs])
        Repo.get_by!(schema, lookup)

      found ->
        found
    end
  end

  defp info(message), do: Mix.shell().info("  #{message}")
end
