defmodule GameServer.AchievementsTest do
  use GameServer.DataCase

  alias GameServer.AccountsFixtures
  alias GameServer.Achievements
  alias GameServer.Achievements.Achievement
  alias GameServer.Achievements.UserAchievement

  defp create_achievement(attrs \\ %{}) do
    defaults = %{slug: "test_#{System.unique_integer([:positive])}", title: "Test Achievement"}
    {:ok, ach} = Achievements.create_achievement(Map.merge(defaults, attrs))
    ach
  end

  describe "achievement CRUD" do
    test "create_achievement/1 creates with valid attrs" do
      attrs = %{
        slug: "first_lobby",
        title: "Welcome!",
        description: "Join your first lobby",
        progress_target: 1,
        hidden: false,
        metadata: %{"category" => "social"}
      }

      assert {:ok, %Achievement{} = ach} = Achievements.create_achievement(attrs)
      assert ach.slug == "first_lobby"
      assert ach.title == "Welcome!"
      assert ach.description == "Join your first lobby"
      assert ach.progress_target == 1
      assert ach.hidden == false
      assert ach.metadata == %{"category" => "social"}
    end

    test "create_achievement/1 validates required fields" do
      assert {:error, changeset} = Achievements.create_achievement(%{})
      assert "can't be blank" in errors_on(changeset).slug
      assert "can't be blank" in errors_on(changeset).title
    end

    test "create_achievement/1 enforces unique slug" do
      create_achievement(%{slug: "unique_slug"})

      assert {:error, changeset} =
               Achievements.create_achievement(%{slug: "unique_slug", title: "Dupe"})

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "create_achievement/1 validates progress_target > 0" do
      assert {:error, changeset} =
               Achievements.create_achievement(%{
                 slug: "zero_target",
                 title: "Zero",
                 progress_target: 0
               })

      assert errors_on(changeset).progress_target != []
    end

    test "create_achievement/1 accepts string keys" do
      attrs = %{"slug" => "str_keys", "title" => "String Keys"}
      assert {:ok, %Achievement{} = ach} = Achievements.create_achievement(attrs)
      assert ach.slug == "str_keys"
    end

    test "get_achievement/1 returns achievement by id" do
      ach = create_achievement()
      assert Achievements.get_achievement(ach.id).id == ach.id
    end

    test "get_achievement/1 returns nil for non-existent id" do
      assert Achievements.get_achievement(999_999) == nil
    end

    test "get_achievement_by_slug/1 returns achievement by slug" do
      ach = create_achievement(%{slug: "by_slug"})
      assert Achievements.get_achievement_by_slug("by_slug").id == ach.id
    end

    test "update_achievement/2 updates fields" do
      ach = create_achievement(%{slug: "update_me", title: "Original"})

      assert {:ok, updated} = Achievements.update_achievement(ach, %{title: "Updated"})
      assert updated.title == "Updated"
    end

    test "delete_achievement/1 removes achievement" do
      ach = create_achievement(%{slug: "delete_me"})
      assert {:ok, _} = Achievements.delete_achievement(ach)
      assert Achievements.get_achievement(ach.id) == nil
    end

    test "change_achievement/2 returns a changeset" do
      changeset = Achievements.change_achievement(%Achievement{})
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "listing achievements" do
    test "list_achievements/1 returns paginated achievements" do
      for i <- 1..3 do
        create_achievement(%{slug: "list_#{i}", title: "Ach #{i}"})
      end

      results = Achievements.list_achievements(page: 1, page_size: 25)
      assert length(results) == 3
      assert Enum.all?(results, &match?(%{achievement: %Achievement{}, progress: 0}, &1))
    end

    test "list_achievements/1 excludes hidden by default" do
      create_achievement(%{slug: "visible", hidden: false})
      create_achievement(%{slug: "secret", hidden: true})

      results = Achievements.list_achievements()
      slugs = Enum.map(results, & &1.achievement.slug)
      assert "visible" in slugs
      refute "secret" in slugs
    end

    test "list_achievements/1 includes hidden when include_hidden: true" do
      create_achievement(%{slug: "hidden_inc", hidden: true})

      results = Achievements.list_achievements(include_hidden: true)
      slugs = Enum.map(results, & &1.achievement.slug)
      assert "hidden_inc" in slugs
    end

    test "list_achievements/1 shows unlocked hidden achievements for user" do
      user = AccountsFixtures.user_fixture()
      ach = create_achievement(%{slug: "hidden_unlocked", hidden: true})
      {:ok, _} = Achievements.unlock_achievement(user.id, "hidden_unlocked")

      results = Achievements.list_achievements(user_id: user.id)
      slugs = Enum.map(results, & &1.achievement.slug)
      assert "hidden_unlocked" in slugs
    end

    test "list_achievements/1 includes user progress when user_id provided" do
      user = AccountsFixtures.user_fixture()
      ach = create_achievement(%{slug: "with_progress", progress_target: 10})
      {:ok, _} = Achievements.increment_progress(user.id, "with_progress", 3)

      results = Achievements.list_achievements(user_id: user.id)
      result = Enum.find(results, &(&1.achievement.slug == "with_progress"))
      assert result.progress == 3
      assert result.unlocked_at == nil
    end

    test "count_achievements/1 counts non-hidden by default" do
      create_achievement(%{slug: "count_vis", hidden: false})
      create_achievement(%{slug: "count_hid", hidden: true})

      assert Achievements.count_achievements() == 1
      assert Achievements.count_achievements(include_hidden: true) == 2
    end

    test "count_all_achievements/0 counts everything" do
      create_achievement(%{slug: "count_all_1", hidden: false})
      create_achievement(%{slug: "count_all_2", hidden: true})

      assert Achievements.count_all_achievements() == 2
    end
  end

  describe "unlocking achievements" do
    test "unlock_achievement/2 by slug" do
      user = AccountsFixtures.user_fixture()
      ach = create_achievement(%{slug: "unlock_slug"})

      assert {:ok, %UserAchievement{} = ua} =
               Achievements.unlock_achievement(user.id, "unlock_slug")

      assert ua.user_id == user.id
      assert ua.achievement_id == ach.id
      assert ua.progress == ach.progress_target
      assert ua.unlocked_at != nil
    end

    test "unlock_achievement/2 by id" do
      user = AccountsFixtures.user_fixture()
      ach = create_achievement(%{slug: "unlock_id"})

      assert {:ok, %UserAchievement{}} = Achievements.unlock_achievement(user.id, ach.id)
    end

    test "unlock_achievement/2 returns error if already unlocked" do
      user = AccountsFixtures.user_fixture()
      create_achievement(%{slug: "already_done"})
      {:ok, _} = Achievements.unlock_achievement(user.id, "already_done")

      assert {:error, :already_unlocked} =
               Achievements.unlock_achievement(user.id, "already_done")
    end

    test "unlock_achievement/2 returns error for non-existent slug" do
      user = AccountsFixtures.user_fixture()
      assert {:error, :achievement_not_found} = Achievements.unlock_achievement(user.id, "nope")
    end

    test "unlock_achievement/2 returns error for non-existent id" do
      user = AccountsFixtures.user_fixture()
      assert {:error, :achievement_not_found} = Achievements.unlock_achievement(user.id, 999_999)
    end
  end

  describe "increment_progress/3" do
    test "increments progress and auto-unlocks at target" do
      user = AccountsFixtures.user_fixture()
      create_achievement(%{slug: "progress_ach", progress_target: 3})

      assert {:ok, ua} = Achievements.increment_progress(user.id, "progress_ach", 1)
      assert ua.progress == 1
      assert ua.unlocked_at == nil

      assert {:ok, ua} = Achievements.increment_progress(user.id, "progress_ach", 1)
      assert ua.progress == 2
      assert ua.unlocked_at == nil

      assert {:ok, ua} = Achievements.increment_progress(user.id, "progress_ach", 1)
      assert ua.progress == 3
      assert ua.unlocked_at != nil
    end

    test "does not exceed target" do
      user = AccountsFixtures.user_fixture()
      create_achievement(%{slug: "overflow_ach", progress_target: 2})

      {:ok, _} = Achievements.increment_progress(user.id, "overflow_ach", 5)

      ua =
        Achievements.get_user_achievement(
          user.id,
          Achievements.get_achievement_by_slug("overflow_ach").id
        )

      assert ua.progress == 2
    end

    test "no-op after already unlocked" do
      user = AccountsFixtures.user_fixture()
      create_achievement(%{slug: "noop_ach", progress_target: 1})
      {:ok, ua1} = Achievements.increment_progress(user.id, "noop_ach", 1)
      assert ua1.unlocked_at != nil

      {:ok, ua2} = Achievements.increment_progress(user.id, "noop_ach", 1)
      assert ua2.unlocked_at == ua1.unlocked_at
    end

    test "returns error for non-existent slug" do
      user = AccountsFixtures.user_fixture()

      assert {:error, :achievement_not_found} =
               Achievements.increment_progress(user.id, "ghost", 1)
    end
  end

  describe "user achievement queries" do
    test "list_user_achievements/2 returns unlocked achievements" do
      user = AccountsFixtures.user_fixture()
      ach = create_achievement(%{slug: "list_ua"})
      {:ok, _} = Achievements.unlock_achievement(user.id, "list_ua")

      results = Achievements.list_user_achievements(user.id)
      assert length(results) == 1
      assert hd(results).achievement.id == ach.id
    end

    test "count_user_achievements/1 counts only unlocked" do
      user = AccountsFixtures.user_fixture()
      create_achievement(%{slug: "count_ua_1"})
      create_achievement(%{slug: "count_ua_2", progress_target: 10})
      {:ok, _} = Achievements.unlock_achievement(user.id, "count_ua_1")
      {:ok, _} = Achievements.increment_progress(user.id, "count_ua_2", 1)

      assert Achievements.count_user_achievements(user.id) == 1
    end
  end

  describe "admin operations" do
    test "grant_achievement/2 unlocks achievement" do
      user = AccountsFixtures.user_fixture()
      create_achievement(%{slug: "grant_me"})

      assert {:ok, %UserAchievement{}} = Achievements.grant_achievement(user.id, "grant_me")
    end

    test "revoke_achievement/2 removes user achievement" do
      user = AccountsFixtures.user_fixture()
      ach = create_achievement(%{slug: "revoke_me"})
      {:ok, _} = Achievements.unlock_achievement(user.id, "revoke_me")

      assert {:ok, _} = Achievements.revoke_achievement(user.id, ach.id)
      assert Achievements.get_user_achievement(user.id, ach.id) == nil
    end

    test "revoke_achievement/2 returns error for non-existent" do
      user = AccountsFixtures.user_fixture()
      assert {:error, :not_found} = Achievements.revoke_achievement(user.id, 999_999)
    end

    test "reset_user_achievement/2 deletes progress" do
      user = AccountsFixtures.user_fixture()
      ach = create_achievement(%{slug: "reset_me", progress_target: 10})
      {:ok, _} = Achievements.increment_progress(user.id, "reset_me", 5)

      assert {:ok, _} = Achievements.reset_user_achievement(user.id, ach.id)
      assert Achievements.get_user_achievement(user.id, ach.id) == nil
    end
  end

  describe "unlock_percentage/1" do
    test "returns unlock percentage" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      ach = create_achievement(%{slug: "rarity_test"})

      {:ok, _} = Achievements.unlock_achievement(user1.id, "rarity_test")
      pct = Achievements.unlock_percentage(ach.id)

      # At least 1 user out of total, should be > 0
      assert pct > 0.0
      assert pct <= 100.0
    end
  end
end
