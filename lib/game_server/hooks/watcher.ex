defmodule GameServer.Hooks.Watcher do
  @moduledoc """
  Small file-watcher that will automatically register a hooks implementation
  from a source file specified in config: :game_server, :hooks_file_path

  It polls the file's mtime every few seconds and will recompile & register
  the module when the file changes. This provides a simple and robust way
  for developers to point the app at a local hook implementation and have
  it hot-reload when edited.
  """

  use GenServer
  require Logger

  # Use seconds for configuration values (makes runtime config more readable).
  # Default to 2 seconds between checks for env/config availability and for
  # debounce behaviour when falling back to env polling.
  @default_interval_sec 2

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    app_path = Application.get_env(:game_server, :hooks_file_path)
    env_path = System.get_env("HOOKS_FILE_PATH")
    path = app_path || env_path

    interval_sec =
      Application.get_env(:game_server, :hooks_file_watch_interval, @default_interval_sec)

    # Normalize to milliseconds for Process.send_after
    interval_ms =
      cond do
        is_integer(interval_sec) and interval_sec > 0 -> interval_sec * 1_000
        is_float(interval_sec) and interval_sec > 0.0 -> trunc(interval_sec * 1_000)
        true -> @default_interval_sec * 1_000
      end

    Logger.info("Hooks watcher starting with path=#{inspect(path)} interval_ms=#{interval_ms}")

    state = %{path: path, interval_ms: interval_ms, fs_pid: nil, mtime: nil, polling?: false}

    state =
      case path do
        p when is_binary(p) ->
          if File.exists?(p) do
            # try to start the filesystem watcher (best-effort); regardless
            # of success we want to trigger an initial compile so the file
            # gets registered even if FileSystem failed to start.
            case start_fs(p) do
              {:ok, pid} ->
                Process.send_after(self(), :trigger_compile, 0)
                %{state | fs_pid: pid}

              {:error, reason} ->
                Logger.warning(
                  "Hooks watcher: failed to start file watcher #{inspect(reason)} - will still attempt initial compile"
                )

                # Still attempt initial compile now that file exists
                # attempt initial immediate compile
                Process.send_after(self(), :trigger_compile, 0)

                # start a simple polling fallback so we keep detecting changes
                # even when FileSystem (inotify) isn't available in the environment
                Process.send_after(self(), :poll_check, interval_ms)

                %{state | polling?: true}
            end
          else
            Process.send_after(self(), :env_check, 0)
            state
          end

        _ ->
          # No file yet - schedule an env/config check loop to pick it up
          Process.send_after(self(), :env_check, 0)
          state
      end

    {:ok, state}
  end

  @impl true
  def handle_info(:env_check, state) do
    # No path configured - check app config and environment again so this
    # process can pick up a path that was exported after startup (convenient
    # for quick dev workflows).
    app_path = Application.get_env(:game_server, :hooks_file_path)
    env_path = System.get_env("HOOKS_FILE_PATH")

    new_path = app_path || env_path

    if is_binary(new_path) and File.exists?(new_path) do
      Logger.info("Hooks watcher discovered hooks file path: #{inspect(new_path)}")

      case start_fs(new_path) do
        {:ok, pid} ->
          # ensure we also compile the file after discovery
          Process.send_after(self(), :trigger_compile, 0)
          {:noreply, %{state | path: new_path, fs_pid: pid}}

        {:error, reason} ->
          Logger.warning(
            "Hooks watcher: failed to start file watcher for #{inspect(new_path)}: #{inspect(reason)} - attempting compile anyway"
          )

          # attempt an immediate compile even if we couldn't start fs watcher
          Process.send_after(self(), :trigger_compile, 0)

          # start polling fallback to keep detecting file changes
          Process.send_after(self(), :poll_check, state.interval_ms)
          {:noreply, %{state | path: new_path, polling?: true}}
      end
    else
      # Still missing - reschedule and continue waiting
      Process.send_after(self(), :env_check, state.interval_ms)
      {:noreply, state}
    end
  end

  @impl true
  @doc false
  # file_system sends {:file_event, pid, {path, events}} messages. We simply
  # trigger a compile when the file changes. Editors can emit multiple events
  # for a single save, so we debounce using a small scheduled message.
  def handle_info({:file_event, _watcher_pid, {file_path, events}}, %{path: path} = state) do
    file_path = to_string(file_path)
    events = List.wrap(events)

    # If the event refers to the exact file (or to the watched directory),
    # and includes modification-like events, schedule a compile.
    interested = String.ends_with?(file_path, Path.basename(path)) or file_path == path

    if interested and
         Enum.any?(events, fn e -> e in [:modified, :closed_write, :moved_to, :created] end) do
      # trigger compilation asynchronously so we quickly return from this
      # message handler
      send(self(), :trigger_compile)
    end

    {:noreply, state}
  end

  def handle_info({:file_event, _watcher_pid, :stop}, state) do
    Logger.info("Hooks watcher: file_system watcher stopped")
    {:noreply, %{state | fs_pid: nil}}
  end

  def handle_info(:trigger_compile, %{path: path} = state) when is_binary(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mtime: mtime}} ->
        if state.mtime != mtime do
          Logger.info("Hooks watcher: detected change or first load for #{path}. Loading...")

          case GameServer.Hooks.register_file(path) do
            {:ok, mod} ->
              Logger.info("Hooks watcher: registered #{inspect(mod)} from #{path}")
              {:noreply, %{state | mtime: mtime}}

            {:error, reason} ->
              Logger.error(
                "Hooks watcher: failed to register hooks from #{path}: #{inspect(reason)}"
              )

              {:noreply, %{state | mtime: mtime}}
          end
        else
          {:noreply, state}
        end

      {:error, _} ->
        # File missing or inaccessible - log and keep trying
        Logger.debug("Hooks watcher: file not found or inaccessible: #{path}")
        {:noreply, state}
    end
  end

  # Polling fallback when FileSystem watcher is not available. We simply
  # stat the file periodically and trigger compilation if mtime changed.
  def handle_info(:poll_check, %{path: path, interval_ms: interval_ms} = state)
      when is_binary(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mtime: mtime}} ->
        if state.mtime != mtime do
          send(self(), :trigger_compile)
          {:noreply, %{state | mtime: mtime, polling?: true}}
        else
          Process.send_after(self(), :poll_check, interval_ms)
          {:noreply, state}
        end

      {:error, _} ->
        # File missing; stop polling and fall back to env checks
        Process.send_after(self(), :env_check, interval_ms)
        {:noreply, %{state | polling?: false}}
    end
  end

  def handle_info(_msg, state) do
    # ignore other messages
    {:noreply, state}
  end

  defp start_fs(path) do
    dir = Path.dirname(path)

    # Use a distinct registered name for the FileSystem process so it
    # doesn't conflict with this GenServer's registered name (__MODULE__).
    # If someone else already started a watcher for the same directory we
    # will reuse it via the {:already_started, pid} clause below.
    fs_name = Module.concat(__MODULE__, :FileSystem)

    case FileSystem.start_link(dirs: [dir], name: fs_name) do
      {:ok, pid} ->
        FileSystem.subscribe(pid)
        {:ok, pid}

      # If the FileSystem process is already started under the same name,
      # subscribe to it and reuse the existing pid instead of returning an
      # error. This avoids noisy `{:already_started, pid}` failures and
      # supports environments where the watcher may already be running.
      {:error, {:already_started, pid}} ->
        FileSystem.subscribe(pid)
        {:ok, pid}

      :ignore ->
        # file_system returned :ignore (e.g. missing platform binary). Treat
        # this as an error so the caller can fallback to polling instead of
        # crashing on an unexpected atom.
        {:error, :ignored}

      {:error, _} = err ->
        err
    end
  end
end
