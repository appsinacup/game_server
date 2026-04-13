defmodule GameServerWeb.AdminLogBuffer do
  @moduledoc false

  use GenServer

  @name __MODULE__
  @topic "admin_logs"
  @max_entries 5000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  def topic, do: @topic

  def put(entry) when is_map(entry) do
    GenServer.cast(@name, {:put, entry})
  end

  def list(opts \\ []) do
    module_filter = Keyword.get(opts, :module)
    level_filter = Keyword.get(opts, :level)
    limit = Keyword.get(opts, :limit, @max_entries)

    GenServer.call(@name, {:list, module_filter, level_filter, limit})
  end

  @doc "Returns a map of level => count for all buffered entries."
  def count_by_level do
    GenServer.call(@name, :count_by_level)
  end

  @doc "Returns the count of error/critical/alert/emergency entries in the last `seconds` seconds."
  def count_recent_errors(seconds \\ 3600) do
    GenServer.call(@name, {:count_recent_errors, seconds})
  end

  @impl true
  def init(_) do
    _ = GameServerWeb.AdminLogHandler.install()
    {:ok, %{entries: []}}
  end

  @impl true
  def handle_cast({:put, entry}, state) do
    entry = normalize_entry(entry)

    entries = [entry | state.entries] |> Enum.take(@max_entries)

    Phoenix.PubSub.broadcast(GameServer.PubSub, @topic, {:admin_log, entry})

    {:noreply, %{state | entries: entries}}
  end

  @impl true
  def handle_call({:list, module_filter, level_filter, limit}, _from, state) do
    entries =
      state.entries
      |> maybe_filter_module(module_filter)
      |> maybe_filter_level(level_filter)
      |> Enum.take(limit)

    {:reply, entries, state}
  end

  def handle_call(:count_by_level, _from, state) do
    counts =
      state.entries
      |> Enum.group_by(& &1.level)
      |> Map.new(fn {level, entries} -> {level, length(entries)} end)

    {:reply, counts, state}
  end

  def handle_call({:count_recent_errors, seconds}, _from, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -seconds, :second)
    error_levels = [:error, :critical, :alert, :emergency]

    count =
      Enum.count(state.entries, fn entry ->
        entry.level in error_levels and DateTime.compare(entry.timestamp, cutoff) == :gt
      end)

    {:reply, count, state}
  end

  defp maybe_filter_module(entries, nil), do: entries
  defp maybe_filter_module(entries, ""), do: entries

  defp maybe_filter_module(entries, module_filter) when is_binary(module_filter) do
    filter = String.trim(module_filter)

    if filter == "" do
      entries
    else
      Enum.filter(entries, fn entry ->
        mod = entry.module

        mod_str =
          case mod do
            nil -> ""
            atom when is_atom(atom) -> Atom.to_string(atom)
            other -> to_string(other)
          end

        String.contains?(mod_str, filter)
      end)
    end
  end

  defp maybe_filter_level(entries, nil), do: entries
  defp maybe_filter_level(entries, ""), do: entries
  defp maybe_filter_level(entries, "all"), do: entries

  defp maybe_filter_level(entries, level) when is_binary(level) do
    atom_level = String.to_existing_atom(level)
    Enum.filter(entries, fn entry -> entry.level == atom_level end)
  rescue
    _ -> entries
  end

  defp normalize_entry(entry) do
    module =
      cond do
        is_atom(entry[:module]) -> entry[:module]
        is_tuple(entry[:mfa]) and tuple_size(entry[:mfa]) == 3 -> elem(entry[:mfa], 0)
        true -> nil
      end

    entry
    |> Map.put_new(:timestamp, DateTime.utc_now())
    |> Map.put(:module, module)
  end
end
