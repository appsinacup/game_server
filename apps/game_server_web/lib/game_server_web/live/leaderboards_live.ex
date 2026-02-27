defmodule GameServerWeb.LeaderboardsLive do
  @moduledoc """
  Public-facing leaderboards view.

  Users can browse active and historical leaderboards and see their rank.
  Leaderboards are grouped by slug, showing the active/latest one by default
  with navigation to previous seasons.
  """
  use GameServerWeb, :live_view

  alias GameServer.Leaderboards
  alias GameServer.Leaderboards.Leaderboard

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:locale, Gettext.get_locale(GameServerWeb.Gettext))
      |> assign(:page_title, dgettext("leaderboards", "Leaderboards"))
      |> assign(:page, 1)
      |> assign(:page_size, 25)
      |> assign(:selected_leaderboard, nil)
      |> assign(:slug_leaderboards, [])
      |> assign(:current_season_index, 0)
      |> assign(:records_page, 1)
      |> assign(:user_record, nil)
      |> reload_groups()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug, "id" => id}, _uri, socket) do
    case Leaderboards.get_leaderboard(String.to_integer(id)) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, dgettext("leaderboards", "Leaderboard not found"))
         |> push_navigate(to: ~p"/leaderboards")}

      leaderboard ->
        # Verify slug matches, redirect if not
        cond do
          leaderboard.slug != slug ->
            # Wrong slug, redirect to correct one
            {:noreply, push_navigate(socket, to: leaderboard_path(leaderboard))}

          Leaderboards.Leaderboard.active?(leaderboard) ->
            # Active leaderboard should use slug-only URL
            {:noreply, push_navigate(socket, to: ~p"/leaderboards/#{slug}")}

          true ->
            load_leaderboard(socket, leaderboard)
        end
    end
  end

  def handle_params(%{"slug" => slug}, _uri, socket) do
    # Slug-only URL: load the active leaderboard directly
    case Leaderboards.get_active_leaderboard_by_slug(slug) do
      nil ->
        # No active one, redirect to the latest with ID
        case Leaderboards.list_leaderboards_by_slug(slug) do
          [latest | _] ->
            {:noreply, push_navigate(socket, to: ~p"/leaderboards/#{slug}/#{latest.id}")}

          [] ->
            {:noreply,
             socket
             |> put_flash(:error, dgettext("leaderboards", "Leaderboard not found"))
             |> push_navigate(to: ~p"/leaderboards")}
        end

      leaderboard ->
        # Active leaderboard found, load it directly
        load_leaderboard(socket, leaderboard)
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:selected_leaderboard, nil)
     |> assign(:slug_leaderboards, [])
     |> assign(:current_season_index, 0)
     |> assign(:user_record, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <%= if @selected_leaderboard do %>
          <.render_leaderboard_detail
            leaderboard={@selected_leaderboard}
            slug_leaderboards={@slug_leaderboards}
            current_season_index={@current_season_index}
            records={@records}
            records_page={@records_page}
            records_total_pages={@records_total_pages}
            records_count={@records_count}
            user_record={@user_record}
            current_user_id={@current_scope && @current_scope.user && @current_scope.user.id}
            locale={@locale}
          />
        <% else %>
          <.render_group_list
            groups={@groups}
            page={@page}
            total_pages={@total_pages}
            count={@count}
            locale={@locale}
          />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Render Components
  # ---------------------------------------------------------------------------

  defp render_group_list(assigns) do
    ~H"""
    <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      <.link
        :for={group <- @groups}
        navigate={~p"/leaderboards/#{group.slug}"}
        class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
      >
        <div class="card-body">
          <div class="flex items-start justify-between">
            <h3 class="card-title text-lg">{Leaderboard.localized_title(group, @locale)}</h3>
            <div class="flex flex-col items-end gap-1">
              <%= if group.active_id do %>
                <span class="badge badge-success">{dgettext("leaderboards", "Active")}</span>
              <% else %>
                <span class="badge badge-neutral">{dgettext("leaderboards", "Ended")}</span>
              <% end %>
              <%= if group.season_count > 1 do %>
                <span class="badge badge-ghost badge-sm text-nowrap">
                  {dngettext(
                    "leaderboards",
                    "%{count} season",
                    "%{count} seasons",
                    group.season_count,
                    count: group.season_count
                  )}
                </span>
              <% end %>
            </div>
          </div>

          <% localized_desc = Leaderboard.localized_description(group, @locale) %>
          <%= if localized_desc do %>
            <p class="text-sm text-base-content/70 line-clamp-2">{localized_desc}</p>
          <% end %>
        </div>
      </.link>
    </div>

    <%= if @groups == [] do %>
      <div class="text-center py-12 text-base-content/60">
        <p>{gettext("None available.")}</p>
      </div>
    <% end %>

    <%= if @page > @total_pages do %>
      <div class="mt-6 flex gap-2 items-center justify-center">
        <button phx-click="prev_page" class="btn btn-sm" disabled={@page <= 1}>
          {gettext("Previous")}
        </button>
        <div class="text-sm text-base-content/70">
          {gettext("Page %{page} of %{total}", page: @page, total: @total_pages)}
        </div>
        <button phx-click="next_page" class="btn btn-sm" disabled={@page >= @total_pages}>
          {gettext("Next")}
        </button>
      </div>
    <% end %>
    """
  end

  defp render_leaderboard_detail(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 mb-6">
      <%!-- Back button and title --%>
      <div class="flex items-center gap-4">
        <.link navigate={~p"/leaderboards"} class="btn btn-outline btn-sm">
          {gettext("Back")}
        </.link>
        <div>
          <h1 class="text-2xl font-bold">{Leaderboard.localized_title(@leaderboard, @locale)}</h1>
          <div class="flex items-center gap-2 mt-1">
            <%= if Leaderboard.active?(@leaderboard) do %>
              <span class="badge badge-success">{dgettext("leaderboards", "Active")}</span>
            <% else %>
              <span class="badge badge-neutral">{dgettext("leaderboards", "Ended")}</span>
            <% end %>
            <span class="text-sm text-base-content/60">
              <%= cond do %>
                <% @leaderboard.ends_at && Leaderboard.ended?(@leaderboard) -> %>
                  {dgettext("leaderboards", "Ended %{date}",
                    date: Calendar.strftime(@leaderboard.ends_at, "%b %d, %Y")
                  )}
                <% @leaderboard.ends_at -> %>
                  {dgettext("leaderboards", "Ends %{date}",
                    date: Calendar.strftime(@leaderboard.ends_at, "%b %d, %Y")
                  )}
                <% true -> %>
                  {dgettext("leaderboards", "Permanent")}
              <% end %>
            </span>
          </div>
        </div>
      </div>

      <%!-- Season navigation --%>
      <%= if length(@slug_leaderboards) > 1 do %>
        <div class="flex items-center gap-3 bg-base-200 rounded-lg px-4 py-2 w-fit">
          <button
            phx-click="prev_season"
            class="btn btn-sm btn-ghost"
            disabled={@current_season_index >= length(@slug_leaderboards) - 1}
          >
            {dgettext("leaderboards", "Older")}
          </button>
          <div class="text-sm">
            <span class="font-medium">
              {dgettext("leaderboards", "Season %{number}",
                number: length(@slug_leaderboards) - @current_season_index
              )}
            </span>
            <span class="text-base-content/60">
              {dgettext("leaderboards", "of %{total}", total: length(@slug_leaderboards))}
            </span>
          </div>
          <button
            phx-click="next_season"
            class="btn btn-sm btn-ghost"
            disabled={@current_season_index <= 0}
          >
            {dgettext("leaderboards", "Newer")}
          </button>
        </div>
      <% end %>
    </div>

    <% localized_desc = Leaderboard.localized_description(@leaderboard, @locale) %>
    <%= if localized_desc do %>
      <p class="text-base-content/70 mb-6">{localized_desc}</p>
    <% end %>

    <%= if @user_record do %>
      <div class="card bg-primary/10 border border-primary/30 mb-6">
        <div class="card-body py-4">
          <div class="flex items-center justify-between">
            <div>
              <span class="text-sm text-base-content/70">
                {dgettext("leaderboards", "Your Rank")}
              </span>
              <div class="text-2xl font-bold">#{@user_record.rank}</div>
            </div>
            <div class="text-right">
              <span class="text-sm text-base-content/70">
                {dgettext("leaderboards", "Your Score")}
              </span>
              <div class="text-2xl font-bold">{format_score(@user_record.score)}</div>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <div class="card bg-base-200">
      <div class="card-body">
        <h2 class="card-title">{dgettext("leaderboards", "Rankings")}</h2>

        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th class="w-16">{dgettext("leaderboards", "Rank")}</th>
                <th>{dgettext("leaderboards", "Player")}</th>
                <th class="text-right">{dgettext("leaderboards", "Score")}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={record <- @records}
                class={[
                  record.user_id == @current_user_id && "bg-primary/10"
                ]}
              >
                <td class="font-mono">
                  <span class={[
                    "inline-flex items-center justify-center w-8 h-8 rounded-full",
                    record.rank == 1 && "bg-yellow-500/20 text-yellow-600",
                    record.rank == 2 && "bg-gray-400/20 text-gray-600",
                    record.rank == 3 && "bg-orange-500/20 text-orange-600"
                  ]}>
                    {record.rank}
                  </span>
                </td>
                <td>
                  <div class="flex items-center gap-2">
                    <span class={[
                      record.user_id == @current_user_id && "font-bold"
                    ]}>
                      {(record.user && record.user.display_name) || "User #{record.user_id}"}
                    </span>
                    <%= if record.user_id == @current_user_id do %>
                      <span class="badge badge-primary badge-sm">{gettext("You")}</span>
                    <% end %>
                  </div>
                </td>
                <td class="text-right font-mono">
                  {format_score(record.score)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%= if @records == [] do %>
          <div class="text-center py-8 text-base-content/60">
            <p>{gettext("None available.")}</p>
          </div>
        <% end %>

        <%= if @records_page > @records_total_pages do %>
          <div class="mt-4 flex gap-2 items-center justify-center">
            <button phx-click="records_prev" class="btn btn-sm" disabled={@records_page <= 1}>
              {gettext("Previous")}
            </button>
            <div class="text-sm text-base-content/70">
              {gettext("Page %{page} of %{total} (%{count} total)",
                page: @records_page,
                total: @records_total_pages,
                count: @records_count
              )}
            </div>
            <button
              phx-click="records_next"
              class="btn btn-sm"
              disabled={@records_page >= @records_total_pages}
            >
              {gettext("Next")}
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Event Handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("prev_page", _, socket) do
    {:noreply,
     socket
     |> assign(:page, max(1, socket.assigns.page - 1))
     |> reload_groups()}
  end

  def handle_event("next_page", _, socket) do
    {:noreply,
     socket
     |> assign(:page, socket.assigns.page + 1)
     |> reload_groups()}
  end

  def handle_event("prev_season", _, socket) do
    # Go to older season (higher index)
    slug_lbs = socket.assigns.slug_leaderboards
    new_index = min(socket.assigns.current_season_index + 1, length(slug_lbs) - 1)
    leaderboard = Enum.at(slug_lbs, new_index)

    {:noreply, push_patch(socket, to: leaderboard_path(leaderboard))}
  end

  def handle_event("next_season", _, socket) do
    # Go to newer season (lower index)
    slug_lbs = socket.assigns.slug_leaderboards
    new_index = max(socket.assigns.current_season_index - 1, 0)
    leaderboard = Enum.at(slug_lbs, new_index)

    {:noreply, push_patch(socket, to: leaderboard_path(leaderboard))}
  end

  def handle_event("records_prev", _, socket) do
    {:noreply,
     socket
     |> assign(:records_page, max(1, socket.assigns.records_page - 1))
     |> reload_records()}
  end

  def handle_event("records_next", _, socket) do
    {:noreply,
     socket
     |> assign(:records_page, socket.assigns.records_page + 1)
     |> reload_records()}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp reload_groups(socket) do
    page = socket.assigns[:page] || 1
    page_size = socket.assigns[:page_size] || 25

    groups = Leaderboards.list_leaderboard_groups(page: page, page_size: page_size)
    count = Leaderboards.count_leaderboard_groups()
    total_pages = max(1, div(count + page_size - 1, page_size))

    socket
    |> assign(:groups, groups)
    |> assign(:count, count)
    |> assign(:total_pages, total_pages)
  end

  defp reload_records(socket) do
    lb = socket.assigns.selected_leaderboard
    page = socket.assigns[:records_page] || 1
    page_size = 25

    records = Leaderboards.list_records(lb.id, page: page, page_size: page_size)
    count = Leaderboards.count_records(lb.id)
    total_pages = max(1, div(count + page_size - 1, page_size))

    socket
    |> assign(:records, records)
    |> assign(:records_count, count)
    |> assign(:records_total_pages, total_pages)
  end

  defp get_user_record(socket, leaderboard_id) do
    case socket.assigns[:current_scope] do
      %{user: %{id: user_id}} when is_integer(user_id) ->
        case Leaderboards.get_user_record(leaderboard_id, user_id) do
          {:ok, record} -> record
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp load_leaderboard(socket, leaderboard) do
    # Load all leaderboards with same slug for season navigation
    slug_leaderboards = Leaderboards.list_leaderboards_by_slug(leaderboard.slug)
    current_index = Enum.find_index(slug_leaderboards, &(&1.id == leaderboard.id)) || 0
    user_record = get_user_record(socket, leaderboard.id)

    {:noreply,
     socket
     |> assign(:selected_leaderboard, leaderboard)
     |> assign(:slug_leaderboards, slug_leaderboards)
     |> assign(:current_season_index, current_index)
     |> assign(:user_record, user_record)
     |> assign(:records_page, 1)
     |> reload_records()}
  end

  # Returns the appropriate URL for a leaderboard:
  # - Active leaderboards use slug-only: /leaderboards/weekly_kills
  # - Historical leaderboards use slug/id: /leaderboards/weekly_kills/123
  defp leaderboard_path(leaderboard) do
    if Leaderboard.active?(leaderboard) do
      ~p"/leaderboards/#{leaderboard.slug}"
    else
      ~p"/leaderboards/#{leaderboard.slug}/#{leaderboard.id}"
    end
  end

  defp format_score(score) when is_integer(score) do
    score
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0,")
    |> String.reverse()
  end

  defp format_score(score), do: to_string(score)
end
