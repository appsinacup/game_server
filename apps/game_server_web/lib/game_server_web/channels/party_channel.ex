defmodule GameServerWeb.PartyChannel do
  @moduledoc """
  Channel for party realtime events.

  Topic: "party:<party_id>"

  Only users who are members of the party may join this channel.
  Membership is determined by the user's `party_id` field.

  ## Events pushed to clients

  - `"member_joined"` - A user joined the party. Payload: `%{user_id: integer}`
  - `"member_left"` - A user left or was kicked from the party. Payload: `%{user_id: integer}`
  - `"updated"` - The party settings were updated. Payload: party object
  - `"disbanded"` - The party was disbanded. Payload: `%{party_id: integer}`
  """

  use Phoenix.Channel
  require Logger

  alias GameServer.Accounts
  alias GameServer.Accounts.Scope
  alias GameServer.Accounts.User
  alias GameServer.Parties

  @impl true
  def join("party:" <> party_id_str, _payload, socket) do
    current_scope = Map.get(socket.assigns, :current_scope)

    with {party_id, ""} <- Integer.parse(party_id_str),
         %Scope{user: %{id: user_id}} <- current_scope do
      case Accounts.get_user(user_id) do
        %User{party_id: ^party_id} ->
          # Subscribe to party PubSub events to forward to WebSocket clients
          socket =
            if Map.get(socket.assigns, :subscribed_party, false) do
              socket
            else
              _ = Parties.unsubscribe_party(party_id)
              Parties.subscribe_party(party_id)
              assign(socket, :subscribed_party, true)
            end

          party = Parties.get_party(party_id)
          send(self(), {:after_join, party})
          {:ok, socket |> assign(:party_id, party_id)}

        _ ->
          Logger.info(
            "PartyChannel: user #{user_id} attempted to join party #{party_id} but is not a member"
          )

          {:error, %{reason: "not_a_member"}}
      end
    else
      _ ->
        {:error, %{reason: "invalid_topic_or_unauthenticated"}}
    end
  end

  # Handle PubSub messages and forward them to WebSocket clients

  @impl true
  def handle_info({:party_member_joined, _party_id, user_id}, socket) do
    push(socket, "member_joined", %{user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_member_left, _party_id, user_id}, socket) do
    push(socket, "member_left", %{user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_updated, %GameServer.Parties.Party{} = party}, socket) do
    payload = serialize_party(party)
    last_payload = Map.get(socket.assigns, :last_party_payload)

    if last_payload == payload do
      {:noreply, socket}
    else
      push(socket, "updated", payload)
      {:noreply, assign(socket, :last_party_payload, payload)}
    end
  end

  @impl true
  def handle_info({:party_updated, party_id}, socket) when is_integer(party_id) do
    case Parties.get_party(party_id) do
      nil ->
        {:noreply, socket}

      party ->
        payload = serialize_party(party)
        last_payload = Map.get(socket.assigns, :last_party_payload)

        if last_payload == payload do
          {:noreply, socket}
        else
          push(socket, "updated", payload)
          {:noreply, assign(socket, :last_party_payload, payload)}
        end
    end
  end

  @impl true
  def handle_info({:party_disbanded, party_id}, socket) do
    push(socket, "disbanded", %{party_id: party_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, nil}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, party}, socket) do
    payload = serialize_party(party)
    push(socket, "updated", payload)
    {:noreply, assign(socket, :last_party_payload, payload)}
  end

  # Ignore other messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns do
      %{party_id: party_id} when is_integer(party_id) ->
        _ = Parties.unsubscribe_party(party_id)
        :ok

      _ ->
        :ok
    end
  end

  defp serialize_party(party) do
    %{
      id: party.id,
      leader_id: party.leader_id,
      max_size: party.max_size,
      code: party.code,
      metadata: party.metadata || %{}
    }
  end
end
