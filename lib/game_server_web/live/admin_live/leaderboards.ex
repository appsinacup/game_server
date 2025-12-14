defmodule GameServerWeb.AdminLive.Leaderboards do
  use GameServerWeb, :live_view

  alias GameServer.Leaderboards
  alias GameServer.Leaderboards.Leaderboard
  alias GameServer.Leaderboards.Record

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page, 1)
      |> assign(:page_size, 25)
      |> assign(:filter, "all")
      |> assign(:selected_leaderboard, nil)
      |> assign(:viewing_records, false)
      |> assign(:records_page, 1)
      |> assign(:form, nil)
      |> assign(:record_form, nil)
      |> assign(:editing_record, nil)
      |> reload_leaderboards()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.link navigate={~p"/admin"} class="btn btn-outline mb-4">← Back to Admin</.link>

        <div class="card bg-base-200">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Leaderboards ({@count})</h2>
              <button phx-click="new_leaderboard" class="btn btn-primary btn-sm">
                + Create Leaderboard
              </button>
            </div>

            <div class="flex gap-2 mt-4">
              <button
                phx-click="set_filter"
                phx-value-filter="all"
                class={["btn btn-sm", @filter == "all" && "btn-active"]}
              >
                All
              </button>
              <button
                phx-click="set_filter"
                phx-value-filter="active"
                class={["btn btn-sm", @filter == "active" && "btn-active"]}
              >
                Active
              </button>
              <button
                phx-click="set_filter"
                phx-value-filter="ended"
                class={["btn btn-sm", @filter == "ended" && "btn-active"]}
              >
                Ended
              </button>
            </div>

            <div class="overflow-x-auto mt-4">
              <table class="table table-zebra w-full">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Slug</th>
                    <th>Title</th>
                    <th>Sort</th>
                    <th>Operator</th>
                    <th>Status</th>
                    <th>Records</th>
                    <th>Created</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={lb <- @leaderboards} id={"admin-lb-#{lb.id}"}>
                    <td class="font-mono text-sm">{lb.id}</td>
                    <td class="font-mono text-sm">{lb.slug}</td>
                    <td class="text-sm">{lb.title}</td>
                    <td class="text-sm">
                      <span class="badge badge-ghost badge-sm">{lb.sort_order}</span>
                    </td>
                    <td class="text-sm">
                      <span class="badge badge-ghost badge-sm">{lb.operator}</span>
                    </td>
                    <td class="text-sm">
                      <%= if Leaderboard.active?(lb) do %>
                        <span class="badge badge-success badge-sm">Active</span>
                      <% else %>
                        <span class="badge badge-neutral badge-sm">Ended</span>
                      <% end %>
                    </td>
                    <td class="text-sm">{Leaderboards.count_records(lb.id)}</td>
                    <td class="text-sm">
                      {Calendar.strftime(lb.inserted_at, "%Y-%m-%d %H:%M")}
                    </td>
                    <td class="text-sm flex gap-1">
                      <button
                        phx-click="view_records"
                        phx-value-id={lb.id}
                        class="btn btn-xs btn-outline"
                      >
                        Records
                      </button>
                      <button
                        phx-click="edit_leaderboard"
                        phx-value-id={lb.id}
                        class="btn btn-xs btn-outline btn-info"
                      >
                        Edit
                      </button>
                      <%= if Leaderboard.active?(lb) do %>
                        <button
                          phx-click="end_leaderboard"
                          phx-value-id={lb.id}
                          data-confirm="End this leaderboard? No more scores can be submitted."
                          class="btn btn-xs btn-outline btn-warning"
                        >
                          End
                        </button>
                      <% end %>
                      <button
                        phx-click="delete_leaderboard"
                        phx-value-id={lb.id}
                        data-confirm="Delete this leaderboard and all its records?"
                        class="btn btn-xs btn-outline btn-error"
                      >
                        Delete
                      </button>
                      <button
                        phx-click="new_season_from"
                        phx-value-id={lb.id}
                        class="btn btn-xs btn-outline btn-success"
                        title="Create new season with same settings"
                      >
                        + Season
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div class="mt-4 flex gap-2 items-center">
              <button phx-click="prev_page" class="btn btn-xs" disabled={@page <= 1}>
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@page} / {@total_pages} ({@count} total)
              </div>
              <button
                phx-click="next_page"
                class="btn btn-xs"
                disabled={@page >= @total_pages || @total_pages == 0}
              >
                Next
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Create/Edit Leaderboard Modal --%>
      <%= if @form do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">
              {if @selected_leaderboard, do: "Edit Leaderboard", else: "Create Leaderboard"}
            </h3>

            <.form for={@form} id="leaderboard-form" phx-submit="save_leaderboard">
              <%= if is_nil(@selected_leaderboard) do %>
                <.input
                  field={@form[:slug]}
                  type="text"
                  label="Slug (unique identifier, e.g. weekly_kills)"
                />
              <% else %>
                <div class="form-control">
                  <label class="label"><span class="label-text">Slug</span></label>
                  <input
                    type="text"
                    value={@selected_leaderboard.slug}
                    class="input input-bordered opacity-60"
                    disabled
                  />
                  <label class="label">
                    <span class="label-text-alt text-base-content/50">
                      Slug cannot be changed after creation
                    </span>
                  </label>
                </div>
              <% end %>
              <.input field={@form[:title]} type="text" label="Title" />
              <.input field={@form[:description]} type="textarea" label="Description" />

              <%= if is_nil(@selected_leaderboard) do %>
                <div class="form-control">
                  <label class="label"><span class="label-text">Sort Order</span></label>
                  <select name="leaderboard[sort_order]" class="select select-bordered">
                    <option value="desc" selected={@form[:sort_order].value == :desc}>
                      Descending (higher is better)
                    </option>
                    <option value="asc" selected={@form[:sort_order].value == :asc}>
                      Ascending (lower is better)
                    </option>
                  </select>
                </div>

                <div class="form-control">
                  <label class="label"><span class="label-text">Operator</span></label>
                  <select name="leaderboard[operator]" class="select select-bordered">
                    <option value="best" selected={@form[:operator].value == :best}>
                      Best (keep best score)
                    </option>
                    <option value="set" selected={@form[:operator].value == :set}>
                      Set (always replace)
                    </option>
                    <option value="incr" selected={@form[:operator].value == :incr}>
                      Increment (add to score)
                    </option>
                    <option value="decr" selected={@form[:operator].value == :decr}>
                      Decrement (subtract from score)
                    </option>
                  </select>
                </div>
              <% end %>

              <.input field={@form[:starts_at]} type="datetime-local" label="Starts at (optional)" />
              <.input field={@form[:ends_at]} type="datetime-local" label="Ends at (optional)" />

              <div class="form-control">
                <label class="label"><span class="label-text">Metadata (JSON)</span></label>
                <textarea
                  name="leaderboard[metadata]"
                  class="textarea textarea-bordered"
                  rows="3"
                ><%= Jason.encode!((@selected_leaderboard && @selected_leaderboard.metadata) || %{}) %></textarea>
              </div>

              <div class="modal-action">
                <button type="button" phx-click="cancel_edit" class="btn">Cancel</button>
                <button type="submit" class="btn btn-primary">Save</button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <%!-- View Records Modal --%>
      <%= if @viewing_records && @selected_leaderboard do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-4xl">
            <div class="flex items-center justify-between">
              <h3 class="font-bold text-lg">
                Records: {@selected_leaderboard.title}
              </h3>
              <button
                phx-click="add_record"
                class="btn btn-sm btn-primary"
                disabled={not Leaderboard.active?(@selected_leaderboard)}
              >
                + Add Record
              </button>
            </div>

            <div class="overflow-x-auto mt-4">
              <table class="table table-zebra w-full">
                <thead>
                  <tr>
                    <th>Rank</th>
                    <th>User ID</th>
                    <th>Display Name</th>
                    <th>Score</th>
                    <th>Updated</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={record <- @records} id={"record-#{record.id}"}>
                    <td class="font-mono">#{record.rank}</td>
                    <td class="font-mono text-sm">{record.user_id}</td>
                    <td class="text-sm">{(record.user && record.user.display_name) || "-"}</td>
                    <td class="font-mono">{record.score}</td>
                    <td class="text-sm">
                      {Calendar.strftime(record.updated_at, "%Y-%m-%d %H:%M")}
                    </td>
                    <td class="flex gap-1">
                      <button
                        phx-click="edit_record"
                        phx-value-id={record.id}
                        class="btn btn-xs btn-outline btn-info"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete_record"
                        phx-value-id={record.id}
                        data-confirm="Delete this record?"
                        class="btn btn-xs btn-outline btn-error"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div class="mt-4 flex gap-2 items-center justify-between">
              <div class="flex gap-2 items-center">
                <button
                  phx-click="records_prev_page"
                  class="btn btn-xs"
                  disabled={@records_page <= 1}
                >
                  Prev
                </button>
                <div class="text-xs text-base-content/70">
                  page {@records_page} / {@records_total_pages} ({@records_count} total)
                </div>
                <button
                  phx-click="records_next_page"
                  class="btn btn-xs"
                  disabled={@records_page >= @records_total_pages}
                >
                  Next
                </button>
              </div>
              <button phx-click="close_records" class="btn btn-sm">Close</button>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Add/Edit Record Modal --%>
      <%= if @record_form do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">
              {if @editing_record, do: "Edit Record", else: "Add Record"}
            </h3>

            <.form for={@record_form} id="record-form" phx-submit="save_record">
              <%= if is_nil(@editing_record) do %>
                <.input field={@record_form[:user_id]} type="number" label="User ID" />
              <% end %>
              <.input field={@record_form[:score]} type="number" label="Score" />

              <div class="form-control">
                <label class="label"><span class="label-text">Metadata (JSON)</span></label>
                <textarea
                  name="record[metadata]"
                  class="textarea textarea-bordered"
                  rows="3"
                ><%= Jason.encode!((@editing_record && @editing_record.metadata) || %{}) %></textarea>
              </div>

              <div class="modal-action">
                <button type="button" phx-click="cancel_record_edit" class="btn">Cancel</button>
                <button type="submit" class="btn btn-primary">Save</button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Event Handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:page, 1)
     |> reload_leaderboards()}
  end

  def handle_event("prev_page", _, socket) do
    {:noreply,
     socket
     |> assign(:page, max(1, socket.assigns.page - 1))
     |> reload_leaderboards()}
  end

  def handle_event("next_page", _, socket) do
    {:noreply,
     socket
     |> assign(:page, socket.assigns.page + 1)
     |> reload_leaderboards()}
  end

  def handle_event("new_leaderboard", _, socket) do
    changeset = Leaderboards.change_leaderboard(%Leaderboard{})
    form = to_form(changeset, as: "leaderboard")

    {:noreply,
     socket
     |> assign(:selected_leaderboard, nil)
     |> assign(:form, form)}
  end

  def handle_event("new_season_from", %{"id" => id}, socket) do
    # Load the existing leaderboard to copy settings from
    source = Leaderboards.get_leaderboard!(String.to_integer(id))

    # Create a new leaderboard struct with copied settings
    new_leaderboard = %Leaderboard{
      slug: source.slug,
      title: source.title,
      description: source.description,
      sort_order: source.sort_order,
      operator: source.operator,
      metadata: source.metadata
    }

    changeset = Leaderboards.change_leaderboard(new_leaderboard)
    form = to_form(changeset, as: "leaderboard")

    {:noreply,
     socket
     |> assign(:selected_leaderboard, nil)
     |> assign(:form, form)}
  end

  def handle_event("edit_leaderboard", %{"id" => id}, socket) do
    leaderboard = Leaderboards.get_leaderboard!(String.to_integer(id))
    changeset = Leaderboards.change_leaderboard(leaderboard)
    form = to_form(changeset, as: "leaderboard")

    {:noreply,
     socket
     |> assign(:selected_leaderboard, leaderboard)
     |> assign(:form, form)}
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_leaderboard, nil)
     |> assign(:form, nil)}
  end

  def handle_event("save_leaderboard", %{"leaderboard" => params}, socket) do
    # Parse metadata JSON
    params =
      Map.update(params, "metadata", %{}, fn metadata_str ->
        case Jason.decode(metadata_str) do
          {:ok, map} when is_map(map) -> map
          _ -> %{}
        end
      end)

    result =
      case socket.assigns.selected_leaderboard do
        nil ->
          Leaderboards.create_leaderboard(params)

        lb ->
          Leaderboards.update_leaderboard(lb, params)
      end

    case result do
      {:ok, _lb} ->
        {:noreply,
         socket
         |> put_flash(:info, "Leaderboard saved")
         |> assign(:selected_leaderboard, nil)
         |> assign(:form, nil)
         |> reload_leaderboards()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "leaderboard"))}
    end
  end

  def handle_event("end_leaderboard", %{"id" => id}, socket) do
    case Leaderboards.end_leaderboard(String.to_integer(id)) do
      {:ok, _lb} ->
        {:noreply,
         socket
         |> put_flash(:info, "Leaderboard ended")
         |> reload_leaderboards()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to end leaderboard")}
    end
  end

  def handle_event("delete_leaderboard", %{"id" => id}, socket) do
    lb = Leaderboards.get_leaderboard!(String.to_integer(id))

    case Leaderboards.delete_leaderboard(lb) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Leaderboard deleted")
         |> reload_leaderboards()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete leaderboard")}
    end
  end

  # Records
  def handle_event("view_records", %{"id" => id}, socket) do
    leaderboard = Leaderboards.get_leaderboard!(String.to_integer(id))

    {:noreply,
     socket
     |> assign(:selected_leaderboard, leaderboard)
     |> assign(:viewing_records, true)
     |> assign(:records_page, 1)
     |> reload_records()}
  end

  def handle_event("close_records", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_leaderboard, nil)
     |> assign(:viewing_records, false)
     |> assign(:records, [])}
  end

  def handle_event("records_prev_page", _, socket) do
    {:noreply,
     socket
     |> assign(:records_page, max(1, socket.assigns.records_page - 1))
     |> reload_records()}
  end

  def handle_event("records_next_page", _, socket) do
    {:noreply,
     socket
     |> assign(:records_page, socket.assigns.records_page + 1)
     |> reload_records()}
  end

  def handle_event("add_record", _, socket) do
    changeset = Leaderboards.change_record(%Record{})
    form = to_form(changeset, as: "record")

    {:noreply,
     socket
     |> assign(:editing_record, nil)
     |> assign(:record_form, form)}
  end

  def handle_event("edit_record", %{"id" => id}, socket) do
    record = Leaderboards.get_record!(String.to_integer(id))
    changeset = Leaderboards.change_record(record)
    form = to_form(changeset, as: "record")

    {:noreply,
     socket
     |> assign(:editing_record, record)
     |> assign(:record_form, form)}
  end

  def handle_event("cancel_record_edit", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_record, nil)
     |> assign(:record_form, nil)}
  end

  def handle_event("save_record", %{"record" => params}, socket) do
    lb = socket.assigns.selected_leaderboard

    # Parse metadata JSON
    params =
      Map.update(params, "metadata", %{}, fn metadata_str ->
        case Jason.decode(metadata_str) do
          {:ok, map} when is_map(map) -> map
          _ -> %{}
        end
      end)

    result =
      case socket.assigns.editing_record do
        nil ->
          # Create new record via submit_score
          user_id = String.to_integer(params["user_id"])
          score = String.to_integer(params["score"])
          Leaderboards.submit_score(lb.id, user_id, score, params["metadata"] || %{})

        record ->
          # Update existing record
          Leaderboards.update_record(record, params)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Record saved")
         |> assign(:editing_record, nil)
         |> assign(:record_form, nil)
         |> reload_records()}

      {:error, changeset} ->
        {:noreply, assign(socket, :record_form, to_form(changeset, as: "record"))}
    end
  end

  def handle_event("delete_record", %{"id" => id}, socket) do
    record = Leaderboards.get_record!(String.to_integer(id))

    case Leaderboards.delete_record(record) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Record deleted")
         |> reload_records()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete record")}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp reload_leaderboards(socket) do
    page = socket.assigns[:page] || 1
    page_size = socket.assigns[:page_size] || 25

    opts =
      [page: page, page_size: page_size]
      |> maybe_add_filter(socket.assigns[:filter])

    leaderboards = Leaderboards.list_leaderboards(opts)
    count = Leaderboards.count_leaderboards(Keyword.take(opts, [:active]))
    total_pages = if page_size > 0, do: div(count + page_size - 1, page_size), else: 0

    socket
    |> assign(:leaderboards, leaderboards)
    |> assign(:count, count)
    |> assign(:total_pages, total_pages)
  end

  defp maybe_add_filter(opts, "active"), do: Keyword.put(opts, :active, true)
  defp maybe_add_filter(opts, "ended"), do: Keyword.put(opts, :active, false)
  defp maybe_add_filter(opts, _), do: opts

  defp reload_records(socket) do
    lb = socket.assigns.selected_leaderboard
    page = socket.assigns[:records_page] || 1
    page_size = 25

    records = Leaderboards.list_records(lb.id, page: page, page_size: page_size)
    count = Leaderboards.count_records(lb.id)
    total_pages = if page_size > 0, do: div(count + page_size - 1, page_size), else: 0

    socket
    |> assign(:records, records)
    |> assign(:records_count, count)
    |> assign(:records_total_pages, max(total_pages, 1))
  end
end
