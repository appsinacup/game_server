defmodule GameServerWeb.RoadmapLive do
  @moduledoc false

  use GameServerWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    host_live().mount(params, session, socket)
  end

  @impl true
  def render(assigns) do
    host_live().render(assigns)
  end

  defp host_live, do: Module.concat(GameServerWeb, HostRoadmapLive)
end
