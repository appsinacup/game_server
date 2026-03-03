defmodule GameServerWeb.PlayLive do
  @moduledoc """
  LiveView wrapper that embeds the Godot web export (`/game/index.html`)
  inside the app layout so the navbar is visible.

  The game itself runs in an iframe with its own COOP/COEP headers
  (set by `GameServerWeb.Plugs.GameHeaders`) so `SharedArrayBuffer` works.
  """
  use GameServerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} flush>
      <div
        id="game-container"
        class="relative w-full overflow-hidden"
        style="height: calc(100vh - 4rem);"
      >
        <iframe
          id="game-frame"
          src="/game/index.html"
          class="w-full h-full border-0"
          allow="autoplay; fullscreen"
          allowfullscreen
          phx-update="ignore"
        >
        </iframe>

        <button
          id="fullscreen-btn"
          phx-hook="Fullscreen"
          phx-update="ignore"
          data-target="game-container"
          class={[
            "absolute bottom-4 right-4 z-10",
            "bg-black/60 hover:bg-black/80 text-white rounded-full p-2 shadow-lg transition-colors cursor-pointer"
          ]}
          title="Toggle fullscreen"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-5 h-5"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path
              fill-rule="evenodd"
              d="M4.25 2A2.25 2.25 0 002 4.25v2.5a.75.75 0 001.5 0v-2.5a.75.75 0 01.75-.75h2.5a.75.75 0 000-1.5h-2.5zM13.25 2a.75.75 0 000 1.5h2.5a.75.75 0 01.75.75v2.5a.75.75 0 001.5 0v-2.5A2.25 2.25 0 0015.75 2h-2.5zM2 13.25a.75.75 0 011.5 0v2.5a.75.75 0 00.75.75h2.5a.75.75 0 010 1.5h-2.5A2.25 2.25 0 012 15.75v-2.5zM16.5 13.25a.75.75 0 011.5 0v2.5A2.25 2.25 0 0115.75 18h-2.5a.75.75 0 010-1.5h2.5a.75.75 0 00.75-.75v-2.5z"
              clip-rule="evenodd"
            />
          </svg>
        </button>
      </div>
    </Layouts.app>
    """
  end
end
