defmodule GameServerWeb.Api.V1.PublicListingGatesTest do
  @moduledoc """
  Tests for the LIST_*_ENABLED env flags that gate public listing endpoints
  and their matching realtime list channels.
  """
  use GameServerWeb.ChannelCase, async: false

  import Phoenix.ConnTest, except: [connect: 2, connect: 3]

  alias GameServer.AccountsFixtures
  alias GameServerWeb.Auth.Guardian
  alias GameServerWeb.UserSocket

  @endpoint GameServerWeb.Endpoint

  @flags [
    "LIST_USERS_ENABLED",
    "LIST_LOBBIES_ENABLED",
    "LIST_GROUPS_ENABLED",
    "LIST_LEADERBOARDS_ENABLED",
    "LIST_ACHIEVEMENTS_ENABLED"
  ]

  setup do
    on_exit(fn -> Enum.each(@flags, &System.delete_env/1) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  defp disable(flag), do: System.put_env(flag, "false")

  describe "defaults (flags unset)" do
    test "public listing endpoints are reachable", %{conn: conn} do
      assert conn |> get("/api/v1/users") |> json_response(200)
      assert conn |> get("/api/v1/lobbies") |> json_response(200)
      assert conn |> get("/api/v1/groups") |> json_response(200)
    end
  end

  describe "LIST_USERS_ENABLED=false" do
    test "GET /users and /users/:id return 404", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      disable("LIST_USERS_ENABLED")

      assert conn |> get("/api/v1/users") |> response(404)
      assert conn |> get("/api/v1/users/#{user.id}") |> response(404)
    end
  end

  describe "LIST_LOBBIES_ENABLED=false" do
    test "GET /lobbies returns 404", %{conn: conn} do
      disable("LIST_LOBBIES_ENABLED")

      assert conn |> get("/api/v1/lobbies") |> response(404)
    end

    test "joining the lobbies channel is rejected" do
      disable("LIST_LOBBIES_ENABLED")

      assert {:error, %{reason: "listing_disabled"}} =
               connect_user_socket()
               |> subscribe_and_join(GameServerWeb.LobbiesChannel, "lobbies")
    end
  end

  describe "LIST_GROUPS_ENABLED=false" do
    test "GET /groups, /groups/:id and /groups/:id/members return 404", %{conn: conn} do
      disable("LIST_GROUPS_ENABLED")

      assert conn |> get("/api/v1/groups") |> response(404)
      assert conn |> get("/api/v1/groups/1") |> response(404)
      assert conn |> get("/api/v1/groups/1/members") |> response(404)
    end

    test "joining the groups channel is rejected" do
      disable("LIST_GROUPS_ENABLED")

      assert {:error, %{reason: "listing_disabled"}} =
               connect_user_socket() |> subscribe_and_join(GameServerWeb.GroupsChannel, "groups")
    end
  end

  describe "LIST_LEADERBOARDS_ENABLED=false" do
    test "public leaderboard endpoints return 404", %{conn: conn} do
      disable("LIST_LEADERBOARDS_ENABLED")

      assert conn |> get("/api/v1/leaderboards") |> response(404)
      assert conn |> get("/api/v1/leaderboards/some-slug") |> response(404)
      assert conn |> post("/api/v1/leaderboards/resolve", %{slugs: []}) |> response(404)
    end
  end

  describe "LIST_ACHIEVEMENTS_ENABLED=false" do
    test "public achievement endpoints return 404", %{conn: conn} do
      disable("LIST_ACHIEVEMENTS_ENABLED")

      assert conn |> get("/api/v1/achievements") |> response(404)
      assert conn |> get("/api/v1/achievements/some-slug") |> response(404)
    end
  end

  describe "browser list pages honor the same flags" do
    test "/groups, /leaderboards, /achievements 404 when disabled", %{conn: conn} do
      disable("LIST_GROUPS_ENABLED")
      disable("LIST_LEADERBOARDS_ENABLED")
      disable("LIST_ACHIEVEMENTS_ENABLED")

      assert_error_sent 404, fn -> get(conn, "/groups") end
      assert_error_sent 404, fn -> get(conn, "/leaderboards") end
      assert_error_sent 404, fn -> get(conn, "/achievements") end
    end

    test "pages render when flags are unset", %{conn: conn} do
      assert conn |> get("/groups") |> html_response(200)
      assert conn |> get("/leaderboards") |> html_response(200)
      assert conn |> get("/achievements") |> html_response(200)
    end
  end

  describe "channels with flags enabled" do
    test "lobbies and groups channels join normally" do
      assert {:ok, _, _socket} =
               connect_user_socket()
               |> subscribe_and_join(GameServerWeb.LobbiesChannel, "lobbies")

      assert {:ok, _, _socket} =
               connect_user_socket() |> subscribe_and_join(GameServerWeb.GroupsChannel, "groups")
    end
  end

  defp connect_user_socket do
    user = AccountsFixtures.user_fixture()
    {:ok, token, _} = Guardian.encode_and_sign(user)
    {:ok, socket} = connect(UserSocket, %{"token" => token})
    socket
  end
end
