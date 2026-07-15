defmodule GameServerWeb.UserSocket do
  use Phoenix.Socket

  alias GameServer.Accounts.Scope
  alias GameServerWeb.Auth.Guardian

  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics.

  ## Channels
  # Register the user channel for per-user realtime events
  channel "user:*", GameServerWeb.UserChannel

  # Lobby channels - join workspace level lobby topics (members only)
  channel "lobby:*", GameServerWeb.LobbyChannel

  # Global lobbies channel for list updates and membership-change notifications
  channel "lobbies", GameServerWeb.LobbiesChannel

  # Group channels - per-group events for members
  channel "group:*", GameServerWeb.GroupChannel

  # Global groups channel for list updates (new/updated/deleted groups)
  channel "groups", GameServerWeb.GroupsChannel

  # Party channels - per-party events for members
  channel "party:*", GameServerWeb.PartyChannel

  # Uncomment the following line to define a "room:*" topic
  # pointing to the `GameServerWeb.RoomChannel`:
  #
  # channel "room:*", GameServerWeb.RoomChannel
  #
  # To create a channel file, use the mix task:
  #
  #     mix phx.gen.channel Room
  #
  # See the [`Channels guide`](https://hexdocs.pm/phoenix/channels.html)
  # for further details.

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error` or `{:error, term}`. To control the
  # response the client receives in that case, [define an error handler in the
  # websocket
  # configuration](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-websocket-configuration).
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  # Generic connect that attempts to extract a token from a variety of
  # param shapes (plain map, nested under "params" or :params, etc.).
  # Unauthenticated connections are rejected (connection-exhaustion DoS
  # guard) — all channel functionality requires a valid JWT token — and
  # each user may hold at most :max_sockets_per_user concurrent sockets.
  def connect(params, socket, _connect_info) do
    with token when is_binary(token) <- extract_token(params),
         {:ok, claims} <- Guardian.decode_and_verify(token),
         {:ok, user} <- Guardian.resource_from_claims(claims),
         false <- socket_limit_reached?(user.id) do
      GameServerWeb.ConnectionTracker.register(:ws_socket, %{
        user_id: user.id,
        authenticated: true
      })

      {:ok, assign(socket, :current_scope, Scope.for_user(user))}
    else
      _ -> :error
    end
  end

  # 0 disables; counted per app instance.
  defp socket_limit_reached?(user_id) do
    limit = GameServer.Limits.get(:max_sockets_per_user)

    is_integer(limit) and limit > 0 and
      GameServerWeb.ConnectionTracker.list_registered(:ws_socket)
      |> Enum.count(fn {_pid, meta} -> Map.get(meta, :user_id) == user_id end) >= limit
  end

  # Extract token from various parameter shapes:
  # - ChannelTest passes %{params: %{"token" => ...}, ...}
  # - Real WebSocket might pass %{"token" => ...} directly
  defp extract_token(%{params: %{"token" => token}}), do: token
  defp extract_token(%{"params" => %{"token" => token}}), do: token
  defp extract_token(%{"token" => token}), do: token
  defp extract_token(%{token: token}), do: token
  defp extract_token(_), do: nil

  # Return a user-scoped socket ID so we can force-disconnect a specific user:
  #
  #     GameServerWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  @impl true
  def id(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{id: user_id}} -> "user_socket:#{user_id}"
      _ -> nil
    end
  end
end
