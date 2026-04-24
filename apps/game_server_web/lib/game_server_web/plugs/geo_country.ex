defmodule GameServerWeb.Plugs.GeoCountry do
  @moduledoc """
  Resolves the client's country and stores it on `conn.assigns[:country]`.

  **Resolution order** (first match wins):

  1. **Geolix MMDB lookup** — if a GeoLite2-Country (or compatible) database
     is configured via `GEOIP_DB_PATH`, the client IP is resolved locally.
     This is the most accurate and works without any proxy.

  2. **Cloudflare `CF-IPCountry` header** — fallback when behind Cloudflare.
     Cloudflare auto-appends the ISO 3166-1 alpha-2 country code.

  3. **`nil`** — when neither source is available (local dev without DB).

  Also maintains an **in-memory ETS aggregate** of request counts by country,
  bucketed by minute, for the admin dashboard. Supports time-windowed queries
  (last 1h, 24h, 7d, or all-time).

  Emits a `:telemetry` event `[:game_server, :geo, :request]` with the
  country code as metadata for Prometheus export.

  ## Configuration

    To enable Geolix lookup, either place the MMDB file under the host-owned
    default path:

      apps/game_server_host/data/GeoLite2-Country.mmdb

    or set a custom path in your environment:

      GEOIP_DB_PATH=/path/to/GeoLite2-Country.mmdb

  Download the free database from:
  https://dev.maxmind.com/geoip/geolite2-free-geolocation-data
  """

  import Plug.Conn

  @behaviour Plug

  @table :geo_country_stats
  # Keep 7 days of minute buckets
  @retention_minutes 7 * 24 * 60

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    country = resolve_country(conn)
    code = country || "XX"

    # Increment minute-bucketed counter
    increment(code)

    # Emit telemetry for Prometheus
    :telemetry.execute(
      [:game_server, :geo, :request],
      %{count: 1},
      %{country: code}
    )

    assign(conn, :country, country)
  end

  # --- Resolution strategies ---

  defp resolve_country(conn) do
    geolix_lookup(conn.remote_ip) || cf_header(conn)
  end

  # Strategy 1: Local MMDB database lookup via Geolix
  defp geolix_lookup(ip) do
    case Geolix.lookup(ip, where: :country) do
      %{country: %{iso_code: code}} when is_binary(code) ->
        String.upcase(code)

      _ ->
        nil
    end
  rescue
    # Geolix not configured or database not loaded
    _ -> nil
  end

  # Strategy 2: Cloudflare CF-IPCountry header
  defp cf_header(conn) do
    case get_req_header(conn, "cf-ipcountry") do
      [code | _] when byte_size(code) in 2..3 -> String.upcase(code)
      _ -> nil
    end
  end

  # --- Public API for admin dashboard ---

  @doc """
  Initialize the ETS table. Call once at application startup.
  """
  def init_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, {:write_concurrency, true}])
    end

    :ok
  end

  @doc """
  Returns a sorted list of `{country_code, count}` tuples, descending by count.

  ## Options

    * `:window` — one of `:all`, `:hour`, `:day`, `:week` (default: `:all`)
  """
  def country_stats(opts \\ []) do
    if :ets.whereis(@table) == :undefined do
      []
    else
      cutoff = minute_cutoff(opts[:window] || :all)

      @table
      |> :ets.tab2list()
      |> Enum.reduce(%{}, fn
        {{country, minute}, count}, acc when minute >= cutoff ->
          Map.update(acc, country, count, &(&1 + count))

        _, acc ->
          acc
      end)
      |> Enum.sort_by(fn {_country, count} -> count end, :desc)
    end
  end

  @doc """
  Returns the total number of tracked requests across all countries.

  ## Options

    * `:window` — one of `:all`, `:hour`, `:day`, `:week` (default: `:all`)
  """
  def total_requests(opts \\ []) do
    if :ets.whereis(@table) == :undefined do
      0
    else
      cutoff = minute_cutoff(opts[:window] || :all)

      :ets.foldl(
        fn
          {{_country, minute}, count}, acc when minute >= cutoff -> acc + count
          _, acc -> acc
        end,
        0,
        @table
      )
    end
  end

  @doc """
  Returns a time series of `{minute_ts, count}` for the given country and window.
  Useful for sparklines in the UI. Each entry is a Unix minute timestamp.
  """
  def time_series(country, opts \\ []) do
    if :ets.whereis(@table) == :undefined do
      []
    else
      cutoff = minute_cutoff(opts[:window] || :hour)

      :ets.foldl(
        fn
          {{^country, minute}, count}, acc when minute >= cutoff ->
            [{minute, count} | acc]

          _, acc ->
            acc
        end,
        [],
        @table
      )
      |> Enum.sort_by(fn {m, _} -> m end)
    end
  end

  @doc """
  Reset all counters (useful from admin panel).
  """
  def reset_stats do
    if :ets.whereis(@table) != :undefined do
      :ets.delete_all_objects(@table)
    end

    :ok
  end

  @doc """
  Remove minute buckets older than the retention period (#{@retention_minutes} minutes).
  Called periodically by `GameServerWeb.GeoCountryCleaner`.
  """
  def cleanup_old_buckets do
    if :ets.whereis(@table) != :undefined do
      cutoff = current_minute() - @retention_minutes

      :ets.foldl(
        fn
          {{_country, minute} = key, _count}, acc when minute < cutoff ->
            :ets.delete(@table, key)
            acc + 1

          _, acc ->
            acc
        end,
        0,
        @table
      )
    else
      0
    end
  end

  @doc """
  Returns whether Geolix has a country database loaded.
  """
  def geoip_available? do
    case Application.get_env(:geolix, :databases) do
      databases when is_list(databases) and databases != [] -> true
      _ -> false
    end
  end

  @doc """
  Returns the number of distinct countries seen in the given window.
  """
  def country_count(opts \\ []) do
    length(country_stats(opts))
  end

  @doc """
  Single-pass dashboard stats. Returns a map with all-time and 1h data in
  one ETS scan, avoiding multiple `tab2list` / `foldl` calls.

  Returns:

      %{
        stats_all: [{country, count}, ...],
        total_all: integer,
        stats_1h: [{country, count}, ...],
        total_1h: integer
      }
  """
  def dashboard_stats do
    if :ets.whereis(@table) == :undefined do
      %{stats_all: [], total_all: 0, stats_1h: [], total_1h: 0}
    else
      cutoff_1h = minute_cutoff(:hour)

      {by_country_all, by_country_1h, total_all, total_1h} =
        :ets.foldl(
          fn {{country, minute}, count}, {all, h1, t_all, t_1h} ->
            all = Map.update(all, country, count, &(&1 + count))
            t_all = t_all + count

            if minute >= cutoff_1h do
              h1 = Map.update(h1, country, count, &(&1 + count))
              {all, h1, t_all, t_1h + count}
            else
              {all, h1, t_all, t_1h}
            end
          end,
          {%{}, %{}, 0, 0},
          @table
        )

      sort_desc = fn map ->
        map |> Enum.sort_by(fn {_, c} -> c end, :desc)
      end

      %{
        stats_all: sort_desc.(by_country_all),
        total_all: total_all,
        stats_1h: sort_desc.(by_country_1h),
        total_1h: total_1h
      }
    end
  end

  # --- Internal ---

  defp current_minute, do: System.system_time(:second) |> div(60)

  defp minute_cutoff(:all), do: 0
  defp minute_cutoff(:hour), do: current_minute() - 60
  defp minute_cutoff(:day), do: current_minute() - 1440
  defp minute_cutoff(:week), do: current_minute() - 10_080

  defp increment(country) do
    if :ets.whereis(@table) != :undefined do
      minute = current_minute()
      :ets.update_counter(@table, {country, minute}, {2, 1}, {{country, minute}, 0})
    end
  end
end
