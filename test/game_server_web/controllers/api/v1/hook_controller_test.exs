defmodule GameServerWeb.Api.V1.HookControllerTest do
  use GameServerWeb.ConnCase

  alias GameServerWeb.Auth.Guardian

  setup do
    user = GameServer.AccountsFixtures.user_fixture()
    {:ok, token, _} = Guardian.encode_and_sign(user)

    conn = build_conn() |> put_req_header("authorization", "Bearer " <> token)

    orig = Application.get_env(:game_server, :hooks_module)
    on_exit(fn -> Application.put_env(:game_server, :hooks_module, orig) end)

    {:ok, conn: conn, user: user}
  end

  test "GET /api/v1/hooks returns exported functions", %{conn: conn} do
    mod = Module.concat([GameServer, TestHooks, :ApiList])

    Module.create(
      mod,
      quote do
        def example, do: :ok
        def foo(a), do: a
      end,
      __ENV__
    )

    Application.put_env(:game_server, :hooks_module, mod)

    conn = get(conn, "/api/v1/hooks")
    assert %{"data" => data} = json_response(conn, 200)
    assert is_list(data)
  end

  test "POST /api/v1/hooks/call invokes function", %{conn: conn, user: user} do
    mod = Module.concat([GameServer, TestHooks, :ApiCall])

    Module.create(
      mod,
      quote do
        def greet(user), do: %{greeted: user.id}
        def echo(a), do: a
      end,
      __ENV__
    )

    Application.put_env(:game_server, :hooks_module, mod)

    # echo expects a single argument; send the array as the single arg
    body = %{"fn" => "echo", "args" => [[1, 2, 3]]}
    conn = post(conn, "/api/v1/hooks/call", body)
    assert %{"ok" => true, "result" => [1, 2, 3]} = json_response(conn, 200)

    # call with user as first arg by default if args omitted
    body2 = %{"fn" => "greet"}
    conn2 = post(conn, "/api/v1/hooks/call", body2)
    id = user.id
    assert %{"ok" => true, "result" => %{"greeted" => ^id}} = json_response(conn2, 200)
  end
end
