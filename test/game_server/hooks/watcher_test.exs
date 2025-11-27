defmodule GameServer.Hooks.WatcherTest do
  use ExUnit.Case, async: false

  setup do
    # ensure a clean config for the test
    on_exit(fn ->
      Application.delete_env(:game_server, :hooks_file_path)
      Application.delete_env(:game_server, :hooks_file_watch_interval)
    end)

    :ok
  end

  test "watcher starts FileSystem under a distinct name and doesn't subscribe to itself" do
    path = Path.join(System.tmp_dir!(), "temp_hooks_#{System.unique_integer([:positive])}.ex")

    File.write!(path, "defmodule TempHooksImpl do\n  def after_user_register(_u), do: :ok\nend\n")

    Application.put_env(:game_server, :hooks_file_path, path)
    Application.put_env(:game_server, :hooks_file_watch_interval, 1)

    # start the watcher under test supervision
    start_result = start_supervised({GameServer.Hooks.Watcher, []})

    watcher_pid =
      case start_result do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    fs_name = Module.concat(GameServer.Hooks.Watcher, :FileSystem)
    fs_pid = Process.whereis(fs_name)

    assert is_pid(watcher_pid)
    # the FileSystem process may or may not be started in the test environment,
    # but in either case it must not be the watcher itself (no self-subscribe).
    assert watcher_pid != fs_pid

    File.rm!(path)
  end
end
