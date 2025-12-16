defmodule GameServer.LeaderboardsTest do
  use GameServer.DataCase

  alias GameServer.AccountsFixtures
  alias GameServer.Leaderboards
  alias GameServer.Leaderboards.{Leaderboard, Record}

  describe "leaderboard CRUD" do
    test "create_leaderboard/1 creates a leaderboard with valid attrs" do
      attrs = %{
        slug: "weekly_score",
        title: "Weekly High Scores",
        description: "Top scores this week",
        sort_order: :desc,
        operator: :best,
        starts_at: ~U[2024-11-25 00:00:00Z],
        metadata: %{"prize" => "Gold Badge"}
      }

      assert {:ok, %Leaderboard{} = lb} = Leaderboards.create_leaderboard(attrs)
      assert is_integer(lb.id)
      assert lb.slug == "weekly_score"
      assert lb.title == "Weekly High Scores"
      assert lb.sort_order == :desc
      assert lb.operator == :best
      assert lb.metadata == %{"prize" => "Gold Badge"}
    end

    test "create_leaderboard/1 uses defaults for sort_order and operator" do
      attrs = %{slug: "test_lb", title: "Test"}

      assert {:ok, %Leaderboard{} = lb} = Leaderboards.create_leaderboard(attrs)
      assert lb.sort_order == :desc
      assert lb.operator == :best
    end

    test "create_leaderboard/1 validates required fields" do
      assert {:error, changeset} = Leaderboards.create_leaderboard(%{})
      assert "can't be blank" in errors_on(changeset).slug
      assert "can't be blank" in errors_on(changeset).title
    end

    test "create_leaderboard/1 validates slug format" do
      attrs = %{slug: "Invalid-Slug!", title: "Test"}
      assert {:error, changeset} = Leaderboards.create_leaderboard(attrs)
      assert "must be lowercase alphanumeric with underscores" in errors_on(changeset).slug
    end

    test "get_leaderboard/1 with integer id returns the leaderboard" do
      attrs = %{slug: "get_test", title: "Test"}
      {:ok, lb} = Leaderboards.create_leaderboard(attrs)

      assert Leaderboards.get_leaderboard(lb.id).id == lb.id
    end

    test "get_leaderboard/1 returns nil for non-existent id" do
      assert Leaderboards.get_leaderboard(999_999) == nil
    end

    test "update_leaderboard/2 updates the leaderboard" do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "update_test", title: "Original"})

      assert {:ok, updated} = Leaderboards.update_leaderboard(lb, %{title: "Updated"})
      assert updated.title == "Updated"
    end

    test "delete_leaderboard/1 deletes the leaderboard" do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "delete_test", title: "Test"})

      assert {:ok, %Leaderboard{}} = Leaderboards.delete_leaderboard(lb)
      assert Leaderboards.get_leaderboard(lb.id) == nil
    end

    test "end_leaderboard/1 sets ends_at" do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "end_test", title: "Test"})
      assert lb.ends_at == nil

      assert {:ok, ended} = Leaderboards.end_leaderboard(lb)
      assert ended.ends_at != nil
    end
  end

  describe "list_leaderboards/1" do
    test "returns all leaderboards with pagination" do
      for i <- 1..5 do
        Leaderboards.create_leaderboard(%{slug: "lb_#{i}", title: "Leaderboard #{i}"})
      end

      result = Leaderboards.list_leaderboards(page: 1, page_size: 3)
      assert length(result) == 3

      total = Leaderboards.count_leaderboards()
      assert total == 5
    end

    test "returns only active leaderboards when active: true" do
      {:ok, active} = Leaderboards.create_leaderboard(%{slug: "active_lb", title: "Active"})
      {:ok, ended} = Leaderboards.create_leaderboard(%{slug: "ended_lb", title: "Ended"})
      Leaderboards.end_leaderboard(ended)

      result = Leaderboards.list_leaderboards(active: true)
      ids = Enum.map(result, & &1.id)
      assert active.id in ids
      refute ended.id in ids
    end
  end

  describe "get_active_leaderboard_by_slug/1" do
    test "returns active leaderboard with matching slug" do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "active_slug_test", title: "Active"})

      result = Leaderboards.get_active_leaderboard_by_slug("active_slug_test")
      assert result.id == lb.id
    end

    test "returns nil for ended leaderboard" do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "ended_slug_test", title: "Ended"})
      Leaderboards.end_leaderboard(lb)

      assert Leaderboards.get_active_leaderboard_by_slug("ended_slug_test") == nil
    end

    test "returns most recent active when multiple exist" do
      {:ok, _old} = Leaderboards.create_leaderboard(%{slug: "multi_slug", title: "Old"})
      # Small delay to ensure different inserted_at
      Process.sleep(10)
      {:ok, new} = Leaderboards.create_leaderboard(%{slug: "multi_slug", title: "New"})

      result = Leaderboards.get_active_leaderboard_by_slug("multi_slug")
      assert result.id == new.id
    end
  end

  describe "submit_score/4" do
    setup do
      user = AccountsFixtures.user_fixture()

      {:ok, lb} =
        Leaderboards.create_leaderboard(%{slug: "score_test", title: "Test", operator: :best})

      %{user: user, leaderboard: lb}
    end

    test "creates a new record for first submission", %{user: user, leaderboard: lb} do
      assert {:ok, %Record{} = record} = Leaderboards.submit_score(lb.id, user.id, 1000)
      assert record.score == 1000
      assert record.user_id == user.id
    end

    test "accepts integer id", %{user: user, leaderboard: lb} do
      assert {:ok, %Record{} = record} = Leaderboards.submit_score(lb.id, user.id, 1000)
      assert record.score == 1000
    end

    test "operator :set always replaces the score", %{user: user} do
      {:ok, lb} =
        Leaderboards.create_leaderboard(%{slug: "set_test", title: "Set", operator: :set})

      {:ok, _} = Leaderboards.submit_score(lb.id, user.id, 1000)
      {:ok, record} = Leaderboards.submit_score(lb.id, user.id, 500)
      assert record.score == 500
    end

    test "operator :best only updates if better (desc)", %{user: user, leaderboard: lb} do
      {:ok, _} = Leaderboards.submit_score(lb.id, user.id, 1000)
      {:ok, record} = Leaderboards.submit_score(lb.id, user.id, 500)
      # Should not update because 500 < 1000 and sort_order is desc
      assert record.score == 1000
    end

    test "operator :best updates when better (desc)", %{user: user, leaderboard: lb} do
      {:ok, _} = Leaderboards.submit_score(lb.id, user.id, 1000)
      {:ok, record} = Leaderboards.submit_score(lb.id, user.id, 1500)
      assert record.score == 1500
    end

    test "operator :best respects asc sort_order", %{user: user} do
      {:ok, lb} =
        Leaderboards.create_leaderboard(%{
          slug: "asc_test",
          title: "Asc",
          operator: :best,
          sort_order: :asc
        })

      {:ok, _} = Leaderboards.submit_score(lb.id, user.id, 1000)
      {:ok, record1} = Leaderboards.submit_score(lb.id, user.id, 1500)
      # Should not update because 1500 > 1000 and sort_order is asc (lower is better)
      assert record1.score == 1000

      {:ok, record2} = Leaderboards.submit_score(lb.id, user.id, 800)
      assert record2.score == 800
    end

    test "operator :incr adds to existing score", %{user: user} do
      {:ok, lb} =
        Leaderboards.create_leaderboard(%{slug: "incr_test", title: "Incr", operator: :incr})

      {:ok, _} = Leaderboards.submit_score(lb.id, user.id, 100)
      {:ok, record} = Leaderboards.submit_score(lb.id, user.id, 50)
      assert record.score == 150
    end

    test "operator :decr subtracts from existing score", %{user: user} do
      {:ok, lb} =
        Leaderboards.create_leaderboard(%{slug: "decr_test", title: "Decr", operator: :decr})

      {:ok, _} = Leaderboards.submit_score(lb.id, user.id, 100)
      {:ok, record} = Leaderboards.submit_score(lb.id, user.id, 30)
      assert record.score == 70
    end

    test "stores metadata on record", %{user: user, leaderboard: lb} do
      metadata = %{"level" => 15, "combo" => 5}
      {:ok, record} = Leaderboards.submit_score(lb.id, user.id, 1000, metadata)
      assert record.metadata == metadata
    end

    test "fails for non-existent leaderboard", %{user: user} do
      assert {:error, :leaderboard_not_found} =
               Leaderboards.submit_score(999_999, user.id, 100)
    end

    test "fails for ended leaderboard", %{user: user} do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "ended_test", title: "Ended"})
      {:ok, ended} = Leaderboards.end_leaderboard(lb)

      assert {:error, :leaderboard_ended} = Leaderboards.submit_score(ended.id, user.id, 100)
    end
  end

  describe "list_records/2" do
    setup do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "records_test", title: "Test"})

      users =
        for i <- 1..10 do
          user = AccountsFixtures.user_fixture()
          Leaderboards.submit_score(lb.id, user.id, i * 100)
          user
        end

      %{leaderboard: lb, users: users}
    end

    test "returns records with pagination and rank", %{leaderboard: lb} do
      result = Leaderboards.list_records(lb.id, page: 1, page_size: 5)

      assert length(result) == 5
      total = Leaderboards.count_records(lb.id)
      assert total == 10
      # Records are ordered by score desc, so first should have rank 1
      first = hd(result)
      assert first.rank == 1
      assert first.score == 1000
    end

    test "ranks are continuous across pages", %{leaderboard: lb} do
      page1 = Leaderboards.list_records(lb.id, page: 1, page_size: 5)
      page2 = Leaderboards.list_records(lb.id, page: 2, page_size: 5)

      last_rank_page1 = List.last(page1).rank
      first_rank_page2 = hd(page2).rank

      assert first_rank_page2 == last_rank_page1 + 1
    end
  end

  describe "get_user_record/2" do
    test "returns user's record with rank" do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "user_record_test", title: "Test"})

      users =
        for i <- 1..5 do
          user = AccountsFixtures.user_fixture()
          Leaderboards.submit_score(lb.id, user.id, i * 100)
          user
        end

      # User with score 300 should be rank 3 (since higher is better)
      target_user = Enum.at(users, 2)

      {:ok, result} = Leaderboards.get_user_record(lb.id, target_user.id)
      assert result.score == 300
      assert result.rank == 3
    end

    test "returns error for user without record" do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "no_record_test", title: "Test"})
      user = AccountsFixtures.user_fixture()

      assert {:error, :not_found} = Leaderboards.get_user_record(lb.id, user.id)
    end
  end

  describe "list_records_around_user/3" do
    test "returns records around the user's position" do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "around_test", title: "Test"})

      users =
        for i <- 1..10 do
          user = AccountsFixtures.user_fixture()
          Leaderboards.submit_score(lb.id, user.id, i * 100)
          user
        end

      # User with score 500 should be rank 6 (10 - 5 + 1 = 6 in desc order)
      target_user = Enum.at(users, 4)

      result = Leaderboards.list_records_around_user(lb.id, target_user.id, limit: 5)

      # Should get up to 5 records centered around the user
      refute Enum.empty?(result)
      # The user should be in the result
      assert Enum.any?(result, fn r -> r.user_id == target_user.id end)
    end

    test "returns empty list for user without record" do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "around_empty_test", title: "Test"})
      user = AccountsFixtures.user_fixture()

      assert Leaderboards.list_records_around_user(lb.id, user.id, limit: 2) == []
    end
  end

  describe "delete_record/1" do
    test "deletes a record" do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "delete_record_test", title: "Test"})
      user = AccountsFixtures.user_fixture()
      {:ok, record} = Leaderboards.submit_score(lb.id, user.id, 1000)

      assert {:ok, %Record{}} = Leaderboards.delete_record(record)
      assert {:error, :not_found} = Leaderboards.get_user_record(lb.id, user.id)
    end
  end
end
