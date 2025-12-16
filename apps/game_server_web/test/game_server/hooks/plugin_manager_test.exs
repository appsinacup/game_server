defmodule GameServer.Hooks.PluginManagerTest do
  use GameServer.DataCase, async: false

  alias GameServer.Hooks.PluginManager

  test "reload loads OTP plugin apps and call_rpc routes by plugin name" do
    tmp = Path.join(System.tmp_dir!(), "gs-plugin-mgr-#{System.unique_integer([:positive])}")
    plugin_root = Path.join(tmp, "modules/plugins")
    plugin_name = "test_plugin_mgr"
    plugin_dir = Path.join(plugin_root, plugin_name)
    ebin_dir = Path.join(plugin_dir, "ebin")

    File.mkdir_p!(ebin_dir)

    Application.put_env(:game_server, :plugin_mgr_test_pid, self())

    hook_mod = Module.concat([GameServer, TestPluginMgrHook])

    {:module, ^hook_mod, beam, _} =
      Module.create(
        hook_mod,
        quote do
          @behaviour GameServer.Hooks

          def after_startup, do: :ok

          def before_stop do
            if pid = Application.get_env(:game_server, :plugin_mgr_test_pid) do
              send(pid, {:before_stop, :test_plugin_mgr})
            end

            :ok
          end

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

          def echo(a), do: a
        end,
        __ENV__
      )

    File.write!(Path.join(ebin_dir, Atom.to_string(hook_mod) <> ".beam"), beam)

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
      Application.delete_env(:game_server, :plugin_mgr_test_pid)
      _ = PluginManager.reload()
    end)

    _ = PluginManager.reload()

    assert {:ok, plugin} = PluginManager.lookup(plugin_name)
    assert plugin.status == :ok
    assert plugin.hooks_module == hook_mod

    assert {:ok, [1, 2, 3]} = PluginManager.call_rpc(plugin_name, "echo", [[1, 2, 3]])

    _ = PluginManager.reload()
    assert_received {:before_stop, :test_plugin_mgr}
  end
end
