defmodule GameServerWeb.GroupsChannel do
  @moduledoc """
  Channel for broadcasting global group list events.

  Topic: "groups"

  Clients may join this topic to receive real-time notifications when groups
  are created, updated, or deleted. Hidden groups are excluded from broadcasts.

  ## Events pushed to clients

  - `"group_created"` - A new group was created. Payload: group object
  - `"group_updated"` - A group was updated. Payload: group object
  - `"group_deleted"` - A group was deleted. Payload: `%{id: integer}`
  """

  use Phoenix.Channel

  alias GameServer.Groups

  @impl true
  def join("groups", _payload, socket) do
    Groups.subscribe_groups()
    {:ok, socket}
  end

  @impl true
  def handle_info({:group_created, group}, socket) do
    # Don't broadcast hidden groups to the public list channel
    if group.type != "hidden" do
      push(socket, "group_created", serialize_group(group))
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:group_updated, group}, socket) do
    if group.type != "hidden" do
      push(socket, "group_updated", serialize_group(group))
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:group_deleted, group_id}, socket) do
    push(socket, "group_deleted", %{id: group_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp serialize_group(group) do
    creator_name =
      cond do
        is_nil(group.creator_id) ->
          ""

        Ecto.assoc_loaded?(group.creator) and group.creator != nil ->
          group.creator.display_name || ""

        true ->
          resolve_display_name(group.creator_id)
      end

    %{
      id: group.id,
      title: group.title,
      description: group.description || "",
      type: group.type,
      max_members: group.max_members,
      creator_id: group.creator_id,
      creator_name: creator_name,
      metadata: group.metadata || %{}
    }
  end

  defp resolve_display_name(nil), do: ""

  defp resolve_display_name(user_id) do
    case GameServer.Accounts.get_user(user_id) do
      %{display_name: name} when is_binary(name) -> name
      _ -> ""
    end
  end
end
