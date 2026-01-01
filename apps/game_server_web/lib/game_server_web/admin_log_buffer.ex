defmodule GameServerWeb.AdminLogBuffer do
  @moduledoc false

  use GenServer

  @name __MODULE__
  @topic "admin_logs"
  @max_entries 1000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  def topic, do: @topic

  def put(entry) when is_map(entry) do
    GenServer.cast(@name, {:put, entry})
  end

  def list(opts \\ []) do
    module_filter = Keyword.get(opts, :module)
    limit = Keyword.get(opts, :limit, @max_entries)

    GenServer.call(@name, {:list, module_filter, limit})
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
  def handle_call({:list, module_filter, limit}, _from, state) do
    entries =
      state.entries
      |> maybe_filter_module(module_filter)
      |> Enum.take(limit)

    {:reply, entries, state}
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
