defmodule GameServer.NotificationTypesTest do
  @moduledoc """
  Notification codes are a closed set. The server never reads the type, so an
  unregistered code would be delivered and silently ignored by every client —
  it is rejected at write time instead.
  """
  use GameServer.DataCase

  alias GameServer.AccountsFixtures
  alias GameServer.Notifications
  alias GameServer.Notifications.Types

  defp pair do
    {AccountsFixtures.user_fixture(), AccountsFixtures.user_fixture()}
  end

  test "every code emitted by core is registered" do
    # The 17 codes core actually sends; a new emission without a registry entry
    # fails here before it can reach a client.
    for code <- ~w(friend_request friend_accepted friend_rejected
                   group_invite group_invite_accepted group_invite_declined
                   group_join_request group_join_request_approved group_join_request_rejected
                   group_kicked group_promoted group_demoted
                   party_invite party_invite_accepted party_invite_declined party_kicked
                   lobby_kicked) do
      assert Types.known?(code), "core code #{code} is not registered"
    end
  end

  test "a registered code is accepted" do
    {sender, recipient} = pair()

    assert {:ok, notification} =
             Notifications.admin_create_notification(sender.id, recipient.id, %{
               "title" => "Friend request",
               "metadata" => %{"type" => "friend_request"}
             })

    assert notification.metadata["type"] == "friend_request"
  end

  test "an unregistered code is rejected" do
    {sender, recipient} = pair()

    assert {:error, changeset} =
             Notifications.admin_create_notification(sender.id, recipient.id, %{
               "title" => "Mystery",
               "metadata" => %{"type" => "not_a_real_code"}
             })

    assert "unknown notification type \"not_a_real_code\"" in errors_on(changeset).metadata
  end

  test "a notification without a type is still allowed" do
    {sender, recipient} = pair()

    assert {:ok, _} =
             Notifications.admin_create_notification(sender.id, recipient.id, %{
               "title" => "Plain message",
               "metadata" => %{"other" => "data"}
             })
  end

  test "known?/1 rejects non-strings" do
    refute Types.known?(nil)
    refute Types.known?(:friend_request)
    refute Types.known?(42)
  end
end
