defmodule GameServer.HooksRegistrationTest do
  # Registering files at runtime changes application state and can race with
  # other tests that expect a particular hooks module. Run serially to avoid
  # flakiness in CI where tests may run in parallel or with Postgres workers.
  use ExUnit.Case, async: false

  # register/unregister helpers were intentionally removed from the public
  # API - use register_file/1 or the runtime watcher configured via
  # :game_server, :hooks_file_path to enable automatic registration.

  test "register_file/1 compiles and registers a module file at runtime" do
    orig = Application.get_env(:game_server, :hooks_module)
    on_exit(fn -> Application.put_env(:game_server, :hooks_module, orig) end)

    # compile & register from modules/example_hook.ex
    path = Path.join(File.cwd!(), "modules/example_hook.ex")
    assert File.exists?(path)

    assert {:ok, mod} = GameServer.Hooks.register_file(path)
    assert mod == GameServer.Modules.ExampleHook
    assert GameServer.Hooks.module() == mod

    # verify register_file recorded compile timestamp/status in app env
    assert is_binary(Application.get_env(:game_server, :hooks_last_compiled_at))
    assert Application.get_env(:game_server, :hooks_last_compile_status) == {:ok, mod}
  end
end
