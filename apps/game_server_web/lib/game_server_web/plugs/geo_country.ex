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

  Also maintains an **in-memory ETS aggregate** of request counts by country
  for the admin dashboard.

  ## Configuration

  To enable Geolix lookup, set in your environment:

      GEOIP_DB_PATH=/path/to/GeoLite2-Country.mmdb

  Download the free database from:
  https://dev.maxmind.com/geoip/geolite2-free-geolocation-data
  """

  import Plug.Conn

  @behaviour Plug

  @table :geo_country_stats

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    country = resolve_country(conn)

    if country do
      increment(country)
    end

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
  """
  def country_stats do
    if :ets.whereis(@table) != :undefined do
      @table
      |> :ets.tab2list()
      |> Enum.sort_by(fn {_country, count} -> count end, :desc)
    else
      []
    end
  end

  @doc """
  Returns the total number of tracked requests across all countries.
  """
  def total_requests do
    if :ets.whereis(@table) != :undefined do
      :ets.foldl(fn {_country, count}, acc -> acc + count end, 0, @table)
    else
      0
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
  Returns whether Geolix has a country database loaded.
  """
  def geoip_available? do
    case Application.get_env(:geolix, :databases) do
      databases when is_list(databases) and databases != [] -> true
      _ -> false
    end
  end

  # --- Internal ---

  defp increment(country) do
    if :ets.whereis(@table) != :undefined do
      :ets.update_counter(@table, country, {2, 1}, {country, 0})
    end
  end
end
