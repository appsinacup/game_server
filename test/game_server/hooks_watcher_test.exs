defmodule GameServer.HooksWatcherTest do
  use ExUnit.Case, async: false
  @moduletag :skip

  test "watcher loads hooks file at startup when configured" do
    orig_mod = Application.get_env(:game_server, :hooks_module)
    orig_path = Application.get_env(:game_server, :hooks_file_path)

    on_exit(fn ->
      # restore original config
      Application.put_env(:game_server, :hooks_module, orig_mod)
      Application.put_env(:game_server, :hooks_file_path, orig_path)
    end)

    path = Path.join(File.cwd!(), "modules/example_hook.ex")
    assert File.exists?(path)

    Application.put_env(:game_server, :hooks_file_path, path)

    # Ensure the watcher process sees the updated app env and attempts
    # to start watching & compile the file. The application supervision tree
    # already runs the watcher in test env, so signal it to re-check.
    if pid = Process.whereis(GameServer.Hooks.Watcher) do
      Application.put_env(:game_server, :hooks_file_path, path)
      send(pid, :env_check)
    end

    # wait a short amount for the watcher to trigger compile
    mod = Enum.reduce_while(1..20, false, fn _, _ ->
      case Application.get_env(:game_server, :hooks_module) do
        mod when is_atom(mod) and mod != GameServer.Hooks.Default -> {:halt, mod}
        _ ->
          Process.sleep(50)
          {:cont, false}
      end
    end)
    assert mod == GameServer.Modules.ExampleHook

    # cleanup watcher
    Process.exit(pid, :normal)
  end
end
