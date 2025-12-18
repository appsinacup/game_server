defmodule GameServerWeb.Api.V1.HookControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Hooks.PluginManager
  alias GameServerWeb.Auth.Guardian

  setup do
    user = GameServer.AccountsFixtures.user_fixture()
    {:ok, token, _} = Guardian.encode_and_sign(user)

    conn = build_conn() |> put_req_header("authorization", "Bearer " <> token)

    {:ok, conn: conn, user: user}
  end

  test "POST /api/v1/hooks/call invokes plugin function", %{conn: conn, user: user} do
    tmp = Path.join(System.tmp_dir!(), "gs-plugin-#{System.unique_integer([:positive])}")
    plugin_root = Path.join(tmp, "modules/plugins")
    plugin_name = "test_plugin"
    plugin_dir = Path.join(plugin_root, plugin_name)
    ebin_dir = Path.join(plugin_dir, "ebin")

    File.mkdir_p!(ebin_dir)

    hook_mod = Module.concat([GameServer, TestPluginHook])

    {:module, ^hook_mod, beam, _} =
      Module.create(
        hook_mod,
        quote do
          @behaviour GameServer.Hooks

          def after_startup, do: :ok
          def before_stop, do: :ok
          def after_user_register(_user), do: :ok
          def after_user_login(_user), do: :ok

          def before_lobby_create(attrs), do: {:ok, attrs}
          def after_lobby_create(_lobby), do: :ok
          def before_lobby_join(user, lobby, opts), do: {:ok, {user, lobby, opts}}
          def after_lobby_join(_user, _lobby), do: :ok
          def before_lobby_leave(user, lobby), do: {:ok, {user, lobby}}
          def after_lobby_leave(_user, _lobby), do: :ok
          def before_lobby_update(_lobby, attrs), do: {:ok, attrs}
          def after_lobby_update(_lobby), do: :ok
          def before_lobby_delete(lobby), do: {:ok, lobby}
          def after_lobby_delete(_lobby), do: :ok
          def before_user_kicked(host, target, lobby), do: {:ok, {host, target, lobby}}
          def after_user_kicked(_host, _target, _lobby), do: :ok
          def after_lobby_host_change(_lobby, _new_host_id), do: :ok

          def greet do
            user = GameServer.Hooks.caller_user()
            %{greeted: user.id}
          end

          def echo(a), do: a
        end,
        __ENV__
      )

    beam_path = Path.join(ebin_dir, Atom.to_string(hook_mod) <> ".beam")
    File.write!(beam_path, beam)

    app_term =
      {:application, String.to_atom(plugin_name),
       [
         {:description, ~c"test plugin"},
         {:vsn, ~c"0.1.0"},
         {:modules, [hook_mod]},
         {:registered, []},
         {:applications, [:kernel, :stdlib]},
         {:env, [hooks_module: to_charlist(Atom.to_string(hook_mod))]}
       ]}

    app_text = :io_lib.format(~c"~p.~n", [app_term]) |> IO.iodata_to_binary()
    File.write!(Path.join(ebin_dir, "#{plugin_name}.app"), app_text)

    System.put_env("GAME_SERVER_PLUGINS_DIR", plugin_root)

    on_exit(fn ->
      System.delete_env("GAME_SERVER_PLUGINS_DIR")
      _ = PluginManager.reload()
    end)

    _ = PluginManager.reload()

    body = %{"plugin" => plugin_name, "fn" => "echo", "args" => [[1, 2, 3]]}
    conn = post(conn, "/api/v1/hooks/call", body)
    assert %{"data" => [1, 2, 3]} = json_response(conn, 200)

    body2 = %{"plugin" => plugin_name, "fn" => "greet", "args" => []}
    conn2 = post(conn, "/api/v1/hooks/call", body2)
    id = user.id
    assert %{"data" => %{"greeted" => ^id}} = json_response(conn2, 200)
  end
end
