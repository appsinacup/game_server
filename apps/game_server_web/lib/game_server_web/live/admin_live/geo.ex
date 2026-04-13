defmodule GameServerWeb.AdminLive.Geo do
  use GameServerWeb, :live_view

  alias GameServerWeb.Plugs.GeoCountry

  @refresh_interval 5_000

  @windows [
    {"1h", :hour},
    {"24h", :day},
    {"7d", :week},
    {"All", :all}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="space-y-4">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div class="flex items-center gap-3">
            <.link navigate={~p"/admin"} class="btn btn-outline btn-sm">&larr; Admin</.link>
            <h1 class="text-xl font-bold">Geo Traffic</h1>
          </div>

          <div class="flex items-center gap-3">
            <span class="text-xs text-base-content/60">
              Source:
              <span class="font-semibold">
                {if(@geoip_available?, do: "MMDB database", else: "CF-IPCountry header")}
              </span>
            </span>
            <button
              phx-click="reset_stats"
              data-confirm="Reset all geo traffic counters to zero?"
              class="btn btn-outline btn-error btn-xs"
            >
              Reset
            </button>
          </div>
        </div>

        <%!-- Time window selector --%>
        <div class="flex flex-wrap gap-2">
          <button
            :for={{label, window} <- @windows}
            phx-click="set_window"
            phx-value-window={window}
            class={[
              "btn btn-sm",
              if(@window == window, do: "btn-primary", else: "btn-ghost")
            ]}
          >
            {label}
          </button>
        </div>

        <%!-- Summary stats --%>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <div class="card bg-base-100 p-3 text-center">
            <div class="text-2xl font-bold font-mono">{format_number(@total)}</div>
            <div class="text-xs text-base-content/60">Requests</div>
          </div>
          <div class="card bg-base-100 p-3 text-center">
            <div class="text-2xl font-bold font-mono">{length(@stats)}</div>
            <div class="text-xs text-base-content/60">Countries</div>
          </div>
          <div class="card bg-base-100 p-3 text-center">
            <div class="text-2xl font-bold font-mono">
              {if(@top_country, do: "#{country_flag(elem(@top_country, 0))} #{elem(@top_country, 0)}", else: "—")}
            </div>
            <div class="text-xs text-base-content/60">Top Country</div>
          </div>
          <div class="card bg-base-100 p-3 text-center">
            <div class="text-2xl font-bold font-mono">{@unknown_count}</div>
            <div class="text-xs text-base-content/60">Unknown (XX)</div>
          </div>
        </div>

        <%!-- MMDB status --%>
        <div :if={!@geoip_available?} class="alert alert-warning text-sm">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <div>
            <div class="font-semibold">No GeoIP database loaded</div>
            <div class="text-xs opacity-80">
              All requests are counted as "XX" (Unknown). Download
              <a
                href="https://dev.maxmind.com/geoip/geolite2-free-geolocation-data"
                target="_blank"
                class="link"
              >
                GeoLite2-Country.mmdb
              </a>
              and set <code class="bg-base-200 px-1 rounded">GEOIP_DB_PATH</code> to enable country resolution.
            </div>
          </div>
        </div>

        <%!-- Filter & sort --%>
        <div class="flex flex-col sm:flex-row gap-2 items-start sm:items-center">
          <.form for={%{}} id="geo-filter" phx-change="update_filter" class="flex-1 w-full sm:w-auto">
            <input
              id="geo-search"
              name="search"
              value={@search}
              placeholder="Filter by country code (e.g. US, DE, XX)"
              class="input input-sm w-full"
              phx-debounce="300"
            />
          </.form>
          <div class="flex items-center gap-2 text-xs text-base-content/60">
            <span>Sort:</span>
            <button
              phx-click="toggle_sort"
              class="btn btn-ghost btn-xs"
            >
              {if @sort == :count, do: "By Count ↓", else: "By Code A→Z"}
            </button>
          </div>
        </div>

        <%!-- Country table --%>
        <div class="card bg-base-100 overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr class="text-xs text-base-content/60">
                <th class="w-8">#</th>
                <th>Country</th>
                <th class="text-right">Requests</th>
                <th class="text-right w-20">%</th>
                <th class="w-1/3">Distribution</th>
              </tr>
            </thead>
            <tbody>
              <%= if @filtered_stats == [] do %>
                <tr>
                  <td colspan="5" class="text-center py-8 text-base-content/40">
                    <%= if @stats == [] do %>
                      No geo data yet — traffic will appear as requests come in
                    <% else %>
                      No countries match your filter
                    <% end %>
                  </td>
                </tr>
              <% else %>
                <tr :for={{idx, country, count, pct} <- @filtered_stats} class={[
                  country == "XX" && "opacity-60"
                ]}>
                  <td class="font-mono text-base-content/40">{idx}</td>
                  <td>
                    <span class="text-lg mr-1">{country_flag(country)}</span>
                    <span class="font-mono font-semibold">{country}</span>
                    <span :if={country == "XX"} class="text-xs text-base-content/40 ml-1">(Unknown)</span>
                  </td>
                  <td class="text-right font-mono">{format_number(count)}</td>
                  <td class="text-right font-mono text-base-content/60">{pct}%</td>
                  <td>
                    <div class="w-full bg-base-200 rounded-full h-2">
                      <div
                        class={[
                          "h-2 rounded-full transition-all duration-500",
                          bar_color(idx)
                        ]}
                        style={"width: #{pct}%"}
                      >
                      </div>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Footer --%>
        <div class="text-xs text-base-content/40 text-center">
          Auto-refreshes every {div(@refresh_interval, 1000)}s &middot;
          7-day retention &middot;
          Data is in-memory (ETS) &middot;
          Exported to Prometheus as <code class="bg-base-200 px-1 rounded">game_server_geo_requests_total</code>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    window = :all
    stats = GeoCountry.country_stats(window: window)
    total = GeoCountry.total_requests(window: window)

    {:ok,
     socket
     |> assign(
       stats: stats,
       total: total,
       window: window,
       windows: @windows,
       geoip_available?: GeoCountry.geoip_available?(),
       search: "",
       sort: :count,
       refresh_interval: @refresh_interval
     )
     |> compute_derived()}
  end

  @impl true
  def handle_event("set_window", %{"window" => window_str}, socket) do
    window = String.to_existing_atom(window_str)
    stats = GeoCountry.country_stats(window: window)
    total = GeoCountry.total_requests(window: window)

    {:noreply,
     socket
     |> assign(stats: stats, total: total, window: window)
     |> compute_derived()}
  end

  @impl true
  def handle_event("update_filter", %{"search" => search}, socket) do
    {:noreply, socket |> assign(search: String.upcase(String.trim(search))) |> compute_derived()}
  end

  @impl true
  def handle_event("toggle_sort", _params, socket) do
    new_sort = if socket.assigns.sort == :count, do: :alpha, else: :count
    {:noreply, socket |> assign(sort: new_sort) |> compute_derived()}
  end

  @impl true
  def handle_event("reset_stats", _params, socket) do
    GeoCountry.reset_stats()

    {:noreply,
     socket
     |> assign(stats: [], total: 0)
     |> compute_derived()
     |> put_flash(:info, "Geo traffic counters reset.")}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    window = socket.assigns.window
    stats = GeoCountry.country_stats(window: window)
    total = GeoCountry.total_requests(window: window)

    {:noreply,
     socket
     |> assign(stats: stats, total: total, geoip_available?: GeoCountry.geoip_available?())
     |> compute_derived()}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # --- Derived state ---

  defp compute_derived(socket) do
    %{stats: stats, total: total, search: search, sort: sort} = socket.assigns

    sorted =
      case sort do
        :count -> stats
        :alpha -> Enum.sort_by(stats, fn {country, _} -> country end)
      end

    filtered =
      if search == "" do
        sorted
      else
        Enum.filter(sorted, fn {country, _} -> String.contains?(country, search) end)
      end

    # Add rank, percentage
    filtered_with_meta =
      filtered
      |> Enum.with_index(1)
      |> Enum.map(fn {{country, count}, idx} ->
        pct = if total > 0, do: Float.round(count / total * 100, 1), else: 0.0
        {idx, country, count, pct}
      end)

    top_country = List.first(stats)
    unknown_count = Enum.find_value(stats, 0, fn {c, cnt} -> if c == "XX", do: cnt end)

    assign(socket,
      filtered_stats: filtered_with_meta,
      top_country: top_country,
      unknown_count: unknown_count
    )
  end

  # --- Helpers ---

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

  defp format_number(n) when is_integer(n) and n >= 1_000_000 do
    "#{Float.round(n / 1_000_000, 1)}M"
  end

  defp format_number(n) when is_integer(n) and n >= 1_000 do
    "#{Float.round(n / 1_000, 1)}K"
  end

  defp format_number(n) when is_number(n), do: to_string(n)
  defp format_number(n), do: to_string(n)

  defp country_flag(code) when is_binary(code) and byte_size(code) == 2 do
    code
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(fn c -> c - ?A + 0x1F1E6 end)
    |> List.to_string()
  rescue
    _ -> "🌐"
  end

  defp country_flag(_), do: "🌐"

  defp bar_color(rank) when rank <= 1, do: "bg-primary"
  defp bar_color(rank) when rank <= 3, do: "bg-secondary"
  defp bar_color(rank) when rank <= 5, do: "bg-accent"
  defp bar_color(_), do: "bg-base-content/20"
end
