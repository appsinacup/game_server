defmodule GameServer.Modules.ExampleHook do
  @moduledoc """
  Example hooks implementation shipped as an OTP plugin.

  This is intentionally kept out of the default plugins directory so it does not
  affect test runs or production deployments.

  To try it locally:

      export GAME_SERVER_PLUGINS_DIR=modules/plugins_examples

  Then restart the server and use the Admin Config page to reload plugins.
  """

  # `use` (not `@behaviour`) so the SDK supplies overridable defaults for every
  # callback — this example only defines the ones it demonstrates. Any callback
  # left out simply keeps its default behaviour.
  use GameServer.Hooks
  require Logger

  alias GameServer.Accounts
  alias GameServer.Achievements
  alias GameServer.Groups
  alias GameServer.Hooks
  alias GameServer.KV
  alias GameServer.Leaderboards
  alias GameServer.Lock
  alias GameServer.Notifications
  alias GameServer.Tournaments

  # Sample content this plugin owns. Both are namespaced so the hooks below can
  # ignore leaderboards/tournaments belonging to the rest of the game.
  @login_leaderboard "example_login_count"
  @tournament_slug "example-weekly-cup"
  @achievement_slug "example_first_login"
  @group_title "Example Guild"
  @welcome_kv_key "example_welcome"

  @impl true
  def after_startup do
    Logger.info("[ExampleHook] after_startup called")

    # Every sample is created only when missing, so restarts and plugin
    # reloads are safe. The group is seeded on first registration instead —
    # groups need a creator and there may be no users yet at boot.
    ensure_login_leaderboard()
    ensure_weekly_cup()
    ensure_achievement()
    ensure_welcome_kv()

    [
      %{
        hook: "custom_hello",
        meta: %{
          description: "Example dynamic hook that returns hello",
          args: [%{name: "name", type: "string"}],
          example_args: ["Dragos"]
        }
      }
    ]
  end

  # ── Sample leaderboard: how many times each player has logged in ──────────
  #
  # The `incr` operator makes every submission add to the stored score, so the
  # login hook can just submit 1 without reading the previous value.

  defp ensure_login_leaderboard do
    case Leaderboards.get_active_leaderboard_by_slug(@login_leaderboard) do
      nil ->
        Leaderboards.create_leaderboard(%{
          slug: @login_leaderboard,
          title: "Logins",
          description: "How many times each player has logged in.",
          sort_order: :desc,
          operator: :incr
        })

      _existing ->
        :ok
    end
  end

  @impl true
  def after_user_login(user) do
    # Also seeded here, not just on registration: on a database that already
    # has players, nobody registers again and the group would never appear.
    ensure_group(user)

    case Leaderboards.get_active_leaderboard_by_slug(@login_leaderboard) do
      nil -> :ok
      board -> Leaderboards.submit_score(board.id, user.id, 1)
    end

    # Unlocking is idempotent, so re-logins keep the original unlock time.
    Achievements.unlock_achievement(user.id, @achievement_slug)

    :ok
  end

  # ── Sample achievement: unlocked the first time a player logs in ──────────

  defp ensure_achievement do
    if is_nil(Achievements.get_achievement_by_slug(@achievement_slug)) do
      Achievements.create_achievement(%{
        slug: @achievement_slug,
        title: "Welcome aboard",
        description: "Log in for the first time.",
        progress_target: 1
      })
    end

    :ok
  end

  # ── Sample KV entry: a global value any client can read ───────────────────

  defp ensure_welcome_kv do
    case KV.get(@welcome_kv_key) do
      {:ok, _entry} -> :ok
      _missing -> KV.put(@welcome_kv_key, %{"message" => "Hello from ExampleHook!"})
    end

    :ok
  end

  # ── Sample group: seeded by the first player to register ──────────────────

  defp ensure_group(user) do
    if is_nil(Groups.get_group_by_title(@group_title)) do
      Groups.create_group(user.id, %{
        title: @group_title,
        description: "A public group created by the example plugin.",
        type: "public"
      })
    end

    :ok
  end

  @impl true
  def after_user_register(user) do
    ensure_group(user)
    welcome_notification(user)
    :ok
  end

  # Sent once per player rather than on every login. `admin_create_notification/3`
  # is the plugin-side entry point: unlike `send_notification/2` it doesn't
  # require the sender and recipient to be friends, so a plugin can post
  # system messages (here the player is both sender and recipient).
  defp welcome_notification(user) do
    Notifications.admin_create_notification(user.id, user.id, %{
      "title" => "Welcome!",
      "content" => "Thanks for joining. Register for the Weekly Cup to get started.",
      "metadata" => %{"type" => "example_welcome"}
    })

    :ok
  end

  # ── Sample tournament: a weekly cup that plays itself ─────────────────────
  #
  # Registration is the only thing players do. `recur` makes the server create
  # next week's occurrence automatically when this one finishes.

  defp ensure_weekly_cup do
    case Tournaments.get_tournament_by_slug(@tournament_slug) do
      nil ->
        Tournaments.create_tournament(%{
          slug: @tournament_slug,
          title: "Weekly Cup",
          description: "Register any time; the bracket is drawn every Monday.",
          starts_at: next_monday(),
          recur: "0 0 * * 1",
          bracket_size: 8,
          round_window_sec: 24 * 3600
        })

      _existing ->
        :ok
    end
  end

  defp next_monday do
    today = Date.utc_today()
    days = rem(8 - Date.day_of_week(today), 7)
    days = if days == 0, do: 7, else: days

    DateTime.new!(Date.add(today, days), ~T[00:00:00], "Etc/UTC")
  end

  # A real game would start a lobby here and report the outcome later. This
  # sample decides immediately, so resolving one match readies the next and the
  # whole bracket plays itself out.
  @impl true
  def tournament_match_ready(match) do
    if match.tournament.slug == @tournament_slug do
      winner = Enum.random(Enum.reject([match.a_entry_id, match.b_entry_id], &is_nil/1))
      resolve_with_retry(match.id, winner, 3)
    end

    :ok
  end

  # Every match in a round becomes ready at once, so these hooks run
  # concurrently. SQLite (the default dev adapter) rejects a second concurrent
  # write transaction with "Database busy" immediately — WAL mode cannot queue
  # writers — so the write is retried. Postgres writes distinct rows and does
  # not hit this.
  defp resolve_with_retry(match_id, winner, attempts) do
    Tournaments.resolve_match(match_id, winner)
    :ok
  rescue
    error ->
      if attempts > 1 do
        Process.sleep(150)
        resolve_with_retry(match_id, winner, attempts - 1)
      else
        Logger.warning(
          "[ExampleHook] could not resolve match #{match_id}: #{Exception.message(error)}"
        )

        :ok
      end
  end

  @impl true
  def after_tournament_finished(tournament, standings) do
    if tournament.slug == @tournament_slug do
      champions = Enum.map_join(standings.champions, ", ", & &1.leader_id)
      Logger.info("[ExampleHook] #{tournament.title} finished, champions: #{champions}")

      Enum.each(standings.champions, fn entry ->
        Notifications.admin_create_notification(entry.leader_id, entry.leader_id, %{
          "title" => "You won the #{tournament.title}!",
          "content" => "Congratulations — you took the whole bracket.",
          "metadata" => %{"type" => "example_tournament_won", "tournament_id" => tournament.id}
        })
      end)
    end

    :ok
  end

  @impl true
  def on_custom_hook("custom_hello", [name]) when is_binary(name), do: "hello #{name}"

  def on_custom_hook("custom_hello", _args), do: "hello"

  @impl true
  def on_custom_hook(_hook, _args), do: {:error, :not_implemented}

  @doc """
  KV data schema example: entries under the "pb_loadout" key are pushed as
  compact binary (KvEntry data_pb) on protobuf sockets. Exact keys or
  "prefix*" patterns are supported.
  """
  def kv_schemas do
    %{"pb_loadout" => ExampleHook.V1.ExampleLoadout}
  end

  @doc """
  Typed protobuf hook example (see proto/example_hook.proto).

  The HelloProtoRequest/HelloProtoReply message pair registers this hook's
  schema by name, so the server converts at the boundary: protobuf clients
  call it with encoded bytes (`args_raw`), JSON clients with a plain object
  (`{"name": "x", "repeat": 2}`) — this function always receives the
  decoded request struct and returns a reply struct.
  """
  def hello_proto(%ExampleHook.V1.HelloProtoRequest{} = req) do
    repeat = max(req.repeat, 1)
    greeting = String.duplicate("Hello, #{req.name}! ", repeat) |> String.trim_trailing()

    %ExampleHook.V1.HelloProtoReply{
      greeting: greeting,
      name_length: byte_size(req.name)
    }
  end

  @doc "Say hi to a user"
  def hello(name) when is_binary(name) do
    # Exercise an external dependency so the bundle task can prove it ships deps.
    Bunt.ANSI.format(["Hello1, ", name, "!"], false)
  end

  @doc "Return an updated metadata map for the current caller"
  def set_current_user_meta(key, value) when is_binary(key) do
    do_set_user_meta(Hooks.caller_user(), key, value)
  end

  defp do_set_user_meta(user, key, value) do
    meta = user.metadata || %{}
    meta = Map.put(meta, key, value)
    {:ok, updated_user} = Accounts.update_user(user, %{metadata: meta})
    updated_user
  end

  # ── Benchmark RPCs ──────────────────────────────────────────────────

  @doc "Benchmark: instant return, no I/O. Measures pure RPC overhead."
  def bench_noop, do: :ok

  @doc "Benchmark: read a KV entry from the database."
  def bench_kv_read(key) when is_binary(key) do
    case KV.get(key) do
      {:ok, entry} -> entry.value
      _ -> nil
    end
  end

  @doc "Benchmark: read from ETS (in-memory). Measures RPC + ETS overhead."
  def bench_memory_read(key) when is_binary(key) do
    case :ets.lookup(:game_server_bench, key) do
      [{^key, val}] -> val
      [] -> nil
    end
  rescue
    ArgumentError -> nil
  end

  @doc "Benchmark: write to KV inside an advisory lock."
  def bench_kv_write_locked(key) when is_binary(key) do
    resource_id = :erlang.phash2(key)

    _result =
      Lock.serialize("bench", resource_id, fn ->
        ts = System.system_time(:millisecond)
        KV.put(key, %{"ts" => ts, "writer" => "bench"})
      end)

    :ok
  end

  @doc "Benchmark: ensure the ETS table + seed key exist, then read a KV entry."
  def bench_setup(key) when is_binary(key) do
    # Create ETS table for memory benchmarks (idempotent)
    try do
      :ets.new(:game_server_bench, [:named_table, :public, :set])
    rescue
      ArgumentError -> :already_exists
    end

    :ets.insert(:game_server_bench, {key, %{"seeded" => true}})

    # Seed a KV entry for DB read benchmarks
    KV.put(key, %{"seeded" => true})
    :ok
  end
end
