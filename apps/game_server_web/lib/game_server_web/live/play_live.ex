defmodule GameServerWeb.PlayLive do
  @moduledoc """
  LiveView wrapper that embeds the Godot web export (`/game/index.html`)
  inside the app layout so the navbar is visible.

  The game itself runs in an iframe with its own COOP/COEP headers
  (set by `GameServerWeb.Plugs.GameHeaders`) so `SharedArrayBuffer` works.

  When the user is session-authenticated, this LiveView mints a short-lived
  JWT access-token (and a refresh-token) so the Godot game can call the API.
  Tokens are delivered in two ways:

    1. **URL fragment** – the iframe `src` becomes
       `/game/index.html#access_token=…&refresh_token=…`
       (fragment never leaves the browser).
    2. **localStorage** – a JS hook writes `gamend_access_token` and
       `gamend_refresh_token` so the game can also read them with
       `JavaScriptBridge.eval("localStorage.getItem('gamend_access_token')")`.
  """
  use GameServerWeb, :live_view

  alias GameServerWeb.Auth.Guardian

  @impl true
  def mount(_params, _session, socket) do
    {game_src, token_data} = build_game_url(socket.assigns.current_scope)

    {:ok,
     assign(socket,
       game_src: game_src,
       token_data: token_data
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_path={assigns[:current_path]}
      flush
    >
      <div
        id="game-container"
        phx-hook="GameViewport"
        class="relative w-full h-full overflow-hidden"
      >
        <div
          id="game-auth"
          phx-hook="GameAuth"
          phx-update="ignore"
          data-access-token={@token_data[:access_token] || ""}
          data-refresh-token={@token_data[:refresh_token] || ""}
        >
        </div>

        <iframe
          id="game-frame"
          src={@game_src}
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
            "hidden absolute bottom-4 right-4 z-10",
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

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp build_game_url(nil), do: {"/game/index.html", %{}}
  defp build_game_url(%{user: nil}), do: {"/game/index.html", %{}}

  defp build_game_url(%{user: user}) do
    with {:ok, access_token, _claims} <-
           Guardian.encode_and_sign(user, %{}, token_type: "access"),
         {:ok, refresh_token, _claims} <-
           Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days}) do
      fragment =
        URI.encode_query(%{
          "access_token" => access_token,
          "refresh_token" => refresh_token
        })

      {"/game/index.html##{fragment}",
       %{access_token: access_token, refresh_token: refresh_token}}
    else
      _error ->
        {"/game/index.html", %{}}
    end
  end
end
