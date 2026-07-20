defmodule GameServer.Notifications.Types do
  @moduledoc """
  The `metadata["type"]` codes a notification may carry.

  A notification's type is never read by the server — it exists purely so a
  client can decide how to render and route it. That makes an unregistered code
  fail silently: the server stores and delivers it happily, and the client
  simply never handles it. So the set is closed. `GameServer.Notifications`
  rejects an unknown code at write time, and this module is the list clients
  can rely on.

  Plugins add their own by exporting `notification_types/0` (see
  `GameServer.Hooks.Declarations`); those merge with the core codes below.
  """

  alias GameServer.Hooks.Declarations

  @core %{
    "friend_request" => "Someone sent a friend request",
    "friend_accepted" => "A friend request was accepted",
    "friend_rejected" => "A friend request was rejected",
    "group_invite" => "Invited to a group",
    "group_invite_accepted" => "A group invite was accepted",
    "group_invite_declined" => "A group invite was declined",
    "group_join_request" => "Someone asked to join a group you administer",
    "group_join_request_approved" => "A group join request was approved",
    "group_join_request_rejected" => "A group join request was rejected",
    "group_kicked" => "Removed from a group",
    "group_promoted" => "Promoted within a group",
    "group_demoted" => "Demoted within a group",
    "party_invite" => "Invited to a party",
    "party_invite_accepted" => "A party invite was accepted",
    "party_invite_declined" => "A party invite was declined",
    "party_kicked" => "Removed from a party",
    "lobby_kicked" => "Removed from a lobby"
  }

  @doc "Core notification codes, mapped to their description."
  @spec core() :: %{String.t() => String.t()}
  def core, do: @core

  @doc "Core plus plugin-declared codes."
  @spec all() :: %{String.t() => String.t()}
  def all, do: Map.merge(Declarations.notification_types(), @core)

  @doc "True when `code` is declared by core or a loaded plugin."
  @spec known?(term()) :: boolean()
  def known?(code) when is_binary(code), do: Map.has_key?(all(), code)
  def known?(_code), do: false
end
