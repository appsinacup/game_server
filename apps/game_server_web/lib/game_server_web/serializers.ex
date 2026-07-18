defmodule GameServerWeb.Serializers do
  @moduledoc """
  Shared JSON payload serializers used by API controllers and channels.
  """

  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.Groups
  alias GameServer.Lobbies
  alias GameServer.Lobbies.SpectatorTracker
  alias GameServer.Parties

  @spec display_name(integer() | nil) :: String.t()
  def display_name(nil), do: ""

  def display_name(user_id) do
    case Accounts.get_user(user_id) do
      %{display_name: name} when is_binary(name) -> name
      _ -> ""
    end
  end

  @spec serialize_notification(term()) :: map()
  def serialize_notification(notification) do
    sender = loaded_assoc(notification, :sender)

    %{
      id: notification.id,
      sender_id: notification.sender_id,
      sender_name: assoc_display_name(sender),
      recipient_id: notification.recipient_id,
      title: notification.title,
      content: notification.content || "",
      metadata: notification.metadata || %{},
      inserted_at: notification.inserted_at
    }
  end

  @spec serialize_chat_message(term(), keyword()) :: map()
  def serialize_chat_message(message, opts \\ []) do
    sender = loaded_assoc(message, :sender)

    %{
      id: message.id,
      content: message.content,
      metadata: message.metadata || %{},
      sender_id: message.sender_id,
      sender_name: assoc_display_name(sender),
      chat_type: message.chat_type,
      chat_ref_id: message.chat_ref_id,
      inserted_at: message.inserted_at
    }
    |> maybe_put(:updated_at, message.updated_at, Keyword.get(opts, :include_updated_at, false))
    |> maybe_put(
      :sender_email,
      if(sender, do: sender.email, else: ""),
      Keyword.get(opts, :include_sender_email, false)
    )
  end

  @spec serialize_user_achievement(term()) :: map()
  def serialize_user_achievement(user_achievement) do
    %{
      id: user_achievement.id,
      user_id: user_achievement.user_id,
      achievement_id: user_achievement.achievement_id,
      progress: user_achievement.progress,
      unlocked_at: user_achievement.unlocked_at,
      metadata: user_achievement.metadata || %{},
      inserted_at: user_achievement.inserted_at,
      updated_at: user_achievement.updated_at
    }
  end

  @spec serialize_lobby(term(), keyword()) :: map()
  def serialize_lobby(lobby, opts \\ []) do
    host = loaded_assoc(lobby, :host)

    %{
      id: lobby.id,
      title: lobby.title,
      host_id: lobby.host_id || "",
      host_name: assoc_or_lookup_display_name(host, lobby.host_id),
      hostless: lobby.hostless,
      max_users: lobby.max_users,
      is_hidden: lobby.is_hidden,
      is_locked: lobby.is_locked,
      metadata: lobby.metadata || %{}
    }
    |> maybe_put(
      :is_passworded,
      lobby.password_hash != nil,
      Keyword.get(opts, :include_passworded, false)
    )
    |> maybe_put(:slowdown, lobby.slowdown, Keyword.get(opts, :include_slowdown, false))
    |> maybe_put(
      :spectator_count,
      SpectatorTracker.count(lobby.id),
      Keyword.get(opts, :include_spectator_count, false)
    )
    |> maybe_put(
      :members,
      serialize_lobby_members(lobby),
      Keyword.get(opts, :include_members, false)
    )
  end

  # Uses members already loaded onto the struct (e.g. by the broadcast source)
  # so the per-socket channel fan-out never re-queries; falls back to a single
  # query for callers that pass a bare lobby (HTTP controllers).
  defp serialize_lobby_members(lobby) do
    case loaded_assoc(lobby, :memberships) do
      nil -> Lobbies.get_lobby_members(lobby)
      members -> members
    end
    |> Enum.map(&User.serialize_brief/1)
  end

  @spec serialize_group(term(), keyword()) :: map()
  def serialize_group(group, opts \\ []) do
    creator = loaded_assoc(group, :creator)

    %{
      id: group.id,
      title: group.title,
      description: group.description || "",
      type: group.type,
      max_members: group.max_members,
      creator_id: response_id(group.creator_id),
      creator_name: assoc_or_lookup_display_name(creator, group.creator_id),
      metadata: group.metadata || %{}
    }
    |> maybe_put(:member_count, member_count(group, opts), include_member_count?(opts))
    |> maybe_put(:slowdown, group.slowdown, Keyword.get(opts, :include_slowdown, false))
    |> maybe_put(:inserted_at, group.inserted_at, Keyword.get(opts, :include_timestamps, false))
    |> maybe_put(:updated_at, group.updated_at, Keyword.get(opts, :include_timestamps, false))
  end

  @spec serialize_party(term(), keyword()) :: map()
  def serialize_party(party, opts \\ []) do
    leader = loaded_assoc(party, :leader)

    %{
      id: party.id,
      leader_id: party.leader_id,
      leader_name: assoc_or_lookup_display_name(leader, party.leader_id),
      max_size: party.max_size,
      metadata: party.metadata || %{},
      members: serialize_party_members(party)
    }
    |> maybe_put(:inserted_at, party.inserted_at, Keyword.get(opts, :include_timestamps, false))
    |> maybe_put(:updated_at, party.updated_at, Keyword.get(opts, :include_timestamps, false))
  end

  # Uses members already loaded onto the struct (e.g. by the broadcast source)
  # so the per-socket channel fan-out never re-queries.
  defp serialize_party_members(party) do
    case loaded_assoc(party, :members) do
      nil -> Parties.get_party_members(party.id)
      members -> members
    end
    |> Enum.map(&User.serialize_brief/1)
  end

  defp loaded_assoc(struct, field) do
    value = Map.get(struct, field)

    if Ecto.assoc_loaded?(value), do: value, else: nil
  end

  defp assoc_display_name(nil), do: ""
  defp assoc_display_name(%{display_name: name}) when is_binary(name), do: name
  defp assoc_display_name(_assoc), do: ""

  defp assoc_or_lookup_display_name(_assoc, nil), do: ""
  defp assoc_or_lookup_display_name(%{} = assoc, _id), do: assoc_display_name(assoc)
  defp assoc_or_lookup_display_name(_assoc, id), do: display_name(id)

  defp response_id(nil), do: -1
  defp response_id(id), do: id

  defp maybe_put(map, _key, _value, false), do: map
  defp maybe_put(map, key, value, true), do: Map.put(map, key, value)

  defp include_member_count?(opts) do
    Keyword.has_key?(opts, :member_counts) || Keyword.get(opts, :include_member_count, false)
  end

  defp member_count(group, opts) do
    member_counts = Keyword.get(opts, :member_counts)

    if is_map(member_counts) do
      Map.get(member_counts, group.id) || Groups.count_group_members(group.id)
    else
      Groups.count_group_members(group.id)
    end
  end
end
