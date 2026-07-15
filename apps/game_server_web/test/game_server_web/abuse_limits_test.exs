defmodule GameServerWeb.AbuseLimitsTest do
  @moduledoc """
  Tests for anti-abuse limits: per-user daily chat quota and the concurrent
  WebSocket cap per user.
  """
  use GameServerWeb.ConnCase, async: false

  import Phoenix.ChannelTest, only: [connect: 2]
  import Phoenix.ConnTest, except: [connect: 2, connect: 3]

  alias GameServer.AccountsFixtures
  alias GameServer.Groups
  alias GameServerWeb.Auth.Guardian
  alias GameServerWeb.UserSocket

  @endpoint GameServerWeb.Endpoint

  defp auth_conn(conn, user) do
    {:ok, token, _} = Guardian.encode_and_sign(user)
    put_req_header(conn, "authorization", "Bearer " <> token)
  end

  defp with_limits(overrides, fun) do
    previous = Application.get_env(:game_server_core, GameServer.Limits, [])
    Application.put_env(:game_server_core, GameServer.Limits, previous ++ overrides)
    on_exit(fn -> Application.put_env(:game_server_core, GameServer.Limits, previous) end)
    fun.()
  end

  describe "daily chat quota" do
    setup do
      previous = Application.get_env(:game_server_web, GameServerWeb.Plugs.RateLimiter, [])

      Application.put_env(
        :game_server_web,
        GameServerWeb.Plugs.RateLimiter,
        Keyword.put(previous, :enabled, true)
      )

      on_exit(fn ->
        Application.put_env(:game_server_web, GameServerWeb.Plugs.RateLimiter, previous)
      end)

      :ok
    end

    test "POST /chat/messages returns 429 once the daily quota is used up", %{conn: conn} do
      with_limits([max_chat_messages_per_day: 2], fn ->
        owner = AccountsFixtures.user_fixture()

        {:ok, group} =
          Groups.create_group(owner.id, %{"title" => "quota-group", "type" => "public"})

        send_message = fn ->
          conn
          |> auth_conn(owner)
          |> post("/api/v1/chat/messages", %{
            chat_type: "group",
            chat_ref_id: group.id,
            content: "hello"
          })
        end

        assert send_message.() |> json_response(201)
        assert send_message.() |> json_response(201)
        assert %{"error" => "chat_daily_limit"} = send_message.() |> json_response(429)
      end)
    end
  end

  describe "concurrent socket cap" do
    test "rejects new sockets once the per-user cap is reached" do
      with_limits([max_sockets_per_user: 2], fn ->
        user = AccountsFixtures.user_fixture()
        {:ok, token, _} = Guardian.encode_and_sign(user)

        assert {:ok, _s1} = connect(UserSocket, %{"token" => token})
        assert {:ok, _s2} = connect(UserSocket, %{"token" => token})
        assert :error = connect(UserSocket, %{"token" => token})

        # a different user is unaffected
        other = AccountsFixtures.user_fixture()
        {:ok, other_token, _} = Guardian.encode_and_sign(other)
        assert {:ok, _} = connect(UserSocket, %{"token" => other_token})
      end)
    end
  end
end
