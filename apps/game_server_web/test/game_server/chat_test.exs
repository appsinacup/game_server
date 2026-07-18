defmodule GameServer.ChatTest do
  use GameServer.DataCase

  alias GameServer.AccountsFixtures
  alias GameServer.Chat
  alias GameServer.Chat.Message
  alias GameServer.Friends
  alias GameServer.Groups
  alias GameServer.Repo

  defp create_user, do: AccountsFixtures.user_fixture()

  defp insert_message(sender, chat_type, chat_ref_id, content) do
    %Message{sender_id: sender.id}
    |> Message.changeset(%{chat_type: chat_type, chat_ref_id: chat_ref_id, content: content})
    |> Repo.insert!()
  end

  defp make_friends(user_a, user_b) do
    {:ok, req} = Friends.create_request(user_a, user_b.id)
    {:ok, _} = Friends.accept_friend_request(req.id, user_b)
  end

  describe "friend DM cleanup on user deletion" do
    test "removes friend messages referencing the deleted user (no orphans)" do
      alice = create_user()
      bob = create_user()
      make_friends(alice, bob)

      # chat_ref_id is the *recipient* of a friend DM.
      _to_bob = insert_message(alice, "friend", bob.id, "hi bob")
      from_bob = insert_message(bob, "friend", alice.id, "hi alice")

      {:ok, _} = GameServer.Accounts.delete_user(bob)

      # Messages addressed to bob are cleaned up explicitly (no FK cascade)...
      assert Repo.aggregate(
               from(m in Message, where: m.chat_type == "friend" and m.chat_ref_id == ^bob.id),
               :count
             ) == 0

      # ...and bob's own sent message is gone via the sender_id cascade.
      refute Repo.get(Message, from_bob.id)
    end
  end

  describe "mark_read/4" do
    test "rejects a message from another group conversation" do
      owner = create_user()
      member = create_user()
      {:ok, group_a} = Groups.create_group(owner.id, %{"title" => "read-a", "type" => "public"})
      {:ok, group_b} = Groups.create_group(owner.id, %{"title" => "read-b", "type" => "public"})
      {:ok, _} = Groups.join_group(member.id, group_a.id)

      message_b = insert_message(owner, "group", group_b.id, "wrong group")

      assert {:error, :message_not_in_chat} =
               Chat.mark_read(member.id, "group", group_a.id, message_b.id)
    end
  end

  describe "count_unread_friends_batch/2" do
    test "counts unread DMs per friend with read cursors" do
      user = create_user()
      friend_a = create_user()
      friend_b = create_user()
      make_friends(user, friend_a)
      make_friends(user, friend_b)

      first_a = insert_message(friend_a, "friend", user.id, "a1")
      _second_a = insert_message(friend_a, "friend", user.id, "a2")
      _first_b = insert_message(friend_b, "friend", user.id, "b1")

      assert {:ok, _cursor} = Chat.mark_read(user.id, "friend", friend_a.id, first_a.id)

      assert Chat.count_unread_friends_batch(user.id, [friend_a.id, friend_b.id]) == %{
               friend_a.id => 1,
               friend_b.id => 1
             }
    end
  end

  describe "count_unread_groups_batch/2" do
    test "counts unread group messages with read cursors" do
      owner = create_user()
      member = create_user()
      {:ok, group_a} = Groups.create_group(owner.id, %{"title" => "unread-a", "type" => "public"})
      {:ok, group_b} = Groups.create_group(owner.id, %{"title" => "unread-b", "type" => "public"})
      {:ok, _} = Groups.join_group(member.id, group_a.id)
      {:ok, _} = Groups.join_group(member.id, group_b.id)

      first_a = insert_message(owner, "group", group_a.id, "a1")
      _second_a = insert_message(owner, "group", group_a.id, "a2")
      _first_b = insert_message(owner, "group", group_b.id, "b1")

      assert {:ok, _cursor} = Chat.mark_read(member.id, "group", group_a.id, first_a.id)

      assert Chat.count_unread_groups_batch(member.id, [group_a.id, group_b.id]) == %{
               group_a.id => 1,
               group_b.id => 1
             }
    end
  end
end
