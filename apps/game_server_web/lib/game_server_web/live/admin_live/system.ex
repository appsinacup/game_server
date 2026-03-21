defmodule GameServerWeb.AdminLive.System do
  use GameServerWeb, :live_view

  alias GameServerWeb.ConnectionTracker

  @refresh_interval 5_000

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="space-y-6">
        <.link navigate={~p"/admin"} class="btn btn-outline mb-4">&larr; Back to Admin</.link>

        <%!-- Top-level stats --%>
        <div class="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-6 gap-4">
          <div class="stat bg-base-100 rounded-lg shadow-sm p-4">
            <div class="stat-title text-xs">Uptime</div>
            <div class="stat-value text-xl">
              {ConnectionTracker.format_uptime(@sys.uptime_seconds)}
            </div>
          </div>
          <div class="stat bg-base-100 rounded-lg shadow-sm p-4">
            <div class="stat-title text-xs">OTP</div>
            <div class="stat-value text-xl">{@sys.otp_release}</div>
          </div>
          <div class="stat bg-base-100 rounded-lg shadow-sm p-4">
            <div class="stat-title text-xs">Schedulers</div>
            <div class="stat-value text-xl">{@sys.schedulers}</div>
          </div>
          <div class="stat bg-base-100 rounded-lg shadow-sm p-4">
            <div class="stat-title text-xs">Node</div>
            <div class="stat-value text-sm font-mono break-all">{@sys.node}</div>
          </div>
          <div class="stat bg-base-100 rounded-lg shadow-sm p-4">
            <div class="stat-title text-xs">Cluster Nodes</div>
            <div class="stat-value text-xl">{@sys.cluster_size}</div>
          </div>
          <div class="stat bg-base-100 rounded-lg shadow-sm p-4">
            <div class="stat-title text-xs">Elixir</div>
            <div class="stat-value text-xl">{@elixir_version}</div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- Memory breakdown --%>
          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg flex items-center gap-2">
                <.icon name="hero-cpu-chip" class="w-5 h-5 text-primary" />
                Memory
              </h2>
              <div class="overflow-x-auto">
                <table class="table table-sm">
                  <thead>
                    <tr>
                      <th>Category</th>
                      <th class="text-right">MB</th>
                      <th class="text-right">% of Total</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={{label, mb, pct} <- @memory_breakdown} id={"mem-#{label}"}>
                      <td class="font-medium">{label}</td>
                      <td class="text-right font-mono">{mb}</td>
                      <td class="text-right">
                        <div class="flex items-center justify-end gap-2">
                          <div class="w-16 bg-base-300 rounded-full h-2">
                            <div
                              class="bg-primary h-2 rounded-full transition-all"
                              style={"width: #{min(pct, 100)}%"}
                            >
                            </div>
                          </div>
                          <span class="font-mono text-xs w-10 text-right">{pct}%</span>
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <%!-- Processes & Ports --%>
          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg flex items-center gap-2">
                <.icon name="hero-squares-2x2" class="w-5 h-5 text-secondary" />
                Processes & Ports
              </h2>
              <div class="space-y-6 mt-2">
                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span class="font-medium">Processes</span>
                    <span class="font-mono">
                      {format_number(@sys.process_count)} / {format_number(@sys.process_limit)}
                    </span>
                  </div>
                  <div class="w-full bg-base-300 rounded-full h-3">
                    <div
                      class={[
                        "h-3 rounded-full transition-all",
                        process_usage_color(@process_pct)
                      ]}
                      style={"width: #{@process_pct}%"}
                    >
                    </div>
                  </div>
                  <div class="text-xs text-base-content/60 mt-1">
                    {Float.round(@process_pct, 2)}% utilization
                  </div>
                </div>

                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span class="font-medium">Ports</span>
                    <span class="font-mono">
                      {format_number(@sys.port_count)} / {format_number(@sys.port_limit)}
                    </span>
                  </div>
                  <div class="w-full bg-base-300 rounded-full h-3">
                    <div
                      class={[
                        "h-3 rounded-full transition-all",
                        process_usage_color(@port_pct)
                      ]}
                      style={"width: #{@port_pct}%"}
                    >
                    </div>
                  </div>
                  <div class="text-xs text-base-content/60 mt-1">
                    {Float.round(@port_pct, 2)}% utilization
                  </div>
                </div>

                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span class="font-medium">Atoms</span>
                    <span class="font-mono">
                      {format_number(@atom_count)} / {format_number(@atom_limit)}
                    </span>
                  </div>
                  <div class="w-full bg-base-300 rounded-full h-3">
                    <div
                      class={[
                        "h-3 rounded-full transition-all",
                        process_usage_color(@atom_pct)
                      ]}
                      style={"width: #{@atom_pct}%"}
                    >
                    </div>
                  </div>
                  <div class="text-xs text-base-content/60 mt-1">
                    {Float.round(@atom_pct, 2)}% utilization
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- IO stats --%>
          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg flex items-center gap-2">
                <.icon name="hero-arrow-path" class="w-5 h-5 text-accent" />
                I/O & GC
              </h2>
              <div class="overflow-x-auto">
                <table class="table table-sm">
                  <thead>
                    <tr>
                      <th>Metric</th>
                      <th class="text-right">Value</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <td class="font-medium">I/O Input</td>
                      <td class="text-right font-mono">{format_bytes(@io_input)}</td>
                    </tr>
                    <tr>
                      <td class="font-medium">I/O Output</td>
                      <td class="text-right font-mono">{format_bytes(@io_output)}</td>
                    </tr>
                    <tr>
                      <td class="font-medium">GC Runs</td>
                      <td class="text-right font-mono">{format_number(@gc_count)}</td>
                    </tr>
                    <tr>
                      <td class="font-medium">GC Words Reclaimed</td>
                      <td class="text-right font-mono">{format_bytes(@gc_words_reclaimed * 8)}</td>
                    </tr>
                    <tr>
                      <td class="font-medium">Reductions</td>
                      <td class="text-right font-mono">{format_number(@reductions)}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <%!-- ETS tables --%>
          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg flex items-center gap-2">
                <.icon name="hero-table-cells" class="w-5 h-5 text-info" />
                ETS Tables
                <span class="badge badge-sm badge-ghost">{length(@ets_tables)}</span>
              </h2>
              <div class="overflow-x-auto max-h-80">
                <table class="table table-xs table-zebra">
                  <thead class="sticky top-0 bg-base-200">
                    <tr>
                      <th>Name</th>
                      <th class="text-right">Size</th>
                      <th class="text-right">Memory</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={table <- @ets_tables} id={"ets-#{table.id}"}>
                      <td class="font-mono text-xs truncate max-w-48">{table.name}</td>
                      <td class="text-right font-mono text-xs">{format_number(table.size)}</td>
                      <td class="text-right font-mono text-xs">{format_bytes(table.memory)}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <%!-- Cluster nodes --%>
        <%= if @cluster_nodes != [] do %>
          <div class="card bg-base-200 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg flex items-center gap-2">
                <.icon name="hero-server-stack" class="w-5 h-5 text-warning" />
                Cluster Topology
              </h2>
              <div class="flex flex-wrap gap-2 mt-2">
                <div class="badge badge-lg badge-primary gap-1">
                  <span class="w-2 h-2 rounded-full bg-success"></span>
                  {@sys.node} (self)
                </div>
                <div
                  :for={n <- @cluster_nodes}
                  class="badge badge-lg badge-outline badge-primary gap-1"
                >
                  <span class="w-2 h-2 rounded-full bg-success"></span>
                  {n}
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok, assign_all_stats(socket)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()
    {:noreply, assign_all_stats(socket)}
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

  defp assign_all_stats(socket) do
    sys = ConnectionTracker.system_stats()
    memory = :erlang.memory()
    total_bytes = memory[:total]
    {io_input, io_output} = :erlang.statistics(:io) |> then(fn {{:input, i}, {:output, o}} -> {i, o} end)
    {gc_count, gc_words, _} = :erlang.statistics(:garbage_collection)
    {reductions, _} = :erlang.statistics(:exact_reductions)

    memory_breakdown = build_memory_breakdown(memory, total_bytes)

    process_pct = safe_pct(sys.process_count, sys.process_limit)
    port_pct = safe_pct(sys.port_count, sys.port_limit)

    atom_count = :erlang.system_info(:atom_count)
    atom_limit = :erlang.system_info(:atom_limit)
    atom_pct = safe_pct(atom_count, atom_limit)

    ets_tables = build_ets_tables()

    assign(socket,
      sys: sys,
      elixir_version: System.version(),
      memory_breakdown: memory_breakdown,
      process_pct: process_pct,
      port_pct: port_pct,
      atom_count: atom_count,
      atom_limit: atom_limit,
      atom_pct: atom_pct,
      io_input: io_input,
      io_output: io_output,
      gc_count: gc_count,
      gc_words_reclaimed: gc_words,
      reductions: reductions,
      ets_tables: ets_tables,
      cluster_nodes: Node.list()
    )
  end

  defp build_memory_breakdown(memory, total_bytes) do
    categories = [
      {"Total", memory[:total]},
      {"Processes", memory[:processes]},
      {"ETS", memory[:ets]},
      {"Atom", memory[:atom]},
      {"Binary", memory[:binary]},
      {"Code", memory[:code]},
      {"System", memory[:system]}
    ]

    Enum.map(categories, fn {label, bytes} ->
      mb = Float.round(bytes / 1_048_576, 2)
      pct = if total_bytes > 0, do: Float.round(bytes / total_bytes * 100, 1), else: 0.0
      {label, mb, pct}
    end)
  end

  defp build_ets_tables do
    :ets.all()
    |> Enum.with_index()
    |> Enum.map(fn {table_id, idx} ->
      try do
        info = :ets.info(table_id)

        name =
          case Keyword.get(info, :name, table_id) do
            n when is_atom(n) -> Atom.to_string(n)
            n when is_binary(n) -> n
            _ -> "unnamed_#{idx}"
          end

        %{
          id: idx,
          name: name,
          size: Keyword.get(info, :size, 0),
          memory: Keyword.get(info, :memory, 0) * :erlang.system_info(:wordsize)
        }
      rescue
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.memory, :desc)
  end

  defp safe_pct(count, limit) when limit > 0, do: count / limit * 100
  defp safe_pct(_, _), do: 0.0

  defp process_usage_color(pct) when pct > 80, do: "bg-error"
  defp process_usage_color(pct) when pct > 50, do: "bg-warning"
  defp process_usage_color(_), do: "bg-success"

  defp format_number(n) when is_integer(n) and n >= 1_000_000_000 do
    "#{Float.round(n / 1_000_000_000, 1)}B"
  end

  defp format_number(n) when is_integer(n) and n >= 1_000_000 do
    "#{Float.round(n / 1_000_000, 1)}M"
  end

  defp format_number(n) when is_integer(n) and n >= 1_000 do
    "#{Float.round(n / 1_000, 1)}K"
  end

  defp format_number(n), do: to_string(n)

  defp format_bytes(bytes) when bytes >= 1_073_741_824 do
    "#{Float.round(bytes / 1_073_741_824, 2)} GB"
  end

  defp format_bytes(bytes) when bytes >= 1_048_576 do
    "#{Float.round(bytes / 1_048_576, 2)} MB"
  end

  defp format_bytes(bytes) when bytes >= 1_024 do
    "#{Float.round(bytes / 1_024, 1)} KB"
  end

  defp format_bytes(bytes), do: "#{bytes} B"
end
