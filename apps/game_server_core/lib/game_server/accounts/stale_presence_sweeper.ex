defmodule GameServer.Accounts.StalePresenceSweeper do
  @moduledoc """
  Periodically sweeps users whose `is_online` flag is `true` but whose
  `last_seen_at` timestamp is older than a configurable threshold.

  This is a safety net for node crashes or ungraceful disconnects where the
  `UserChannel.terminate/2` callback never fires. Without this, users would
  remain marked as online indefinitely.

  ## Configuration

      config :game_server_core, GameServer.Accounts.StalePresenceSweeper,
        interval_ms: 120_000,       # how often to run the sweep (default 2 min)
        stale_threshold_s: 300,     # mark offline if last_seen > 5 min ago
        enabled: true               # set false to disable the sweep entirely

  """

  use GenServer
  require Logger

  import Ecto.Query

  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.Repo

  @default_interval_ms 120_000
  @default_stale_threshold_s 300

  # ── Public API ──────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the current configuration used by the sweeper.
  """
  @spec config() :: keyword()
  def config do
    Application.get_env(:game_server_core, __MODULE__, [])
  end

  # ── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    conf = config()
    enabled = Keyword.get(conf, :enabled, true)

    if enabled do
      interval = Keyword.get(conf, :interval_ms, @default_interval_ms)
      schedule_sweep(interval)
      Logger.info("StalePresenceSweeper started (interval=#{interval}ms)")
    else
      Logger.info("StalePresenceSweeper disabled by config")
    end

    {:ok, %{enabled: enabled}}
  end

  @impl true
  def handle_info(:sweep, %{enabled: false} = state) do
    {:noreply, state}
  end

  def handle_info(:sweep, state) do
    conf = config()
    interval = Keyword.get(conf, :interval_ms, @default_interval_ms)
    threshold_s = Keyword.get(conf, :stale_threshold_s, @default_stale_threshold_s)

    swept = do_sweep(threshold_s)

    if swept > 0 do
      Logger.info("StalePresenceSweeper: marked #{swept} stale user(s) offline")
    end

    schedule_sweep(interval)
    {:noreply, state}
  end

  # ── Sweep logic ─────────────────────────────────────────────────────────────

  @doc false
  @spec do_sweep(non_neg_integer()) :: non_neg_integer()
  def do_sweep(threshold_s) do
    cutoff = DateTime.utc_now() |> DateTime.add(-threshold_s, :second)

    stale_users =
      from(u in User,
        where: u.is_online == true,
        where: is_nil(u.last_seen_at) or u.last_seen_at < ^cutoff,
        select: u.id
      )
      |> Repo.all()

    Enum.each(stale_users, fn user_id ->
      case Accounts.set_user_offline(user_id) do
        {:ok, _} ->
          Accounts.broadcast_friend_offline(user_id)

        {:error, reason} ->
          Logger.warning(
            "StalePresenceSweeper: failed to mark user #{user_id} offline: #{inspect(reason)}"
          )
      end
    end)

    length(stale_users)
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp schedule_sweep(interval_ms) do
    Process.send_after(self(), :sweep, interval_ms)
  end
end
