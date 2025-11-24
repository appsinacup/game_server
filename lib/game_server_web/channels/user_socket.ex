defmodule GameServerWeb.UserSocket do
  use Phoenix.Socket
  require Logger

  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics.

  ## Channels
  # Register the user_updates channel for per-user realtime events
  channel "user_updates:*", GameServerWeb.UserUpdatesChannel

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
  # If a token is present we verify it and load the user resource. If no
  # token is present we allow an anonymous socket (some channels may still
  # reject joins that require authentication).
  def connect(params, socket, _connect_info) do
    case extract_token(params) do
      token when is_binary(token) ->
        case GameServerWeb.Auth.Guardian.decode_and_verify(token) do
          {:ok, claims} ->
            case GameServerWeb.Auth.Guardian.resource_from_claims(claims) do
              {:ok, user} ->
                socket = assign(socket, :current_scope, GameServer.Accounts.Scope.for_user(user))
                {:ok, socket}

              _ ->
                :error
            end

          _ ->
            :error
        end

      _ ->
        {:ok, socket}
    end
  end

  # Extract token from various parameter shapes:
  # - ChannelTest passes %{params: %{"token" => ...}, ...}
  # - Real WebSocket might pass %{"token" => ...} directly
  defp extract_token(%{params: %{"token" => token}}), do: token
  defp extract_token(%{"params" => %{"token" => token}}), do: token
  defp extract_token(%{"token" => token}), do: token
  defp extract_token(%{token: token}), do: token
  defp extract_token(_), do: nil

  # Socket IDs are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.GameServerWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil
end
