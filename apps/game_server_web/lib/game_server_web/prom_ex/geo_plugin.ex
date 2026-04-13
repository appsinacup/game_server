defmodule GameServerWeb.PromEx.GeoPlugin do
  @moduledoc """
  Custom PromEx plugin that exports geo-traffic Prometheus metrics.

  Tracks:

  - `game_server_geo_requests_total` — counter, tagged by `country`
    (ISO 3166-1 alpha-2 code, or "XX" for unknown).

  The telemetry event `[:game_server, :geo, :request]` is emitted by
  `GameServerWeb.Plugs.GeoCountry` on every HTTP request.
  """

  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    [
      Event.build(
        :game_server_geo_request_metrics,
        [
          counter(
            [:game_server, :geo, :requests, :total],
            event_name: [:game_server, :geo, :request],
            measurement: :count,
            description: "Total HTTP requests by country code.",
            tags: [:country]
          )
        ]
      )
    ]
  end
end
