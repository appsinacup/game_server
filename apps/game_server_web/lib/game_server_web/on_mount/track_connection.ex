defmodule GameServerWeb.OnMount.TrackConnection do
  @moduledoc """
  LiveView on_mount hook that registers the LiveView process with
  `GameServerWeb.ConnectionTracker` when the socket is connected.

  Stores the LiveView module name and user info for richer monitoring.
  The process auto-deregisters when the LiveView terminates.
  """

  import Phoenix.LiveView, only: [connected?: 1]

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      view_module = socket.view |> to_string() |> String.replace("Elixir.", "")
      scope = Map.get(socket.assigns, :current_scope)
      user_id = if scope, do: scope.user && scope.user.id

      GameServerWeb.ConnectionTracker.register(:live_view, %{
        module: view_module,
        user_id: user_id
      })
    end

    {:cont, socket}
  end
end
