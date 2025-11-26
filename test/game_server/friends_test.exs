defmodule GameServer.FriendsTest do
  use GameServer.DataCase

  alias GameServer.AccountsFixtures
  alias GameServer.Friends

  describe "friendship flows" do
    setup do
      a = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      b = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

      %{a: a, b: b}
    end

    test "send request, accept, list friends", %{a: a, b: b} do
      assert {:ok, f} = Friends.create_request(a.id, b.id)
      assert f.status == "pending"

      # accept as b
      assert {:ok, accepted} = Friends.accept_friend_request(f.id, b)
      assert accepted.status == "accepted"

      friends_a = Friends.list_friends_for_user(a)
      friends_b = Friends.list_friends_for_user(b)

      assert Enum.any?(friends_a, &(&1.id == b.id))
      assert Enum.any?(friends_b, &(&1.id == a.id))
      # count helper should reflect 1 friend for each
      assert Friends.count_friends_for_user(a) == 1
      assert Friends.count_friends_for_user(b) == 1
    end

    test "cannot friend yourself", %{a: a} do
      assert {:error, :cannot_friend_self} = Friends.create_request(a.id, a.id)
    end

    test "duplicate request is prevented", %{a: a, b: b} do
      assert {:ok, _} = Friends.create_request(a.id, b.id)
      assert {:error, :already_requested} = Friends.create_request(a.id, b.id)
    end

    test "reverse request auto-accepts if reverse pending", %{a: a, b: b} do
      # a -> b pending
      {:ok, _f} = Friends.create_request(a.id, b.id)

      # b -> a should accept the existing pending request
      {:ok, accepted} = Friends.create_request(b.id, a.id)
      assert accepted.status == "accepted"
      assert Enum.any?(Friends.list_friends_for_user(a), &(&1.id == b.id))
    end

    test "reject and cancel flows", %{a: a, b: b} do
      {:ok, f} = Friends.create_request(a.id, b.id)

      # reject by target
      {:ok, _} = Friends.reject_friend_request(f.id, b)

      # now no friends
      refute Enum.any?(Friends.list_friends_for_user(a), &(&1.id == b.id))

      # new request then canceled
      {:ok, f2} = Friends.create_request(a.id, b.id)
      assert {:ok, :cancelled} = Friends.cancel_request(f2.id, a)
    end

    test "remove accepted friendship", %{a: a, b: b} do
      {:ok, f} = Friends.create_request(a.id, b.id)
      {:ok, _} = Friends.accept_friend_request(f.id, b)

      # remove friend by user a
      assert {:ok, _} = Friends.remove_friend(a.id, b.id)
      refute Enum.any?(Friends.list_friends_for_user(a), &(&1.id == b.id))
    end
  end

  describe "blocking flows and pubsub" do
    setup do
      a = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      b = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

      %{a: a, b: b}
    end

    test "target can block incoming request, it's listed and broadcasts to topics", %{a: a, b: b} do
      {:ok, f} = Friends.create_request(a.id, b.id)

      # subscribe to per-user and global topics
      Phoenix.PubSub.subscribe(GameServer.PubSub, "friends:user:#{a.id}")
      Phoenix.PubSub.subscribe(GameServer.PubSub, "friends:user:#{b.id}")
      Phoenix.PubSub.subscribe(GameServer.PubSub, "friends")

      assert {:ok, blocked} = Friends.block_friend_request(f.id, b)
      assert blocked.status == "blocked"

      # list blocked for b should include the blocked friendship
      blocked_list = Friends.list_blocked_for_user(b)
      assert Enum.any?(blocked_list, &(&1.id == blocked.id))

      # should receive broadcasts on the subscribed topics
      blocked_id = blocked.id
      assert_receive {:friend_blocked, %Friends.Friendship{id: ^blocked_id}}
      assert_receive {:friend_blocked, %Friends.Friendship{id: ^blocked_id}}
      assert_receive {:friend_blocked, %Friends.Friendship{id: ^blocked_id}}
    end

    test "target can unblock and broadcasts friend_unblocked and removes row", %{a: a, b: b} do
      {:ok, f} = Friends.create_request(a.id, b.id)
      {:ok, blocked} = Friends.block_friend_request(f.id, b)

      # subscribe
      Phoenix.PubSub.subscribe(GameServer.PubSub, "friends:user:#{a.id}")
      Phoenix.PubSub.subscribe(GameServer.PubSub, "friends:user:#{b.id}")
      Phoenix.PubSub.subscribe(GameServer.PubSub, "friends")

      # only the block target (b) may unblock
      assert {:error, :not_authorized} = Friends.unblock_friendship(blocked.id, a)

      # unblock as b
      assert {:ok, :unblocked} = Friends.unblock_friendship(blocked.id, b)

      # friendship should be removed from DB
      assert Repo.get(Friends.Friendship, blocked.id) == nil

      # should receive friend_unblocked broadcasts
      bid = blocked.id
      assert_receive {:friend_unblocked, %Friends.Friendship{id: ^bid}}
      assert_receive {:friend_unblocked, %Friends.Friendship{id: ^bid}}
      assert_receive {:friend_unblocked, %Friends.Friendship{id: ^bid}}
    end
  end
end
