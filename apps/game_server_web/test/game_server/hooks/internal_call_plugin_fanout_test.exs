defmodule GameServer.Hooks.InternalCallPluginFanoutTest do
  use GameServer.DataCase, async: false

  alias GameServer.Accounts.User
  alias GameServer.Hooks
  alias GameServer.Hooks.PluginManager

  test "internal_call runs plugin after_user_register even when base is Default" do
    tmp = Path.join(System.tmp_dir!(), "gs-hooks-fanout-#{System.unique_integer([:positive])}")
    plugin_root = Path.join(tmp, "modules/plugins")
    plugin_name = "test_plugin_fanout_#{System.unique_integer([:positive])}"
    plugin_dir = Path.join(plugin_root, plugin_name)
    ebin_dir = Path.join(plugin_dir, "ebin")

    File.mkdir_p!(ebin_dir)

    test_pid = self()

    hook_mod =
      Module.concat([
        GameServer,
        String.to_atom("TestPluginFanoutHook_#{System.unique_integer([:positive])}")
      ])

    {:module, ^hook_mod, beam, _} =
      Module.create(
        hook_mod,
        quote do
          @behaviour GameServer.Hooks

          def after_user_register(_user) do
            if pid = Application.get_env(:game_server, :plugin_fanout_test_pid) do
              send(pid, :after_user_register_called)
            end

            :ok
          end

          # satisfy behaviour with default no-ops where required
          def after_startup, do: :ok
          def before_stop, do: :ok
          def after_user_login(_user), do: :ok
          def after_user_updated(_user), do: :ok
          def on_custom_hook(_hook, _args), do: {:error, :not_implemented}

          def before_lobby_create(attrs), do: {:ok, attrs}
          def after_lobby_create(_lobby), do: :ok
          def before_group_create(_user, attrs), do: {:ok, attrs}
          def after_group_create(_group), do: :ok
          def before_group_join(user, group, opts), do: {:ok, {user, group, opts}}
          def before_lobby_join(user, lobby, opts), do: {:ok, {user, lobby, opts}}
          def before_chat_message(_user, attrs), do: {:ok, attrs}
          def after_chat_message(_message), do: :ok
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

          def before_kv_get(_key, _opts), do: :public
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
    Application.put_env(:game_server, :plugin_fanout_test_pid, test_pid)

    original_hooks_mod = Application.get_env(:game_server_core, :hooks_module)

    on_exit(fn ->
      System.delete_env("GAME_SERVER_PLUGINS_DIR")
      Application.delete_env(:game_server, :plugin_fanout_test_pid)

      if is_nil(original_hooks_mod) do
        Application.delete_env(:game_server_core, :hooks_module)
      else
        Application.put_env(:game_server_core, :hooks_module, original_hooks_mod)
      end

      _ = PluginManager.reload()
    end)

    _ = PluginManager.reload()

    assert {:ok, plugin} = PluginManager.lookup(plugin_name)
    assert plugin.status == :ok
    assert plugin.hooks_module == hook_mod

    Application.put_env(:game_server_core, :hooks_module, GameServer.Hooks.Default)

    assert {:ok, :ok} = Hooks.internal_call(:after_user_register, [%User{id: 123}])
    assert_received :after_user_register_called
  end
end
