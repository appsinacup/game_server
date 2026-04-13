defmodule GameServerWeb.PromEx do
  @moduledoc """
  Prometheus metrics exporter using PromEx.

  Auto-instruments Phoenix, Ecto, BEAM VM, and Application metrics.
  Exposes a `/metrics` endpoint for Prometheus scraping (or Grafana Agent).

  ## Plugins enabled

  | Plugin | What it tracks |
  |--------|----------------|
  | `PromEx.Plugins.Beam` | VM memory, schedulers, atoms, processes, ports, ETS |
  | `PromEx.Plugins.Phoenix` | HTTP request count, duration, status by route |
  | `PromEx.Plugins.Ecto` | Query count, duration, queue time per source |
  | `PromEx.Plugins.Application` | App info (version, git SHA), uptime |

  ## Configuration

  Set `METRICS_ENABLED=false` to disable (default: enabled).

  The `/metrics` endpoint is public by design (Prometheus scrapes it).
  In production, restrict access at the network/firewall level or via
  the `METRICS_AUTH_TOKEN` env var (Bearer token check).
  """

  use PromEx, otp_app: :game_server_web

  @impl true
  def plugins do
    [
      # BEAM VM metrics (memory, schedulers, processes, etc.)
      PromEx.Plugins.Beam,

      # Phoenix HTTP request metrics (count, duration, status by route)
      {PromEx.Plugins.Phoenix, router: GameServerWeb.Router, endpoint: GameServerWeb.Endpoint},

      # Ecto database metrics (query count, duration, queue time)
      {PromEx.Plugins.Ecto, repos: [GameServer.Repo]},

      # Application info & uptime
      {PromEx.Plugins.Application, otp_app: :game_server_web}
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"}
    ]
  end
end
