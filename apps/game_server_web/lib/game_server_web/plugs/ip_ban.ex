defmodule GameServerWeb.Plugs.IpBan do
  @moduledoc """
  Plug that blocks requests from banned IP addresses.

  Ban entries are stored in a dedicated ETS table (`:ip_bans`). When a ban
  exists for the client IP, the request is rejected with `403 Forbidden`.

  ## Banning / unbanning an IP

      GameServerWeb.Plugs.IpBan.ban("1.2.3.4")                    # permanent
      GameServerWeb.Plugs.IpBan.ban("1.2.3.4", :timer.hours(24))  # 24h ban
      GameServerWeb.Plugs.IpBan.unban("1.2.3.4")
      GameServerWeb.Plugs.IpBan.banned?("1.2.3.4")
      GameServerWeb.Plugs.IpBan.list_bans()

  This plug runs early in the endpoint pipeline, after `RealIp` extracts
  the true client address.
  """

  import Plug.Conn

  @behaviour Plug
  @table :ip_bans

  # ── Public API ────────────────────────────────────────────────────────────

  @doc "Ensure the ETS table exists (called once at app startup)."
  def init_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    end

    :ok
  end

  @doc """
  Ban an IP address. Pass `ttl_ms` for a temporary ban (milliseconds)
  or `:infinity` (default) for a permanent ban.
  """
  def ban(ip, ttl_ms \\ :infinity) do
    init_table()

    expires_at =
      case ttl_ms do
        :infinity -> :infinity
        ms when is_integer(ms) -> System.monotonic_time(:millisecond) + ms
      end

    :ets.insert(@table, {ip, expires_at})
    :ok
  end

  @doc "Remove a ban for the given IP."
  def unban(ip) do
    init_table()
    :ets.delete(@table, ip)
    :ok
  end

  @doc "Check if an IP is currently banned."
  def banned?(ip) do
    init_table()

    case :ets.lookup(@table, ip) do
      [{^ip, :infinity}] ->
        true

      [{^ip, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          true
        else
          # Expired — clean up
          :ets.delete(@table, ip)
          false
        end

      [] ->
        false
    end
  end

  @doc "List all currently active bans as `[{ip, expires_at}]`."
  def list_bans do
    init_table()
    now = System.monotonic_time(:millisecond)

    :ets.tab2list(@table)
    |> Enum.filter(fn
      {_ip, :infinity} -> true
      {_ip, expires_at} -> expires_at > now
    end)
  end

  # ── Plug callbacks ────────────────────────────────────────────────────────

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    if banned?(ip) do
      conn
      |> send_resp(403, "Forbidden")
      |> halt()
    else
      conn
    end
  end
end
