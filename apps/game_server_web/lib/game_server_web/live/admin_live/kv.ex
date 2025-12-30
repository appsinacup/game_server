defmodule GameServerWeb.AdminLive.KV do
  use GameServerWeb, :live_view

  alias GameServer.KV

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.link navigate={~p"/admin"} class="btn btn-outline mb-4">
          ← Back to Admin
        </.link>

        <div class="card bg-base-200">
          <div class="card-body">
            <div class="flex items-center justify-between gap-4">
              <h2 class="card-title">KV Entries ({@count})</h2>
              <div class="flex items-center gap-2">
                <button
                  id="admin-kv-new-entry"
                  type="button"
                  phx-click="new_entry"
                  class="btn btn-sm btn-primary"
                >
                  + New Entry
                </button>
                <button
                  type="button"
                  phx-click="bulk_delete"
                  data-confirm={"Delete #{MapSet.size(@selected_ids)} selected KV entries?"}
                  class="btn btn-sm btn-outline btn-error"
                  disabled={MapSet.size(@selected_ids) == 0}
                >
                  Delete selected ({MapSet.size(@selected_ids)})
                </button>
                <div class="text-xs text-base-content/60">
                  page {@page} / {@total_pages}
                </div>
              </div>
            </div>

            <div class="mt-6">
              <h3 class="font-semibold text-sm mb-2">Filters</h3>

              <.form
                for={@filter_form}
                id="admin-kv-filters"
                phx-change="filters_change"
                class="space-y-3"
              >
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <.input
                    field={@filter_form[:key]}
                    type="text"
                    label="Key contains"
                    phx-debounce="300"
                  />
                  <.input
                    field={@filter_form[:user_id]}
                    type="number"
                    label="User ID"
                    inputmode="numeric"
                  />
                  <.input
                    field={@filter_form[:global_only]}
                    type="checkbox"
                    label="Global only"
                  />
                </div>

                <div class="flex gap-2">
                  <button type="button" phx-click="filters_clear" class="btn btn-sm btn-ghost">
                    Clear
                  </button>
                </div>
              </.form>
            </div>

            <div class="overflow-x-auto mt-4">
              <table id="admin-kv-table" class="table table-zebra w-full table-fixed">
                <colgroup>
                  <col class="w-10" />
                  <col class="w-16" />
                  <col class="w-[40%]" />
                  <col class="w-20" />
                  <col class="w-40" />
                  <col class="w-[20%]" />
                  <col class="w-[20%]" />
                  <col class="w-32" />
                </colgroup>
                <thead>
                  <tr>
                    <th class="w-10">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-sm"
                        phx-click="toggle_select_all"
                        checked={@entries != [] && MapSet.size(@selected_ids) == length(@entries)}
                      />
                    </th>
                    <th class="w-16">ID</th>
                    <th class="font-mono text-sm break-all">Key</th>
                    <th class="w-20">User</th>
                    <th class="w-40">Updated</th>
                    <th>Value</th>
                    <th>Metadata</th>
                    <th class="w-32">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={e <- @entries} id={"admin-kv-" <> to_string(e.id)}>
                    <td class="w-10">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-sm"
                        phx-click="toggle_select"
                        phx-value-id={e.id}
                        checked={MapSet.member?(@selected_ids, e.id)}
                      />
                    </td>
                    <td class="font-mono text-sm w-16">{e.id}</td>
                    <td class="font-mono text-sm break-all">{e.key}</td>
                    <td class="font-mono text-sm w-20">{e.user_id || ""}</td>
                    <td class="text-sm w-40">
                      <span class="font-mono text-xs">
                        {if e.updated_at, do: DateTime.to_iso8601(e.updated_at), else: "-"}
                      </span>
                    </td>
                    <td class="text-sm">
                      <pre class="text-xs font-mono whitespace-pre-wrap max-h-24 overflow-auto bg-base-100/60 rounded p-2">{json_preview(e.value)}</pre>
                    </td>
                    <td class="text-sm">
                      <pre class="text-xs font-mono whitespace-pre-wrap max-h-24 overflow-auto bg-base-100/60 rounded p-2">{json_preview(e.metadata)}</pre>
                    </td>
                    <td class="text-sm whitespace-nowrap w-32">
                      <button
                        type="button"
                        phx-click="edit_entry"
                        phx-value-id={e.id}
                        class="btn btn-xs btn-outline btn-info mr-2"
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        phx-click="delete_entry"
                        phx-value-id={e.id}
                        data-confirm="Delete this KV entry?"
                        class="btn btn-xs btn-outline btn-error"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div class="mt-4 flex gap-2 items-center">
              <button phx-click="kv_prev" class="btn btn-xs" disabled={@page <= 1}>
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@page} / {@total_pages} ({@count} total)
              </div>
              <button
                phx-click="kv_next"
                class="btn btn-xs"
                disabled={@page >= @total_pages || @total_pages == 0}
              >
                Next
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>

    <%= if @show_form_modal do %>
      <div class="modal modal-open">
        <div class="modal-box max-w-4xl">
          <h3 class="font-bold text-lg">
            {if(@editing?, do: "Edit KV entry", else: "New KV entry")}
          </h3>

          <.form for={@form} id="admin-kv-form" phx-submit="save_entry" class="space-y-3 mt-4">
            <input
              type="hidden"
              id={@form[:id].id}
              name={@form[:id].name}
              value={@form[:id].value}
            />

            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <.input field={@form[:key]} type="text" label="Key" required />
              <.input
                field={@form[:user_id]}
                type="number"
                label="User ID (optional)"
                inputmode="numeric"
              />
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-3">
              <.input
                field={@form[:value_json]}
                type="textarea"
                label="Value (JSON object)"
                class="w-full textarea font-mono text-xs min-h-32"
                required
              />
              <.input
                field={@form[:metadata_json]}
                type="textarea"
                label="Metadata (JSON object)"
                class="w-full textarea font-mono text-xs min-h-32"
                required
              />
            </div>

            <div class="modal-action">
              <button type="button" phx-click="close_entry_modal" class="btn">
                Cancel
              </button>
              <button id="admin-kv-save" type="submit" class="btn btn-primary">
                {if(@editing?, do: "Save changes", else: "Create")}
              </button>
            </div>
          </.form>
        </div>
      </div>
    <% end %>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    page_size = 50

    {:ok,
     socket
     |> assign(:page, page)
     |> assign(:page_size, page_size)
     |> assign(:filter_key, nil)
     |> assign(:filter_user_id, nil)
     |> assign(:filter_global_only, false)
     |> assign(
       :filter_form,
       to_form(%{"key" => "", "user_id" => "", "global_only" => "false"}, as: :filters)
     )
     |> assign(:selected_ids, MapSet.new())
     |> assign(:show_form_modal, false)
     |> assign_form_new()
     |> reload_entries()}
  end

  @impl true
  def handle_event("kv_prev", _params, socket) do
    {:noreply, socket |> assign(:page, max(1, socket.assigns.page - 1)) |> reload_entries()}
  end

  @impl true
  def handle_event("kv_next", _params, socket) do
    {:noreply, socket |> assign(:page, socket.assigns.page + 1) |> reload_entries()}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    id = parse_int(id)
    selected = socket.assigns[:selected_ids] || MapSet.new()

    selected =
      if id && MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        if id, do: MapSet.put(selected, id), else: selected
      end

    {:noreply,
     socket
     |> assign(:selected_ids, selected)
     |> sync_selected_ids(entry_ids(socket.assigns.entries))}
  end

  @impl true
  def handle_event("toggle_select_all", _params, socket) do
    entries = socket.assigns.entries || []
    ids = entry_ids(entries)

    selected = socket.assigns[:selected_ids] || MapSet.new()

    selected =
      if ids != [] and MapSet.size(selected) == length(ids) do
        MapSet.new()
      else
        MapSet.new(ids)
      end

    {:noreply, assign(socket, :selected_ids, selected)}
  end

  @impl true
  def handle_event("bulk_delete", _params, socket) do
    ids = socket.assigns[:selected_ids] || MapSet.new()
    ids = MapSet.to_list(ids)

    {deleted, failed} =
      Enum.reduce(ids, {0, 0}, fn id, {d, f} ->
        try do
          :ok = KV.delete_entry(id)
          {d + 1, f}
        rescue
          _ -> {d, f + 1}
        end
      end)

    socket = assign(socket, :selected_ids, MapSet.new())

    socket =
      cond do
        failed == 0 -> put_flash(socket, :info, "Deleted #{deleted} entries")
        deleted == 0 -> put_flash(socket, :error, "Failed to delete selected entries")
        true -> put_flash(socket, :error, "Deleted #{deleted} entries; failed #{failed}")
      end

    {:noreply, socket |> reload_entries()}
  end

  @impl true
  def handle_event("filters_change", %{"filters" => params}, socket) when is_map(params) do
    socket = assign(socket, :filter_form, to_form(params, as: :filters))

    case filters_from_params(params) do
      {:ok,
       %{
         filter_key: filter_key,
         filter_user_id: filter_user_id,
         filter_global_only: filter_global_only
       }} ->
        {:noreply,
         socket
         |> assign(:filter_key, filter_key)
         |> assign(:filter_user_id, filter_user_id)
         |> assign(:filter_global_only, filter_global_only)
         |> assign(:page, 1)
         |> reload_entries()}

      {:error, _msg} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filters_clear", _params, socket) do
    {:noreply,
     socket
     |> assign(:filter_key, nil)
     |> assign(:filter_user_id, nil)
     |> assign(:filter_global_only, false)
     |> assign(
       :filter_form,
       to_form(%{"key" => "", "user_id" => "", "global_only" => "false"}, as: :filters)
     )
     |> assign(:page, 1)
     |> reload_entries()}
  end

  @impl true
  def handle_event("new_entry", _params, socket) do
    {:noreply,
     socket
     |> assign_form_new()
     |> assign(:show_form_modal, true)}
  end

  @impl true
  def handle_event("edit_entry", %{"id" => id}, socket) do
    id = parse_int(id)

    case id && KV.get_entry(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Entry not found")}

      entry ->
        {:noreply,
         socket
         |> assign_form_edit(entry)
         |> assign(:show_form_modal, true)}
    end
  end

  @impl true
  def handle_event("close_entry_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form_modal, false)
     |> assign_form_new()}
  end

  @impl true
  def handle_event("delete_entry", %{"id" => id}, socket) do
    id = parse_int(id)

    if id do
      :ok = KV.delete_entry(id)
    end

    {:noreply, socket |> put_flash(:info, "Entry deleted") |> reload_entries()}
  end

  @impl true
  def handle_event("save_entry", %{"kv" => params}, socket) do
    attrs_result = attrs_from_form_params(params)

    case attrs_result do
      {:error, msg} ->
        {:noreply, socket |> put_flash(:error, msg)}

      {:ok, %{id: nil, attrs: attrs}} ->
        case KV.create_entry(attrs) do
          {:ok, _entry} ->
            {:noreply,
             socket
             |> put_flash(:info, "Entry created")
             |> assign_form_new()
             |> assign(:show_form_modal, false)
             |> reload_entries()}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket |> put_flash(:error, "Create failed: #{changeset_error_summary(changeset)}")}
        end

      {:ok, %{id: id, attrs: attrs}} ->
        case KV.update_entry(id, attrs) do
          {:ok, _entry} ->
            {:noreply,
             socket
             |> put_flash(:info, "Entry updated")
             |> assign_form_new()
             |> assign(:show_form_modal, false)
             |> reload_entries()}

          {:error, :not_found} ->
            {:noreply, socket |> put_flash(:error, "Entry not found")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket |> put_flash(:error, "Update failed: #{changeset_error_summary(changeset)}")}
        end
    end
  end

  defp reload_entries(socket) do
    page = socket.assigns.page
    page_size = socket.assigns.page_size

    key = socket.assigns.filter_key
    user_id = socket.assigns.filter_user_id
    global_only = socket.assigns.filter_global_only

    entries =
      KV.list_entries(
        page: page,
        page_size: page_size,
        key: key,
        user_id: user_id,
        global_only: global_only
      )

    count = KV.count_entries(key: key, user_id: user_id, global_only: global_only)
    total_pages = if page_size > 0, do: div(count + page_size - 1, page_size), else: 0

    socket
    |> assign(:entries, entries)
    |> assign(:count, count)
    |> assign(:total_pages, total_pages)
    |> clamp_page()
    |> sync_selected_ids(entry_ids(entries))
  end

  defp clamp_page(socket) do
    page = socket.assigns.page
    total_pages = socket.assigns.total_pages

    page =
      cond do
        total_pages == 0 -> 1
        page < 1 -> 1
        page > total_pages -> total_pages
        true -> page
      end

    assign(socket, :page, page)
  end

  defp json_preview(nil), do: ""

  defp json_preview(map) when is_map(map) do
    Jason.encode!(map)
    |> String.slice(0, 2048)
  end

  defp json_preview(_), do: ""

  defp assign_form_new(socket) do
    params = %{
      "id" => "",
      "key" => "",
      "user_id" => "",
      "value_json" => "{}",
      "metadata_json" => "{}"
    }

    socket
    |> assign(:editing?, false)
    |> assign(:form, to_form(params, as: :kv))
  end

  defp assign_form_edit(socket, entry) do
    params = %{
      "id" => to_string(entry.id),
      "key" => entry.key,
      "user_id" => if(entry.user_id, do: to_string(entry.user_id), else: ""),
      "value_json" => pretty_json(entry.value),
      "metadata_json" => pretty_json(entry.metadata)
    }

    socket
    |> assign(:editing?, true)
    |> assign(:form, to_form(params, as: :kv))
  end

  defp pretty_json(nil), do: "{}"

  defp pretty_json(%{} = map) when map_size(map) == 0, do: "{}"

  defp pretty_json(map) when is_map(map) do
    case Jason.encode(map, pretty: true) do
      {:ok, json} -> json
      _ -> "{}"
    end
  end

  defp pretty_json(_), do: "{}"

  defp entry_ids(entries) when is_list(entries), do: Enum.map(entries, & &1.id)

  defp sync_selected_ids(socket, ids) when is_list(ids) do
    selected = socket.assigns[:selected_ids] || MapSet.new()
    allowed = MapSet.new(ids)
    assign(socket, :selected_ids, MapSet.intersection(selected, allowed))
  end

  defp attrs_from_form_params(params) when is_map(params) do
    id = parse_int(Map.get(params, "id"))
    key = (Map.get(params, "key") || "") |> String.trim()

    with true <- key != "" || {:error, "Key is required"},
         {:ok, user_id} <- parse_optional_int(Map.get(params, "user_id")),
         {:ok, value} <- decode_json_object(Map.get(params, "value_json"), "Value"),
         {:ok, metadata} <- decode_json_object(Map.get(params, "metadata_json"), "Metadata") do
      attrs = %{key: key, user_id: user_id, value: value, metadata: metadata}
      {:ok, %{id: id, attrs: attrs}}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp decode_json_object(nil, label), do: {:error, "#{label} must be a JSON object"}

  defp decode_json_object(raw, label) when is_binary(raw) do
    case Jason.decode(raw) do
      {:ok, map} when is_map(map) ->
        {:ok, map}

      {:ok, _other} ->
        {:error, "#{label} must be a JSON object"}

      {:error, _} ->
        {:error, "#{label} is not valid JSON"}
    end
  end

  defp parse_optional_int(nil), do: {:ok, nil}

  defp parse_optional_int(raw) when is_binary(raw) do
    raw = String.trim(raw)

    if raw == "" do
      {:ok, nil}
    else
      case Integer.parse(raw) do
        {int, ""} when int > 0 -> {:ok, int}
        _ -> {:error, "User ID must be a positive integer"}
      end
    end
  end

  defp parse_int(nil), do: nil

  defp parse_int(raw) when is_binary(raw) do
    raw = String.trim(raw)

    case Integer.parse(raw) do
      {int, ""} when int > 0 -> int
      _ -> nil
    end
  end

  defp changeset_error_summary(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, val}, acc ->
        String.replace(acc, "%{#{key}}", to_string(val))
      end)
    end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end

  defp filters_from_params(params) when is_map(params) do
    key = (Map.get(params, "key") || "") |> String.trim()
    key = if key == "", do: nil, else: key

    global_only = parse_bool(Map.get(params, "global_only"))

    case parse_optional_int(Map.get(params, "user_id")) do
      {:ok, user_id} ->
        user_id = if(global_only, do: nil, else: user_id)
        {:ok, %{filter_key: key, filter_user_id: user_id, filter_global_only: global_only}}

      {:error, msg} ->
        {:error, msg}
    end
  end

  defp parse_bool(true), do: true
  defp parse_bool("true"), do: true
  defp parse_bool("on"), do: true
  defp parse_bool(_), do: false
end
