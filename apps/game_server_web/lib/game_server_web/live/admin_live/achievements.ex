defmodule GameServerWeb.AdminLive.Achievements do
  use GameServerWeb, :live_view

  alias GameServer.Achievements
  alias GameServer.Achievements.Achievement

  @impl true
  def mount(_params, _session, socket) do
    Achievements.subscribe_achievements()

    socket =
      socket
      |> assign(:page, 1)
      |> assign(:page_size, 25)
      |> assign(:selected_achievement, nil)
      |> assign(:form, nil)
      |> assign(:grant_form, nil)
      |> assign(:selected_ids, MapSet.new())
      |> reload_achievements()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="space-y-6">
        <.link navigate={~p"/admin"} class="btn btn-outline mb-4">&larr; Back to Admin</.link>

        <div class="card bg-base-200">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Achievements ({@count})</h2>
              <div class="flex gap-2">
                <button
                  type="button"
                  phx-click="bulk_delete"
                  data-confirm={"Delete #{MapSet.size(@selected_ids)} selected achievements and all user progress?"}
                  class="btn btn-sm btn-outline btn-error"
                  disabled={MapSet.size(@selected_ids) == 0}
                >
                  Delete selected ({MapSet.size(@selected_ids)})
                </button>
                <button phx-click="new_achievement" class="btn btn-primary btn-sm">
                  + Create Achievement
                </button>
              </div>
            </div>

            <div class="overflow-x-auto mt-4">
              <table class="table table-zebra w-full">
                <thead>
                  <tr>
                    <th class="w-10">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-sm"
                        phx-click="toggle_select_all"
                        checked={
                          @achievements != [] &&
                            MapSet.size(@selected_ids) == length(@achievements)
                        }
                      />
                    </th>
                    <th>ID</th>
                    <th>Slug</th>
                    <th>Title</th>
                    <th>Target</th>
                    <th>Hidden</th>
                    <th>Order</th>
                    <th>Unlock %</th>
                    <th>Created</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={a <- @achievements} id={"admin-ach-#{a.id}"}>
                    <td class="w-10">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-sm"
                        phx-click="toggle_select"
                        phx-value-id={a.id}
                        checked={MapSet.member?(@selected_ids, a.id)}
                      />
                    </td>
                    <td class="font-mono text-sm">{a.id}</td>
                    <td class="font-mono text-sm">{a.slug}</td>
                    <td class="text-sm">{a.title}</td>
                    <td class="text-sm">{a.progress_target}</td>
                    <td class="text-sm">
                      <%= if a.hidden do %>
                        <span class="badge badge-warning badge-sm">Hidden</span>
                      <% else %>
                        <span class="badge badge-success badge-sm">Visible</span>
                      <% end %>
                    </td>
                    <td class="text-sm">{a.sort_order}</td>
                    <td class="text-sm">{Achievements.unlock_percentage(a.id)}%</td>
                    <td class="text-sm">
                      {Calendar.strftime(a.inserted_at, "%Y-%m-%d %H:%M")}
                    </td>
                    <td class="text-sm flex gap-1">
                      <button
                        phx-click="edit_achievement"
                        phx-value-id={a.id}
                        class="btn btn-xs btn-outline btn-info"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="grant_form"
                        phx-value-id={a.id}
                        class="btn btn-xs btn-outline btn-success"
                      >
                        Grant
                      </button>
                      <button
                        phx-click="delete_achievement"
                        phx-value-id={a.id}
                        data-confirm="Delete this achievement and all user progress?"
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

      <%!-- Create/Edit Achievement Modal --%>
      <%= if @form do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">
              {if @selected_achievement, do: "Edit Achievement", else: "Create Achievement"}
            </h3>

            <.form for={@form} id="achievement-form" phx-submit="save_achievement">
              <%= if is_nil(@selected_achievement) do %>
                <.input
                  field={@form[:slug]}
                  type="text"
                  label="Slug (unique identifier, e.g. first_lobby)"
                />
              <% else %>
                <div class="form-control">
                  <label class="label"><span class="label-text">Slug</span></label>
                  <input
                    type="text"
                    value={@selected_achievement.slug}
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
              <.input field={@form[:icon_url]} type="text" label="Icon URL (optional)" />
              <.input
                field={@form[:progress_target]}
                type="number"
                label="Progress Target (1 = one-shot)"
              />
              <.input field={@form[:sort_order]} type="number" label="Sort Order" />
              <.input field={@form[:hidden]} type="checkbox" label="Hidden (only shown after unlock)" />

              <div class="form-control">
                <label class="label"><span class="label-text">Metadata (JSON)</span></label>
                <textarea
                  name="achievement[metadata]"
                  class="textarea textarea-bordered"
                  rows="3"
                ><%= Jason.encode!((@selected_achievement && @selected_achievement.metadata) || %{}) %></textarea>
              </div>

              <div class="modal-action">
                <button type="button" phx-click="cancel_edit" class="btn">Cancel</button>
                <button type="submit" class="btn btn-primary">Save</button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <%!-- Grant Achievement Modal --%>
      <%= if @grant_form do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">
              Grant: {@selected_achievement && @selected_achievement.title}
            </h3>
            <p class="text-sm text-base-content/60 mt-1">
              Target: {@selected_achievement && @selected_achievement.progress_target}
            </p>

            <.form
              for={@grant_form}
              id="grant-form"
              phx-submit="grant_achievement"
              phx-change="grant_validate"
            >
              <.input field={@grant_form[:user_id]} type="number" label="User ID" />

              <.input
                field={@grant_form[:mode]}
                type="select"
                label="Mode"
                options={[{"Full Unlock (set to target)", "unlock"}, {"Add Progress", "progress"}]}
              />

              <%= if Phoenix.HTML.Form.input_value(@grant_form, :mode) == "progress" do %>
                <.input field={@grant_form[:amount]} type="number" label="Progress Amount" />
              <% end %>

              <div class="modal-action">
                <button type="button" phx-click="cancel_grant" class="btn">Cancel</button>
                <button type="submit" class="btn btn-success">Grant</button>
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
  def handle_event("toggle_select", %{"id" => id}, socket) do
    id = String.to_integer(to_string(id))
    selected = socket.assigns[:selected_ids] || MapSet.new()

    selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    {:noreply,
     socket
     |> assign(:selected_ids, selected)
     |> sync_selected_ids(achievement_ids(socket.assigns.achievements))}
  end

  @impl true
  def handle_event("toggle_select_all", _params, socket) do
    achievements = socket.assigns.achievements || []
    ids = achievement_ids(achievements)
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
    ids = MapSet.to_list(socket.assigns[:selected_ids] || MapSet.new())

    {deleted, failed} =
      Enum.reduce(ids, {0, 0}, fn id, {d, f} ->
        case Achievements.get_achievement(id) do
          nil ->
            {d, f + 1}

          ach ->
            case Achievements.delete_achievement(ach) do
              {:ok, _} -> {d + 1, f}
              {:error, _} -> {d, f + 1}
            end
        end
      end)

    socket = assign(socket, :selected_ids, MapSet.new())

    socket =
      cond do
        failed == 0 ->
          put_flash(socket, :info, "Deleted #{deleted} achievements")

        deleted == 0 ->
          put_flash(socket, :error, "Failed to delete selected achievements")

        true ->
          put_flash(socket, :error, "Deleted #{deleted} achievements; failed #{failed}")
      end

    {:noreply, reload_achievements(socket)}
  end

  def handle_event("prev_page", _, socket) do
    {:noreply,
     socket
     |> assign(:page, max(1, socket.assigns.page - 1))
     |> reload_achievements()}
  end

  def handle_event("next_page", _, socket) do
    {:noreply,
     socket
     |> assign(:page, socket.assigns.page + 1)
     |> reload_achievements()}
  end

  def handle_event("new_achievement", _, socket) do
    changeset = Achievements.change_achievement(%Achievement{})
    form = to_form(changeset, as: "achievement")

    {:noreply,
     socket
     |> assign(:selected_achievement, nil)
     |> assign(:form, form)}
  end

  def handle_event("edit_achievement", %{"id" => id}, socket) do
    ach = Achievements.get_achievement(String.to_integer(id))

    changeset = Achievements.change_achievement(ach)
    form = to_form(changeset, as: "achievement")

    {:noreply,
     socket
     |> assign(:selected_achievement, ach)
     |> assign(:form, form)}
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_achievement, nil)
     |> assign(:form, nil)}
  end

  def handle_event("save_achievement", %{"achievement" => params}, socket) do
    # Parse metadata JSON
    params = parse_metadata(params)

    if socket.assigns.selected_achievement do
      case Achievements.update_achievement(socket.assigns.selected_achievement, params) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:form, nil)
           |> assign(:selected_achievement, nil)
           |> put_flash(:info, "Achievement updated")
           |> reload_achievements()}

        {:error, changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset, as: "achievement"))}
      end
    else
      case Achievements.create_achievement(params) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:form, nil)
           |> put_flash(:info, "Achievement created")
           |> reload_achievements()}

        {:error, changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset, as: "achievement"))}
      end
    end
  end

  def handle_event("delete_achievement", %{"id" => id}, socket) do
    case Achievements.get_achievement(String.to_integer(id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Achievement not found")}

      ach ->
        case Achievements.delete_achievement(ach) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Achievement deleted")
             |> reload_achievements()}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete achievement")}
        end
    end
  end

  def handle_event("grant_form", %{"id" => id}, socket) do
    ach = Achievements.get_achievement(String.to_integer(id))
    form = to_form(%{"user_id" => "", "mode" => "unlock", "amount" => "1"}, as: "grant")

    {:noreply,
     socket
     |> assign(:selected_achievement, ach)
     |> assign(:grant_form, form)}
  end

  def handle_event("grant_validate", %{"grant" => params}, socket) do
    {:noreply, assign(socket, :grant_form, to_form(params, as: "grant"))}
  end

  def handle_event("cancel_grant", _, socket) do
    {:noreply,
     socket
     |> assign(:grant_form, nil)
     |> assign(:selected_achievement, nil)}
  end

  def handle_event("grant_achievement", %{"grant" => params}, socket) do
    ach = socket.assigns.selected_achievement
    user_id_str = params["user_id"]
    mode = params["mode"] || "unlock"

    case Integer.parse(user_id_str) do
      {user_id, _} ->
        result =
          if mode == "progress" do
            amount = String.to_integer(params["amount"] || "1")
            Achievements.increment_progress(user_id, ach.slug, amount)
          else
            Achievements.grant_achievement(user_id, ach.slug)
          end

        case result do
          {:ok, _} ->
            msg =
              if mode == "progress",
                do: "Added #{params["amount"]} progress to user #{user_id}",
                else: "Achievement granted to user #{user_id}"

            {:noreply,
             socket
             |> assign(:grant_form, nil)
             |> assign(:selected_achievement, nil)
             |> put_flash(:info, msg)
             |> reload_achievements()}

          {:error, :already_unlocked} ->
            {:noreply, put_flash(socket, :error, "User already has this achievement")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to grant achievement")}
        end

      :error ->
        {:noreply, put_flash(socket, :error, "Invalid user ID")}
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:achievements_changed}, socket) do
    {:noreply, reload_achievements(socket)}
  end

  def handle_info({:achievement_unlocked, _user_id, _ua}, socket) do
    {:noreply, reload_achievements(socket)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp reload_achievements(socket) do
    page = socket.assigns[:page] || 1
    page_size = socket.assigns[:page_size] || 25

    achievements_with_progress =
      Achievements.list_achievements(
        page: page,
        page_size: page_size,
        include_hidden: true
      )

    achievements = Enum.map(achievements_with_progress, fn %{achievement: a} -> a end)
    count = Achievements.count_achievements(include_hidden: true)
    total_pages = if page_size > 0, do: div(count + page_size - 1, page_size), else: 0

    socket
    |> assign(:achievements, achievements)
    |> assign(:count, count)
    |> assign(:total_pages, max(total_pages, 1))
    |> sync_selected_ids(achievement_ids(achievements))
  end

  defp achievement_ids(achievements) when is_list(achievements),
    do: Enum.map(achievements, & &1.id)

  defp sync_selected_ids(socket, ids) when is_list(ids) do
    selected = socket.assigns[:selected_ids] || MapSet.new()
    allowed = MapSet.new(ids)
    assign(socket, :selected_ids, MapSet.intersection(selected, allowed))
  end

  defp parse_metadata(params) do
    case Map.get(params, "metadata") do
      nil ->
        params

      json_str when is_binary(json_str) ->
        case Jason.decode(json_str) do
          {:ok, map} when is_map(map) -> Map.put(params, "metadata", map)
          _ -> Map.delete(params, "metadata")
        end

      _ ->
        params
    end
  end
end
