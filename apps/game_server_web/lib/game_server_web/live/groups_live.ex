defmodule GameServerWeb.GroupsLive do
  use GameServerWeb, :live_view

  alias GameServer.Groups

  @page_size 12

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Groups.subscribe_groups()

    user =
      case socket.assigns do
        %{current_scope: %{user: u}} when u != nil -> u
        _ -> nil
      end

    # Build a set of group IDs the user has pending requests for
    pending_request_ids =
      if user do
        user.id
        |> Groups.list_user_pending_requests()
        |> MapSet.new(& &1.group_id)
      else
        MapSet.new()
      end

    # Build a set of group IDs the user is a member of
    member_group_ids =
      if user do
        user.id
        |> Groups.list_user_groups([])
        |> MapSet.new(& &1.id)
      else
        MapSet.new()
      end

    {:ok,
     assign(socket,
       page_title: dgettext("groups", "Groups"),
       search: "",
       type_filter: "all",
       sort_by: "updated_at",
       page: 1,
       page_size: @page_size,
       groups: [],
       total_count: 0,
       total_pages: 0,
       pending_request_ids: pending_request_ids,
       member_group_ids: member_group_ids,
       selected_group: nil,
       selected_members: [],
       members_page: 1,
       members_total: 0,
       members_total_pages: 0
     )
     |> load_groups()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case socket.assigns.live_action do
      :show ->
        group_id = String.to_integer(params["id"])

        case Groups.get_group(group_id) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:error, dgettext("groups", "Group not found"))
             |> push_navigate(to: ~p"/groups")}

          group ->
            members = Groups.get_group_members_paginated(group.id, page: 1, page_size: @page_size)
            members_total = Groups.count_group_members(group.id)

            members_total_pages =
              if @page_size > 0, do: div(members_total + @page_size - 1, @page_size), else: 0

            Groups.subscribe_group(group.id)

            {:noreply,
             assign(socket,
               page_title: group.title,
               selected_group: group,
               selected_members: members,
               members_page: 1,
               members_total: members_total,
               members_total_pages: members_total_pages
             )}
        end

      _ ->
        {:noreply, assign(socket, selected_group: nil, page_title: dgettext("groups", "Groups"))}
    end
  end

  # ── Events ──────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {:noreply,
     socket
     |> assign(search: term, page: 1)
     |> load_groups()}
  end

  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(type_filter: type, page: 1)
     |> load_groups()}
  end

  def handle_event("sort_by", %{"sort" => sort}, socket) do
    {:noreply,
     socket
     |> assign(sort_by: sort, page: 1)
     |> load_groups()}
  end

  def handle_event("prev_page", _params, socket) do
    page = max(1, socket.assigns.page - 1)

    {:noreply,
     socket
     |> assign(page: page)
     |> load_groups()}
  end

  def handle_event("next_page", _params, socket) do
    page = socket.assigns.page + 1

    {:noreply,
     socket
     |> assign(page: page)
     |> load_groups()}
  end

  def handle_event("view_group", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/groups/#{id}")}
  end

  def handle_event("back_to_list", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/groups")}
  end

  def handle_event("join_group", %{"id" => id}, socket) do
    group_id = String.to_integer(id)

    case socket.assigns.current_scope do
      %{user: user} when user != nil ->
        case Groups.join_group(user.id, group_id) do
          {:ok, _member} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "You have joined the group"))
             |> update(:member_group_ids, &MapSet.put(&1, group_id))
             |> maybe_refresh_selected(group_id)}

          {:error, :already_member} ->
            {:noreply, put_flash(socket, :info, dgettext("groups", "You are already a member"))}

          {:error, :not_public} ->
            {:noreply, put_flash(socket, :error, dgettext("groups", "This group is not public"))}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not join: %{reason}", reason: inspect(reason))
             )}
        end

      _ ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("request_join", %{"id" => id}, socket) do
    group_id = String.to_integer(id)

    case socket.assigns.current_scope do
      %{user: user} when user != nil ->
        case Groups.request_join(user.id, group_id) do
          {:ok, _request} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Join request sent"))
             |> update(:pending_request_ids, &MapSet.put(&1, group_id))}

          {:error, :already_member} ->
            {:noreply, put_flash(socket, :info, dgettext("groups", "You are already a member"))}

          {:error, :already_requested} ->
            {:noreply,
             put_flash(socket, :info, dgettext("groups", "You already have a pending request"))}

          {:error, :not_private} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "This group does not accept join requests")
             )}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not request: %{reason}", reason: inspect(reason))
             )}
        end

      _ ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("leave_group", %{"id" => id}, socket) do
    group_id = String.to_integer(id)

    case socket.assigns.current_scope do
      %{user: user} when user != nil ->
        case Groups.leave_group(user.id, group_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "You have left the group"))
             |> update(:member_group_ids, &MapSet.delete(&1, group_id))
             |> maybe_refresh_selected(group_id)}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not leave: %{reason}", reason: inspect(reason))
             )}
        end

      _ ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("members_prev", _params, socket) do
    page = max(1, socket.assigns.members_page - 1)
    {:noreply, load_members(assign(socket, members_page: page))}
  end

  def handle_event("members_next", _params, socket) do
    page = socket.assigns.members_page + 1
    {:noreply, load_members(assign(socket, members_page: page))}
  end

  # ── PubSub handlers ────────────────────────────────────────────────────────

  @impl true
  def handle_info({:group_created, _group}, socket) do
    {:noreply, load_groups(socket)}
  end

  def handle_info({:group_updated, _group}, socket) do
    {:noreply, load_groups(socket)}
  end

  def handle_info({:group_deleted, _group_id}, socket) do
    {:noreply,
     socket
     |> assign(selected_group: nil)
     |> load_groups()}
  end

  def handle_info({:member_joined, group_id, _user_id}, socket) do
    {:noreply,
     socket
     |> load_groups()
     |> maybe_refresh_selected(group_id)}
  end

  def handle_info({:member_left, group_id, _user_id}, socket) do
    {:noreply,
     socket
     |> load_groups()
     |> maybe_refresh_selected(group_id)}
  end

  def handle_info({:join_request_created, _group_id, _user_id}, socket) do
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp build_filters(socket) do
    filters = %{}

    filters =
      if socket.assigns.search != "" do
        Map.put(filters, :title, socket.assigns.search)
      else
        filters
      end

    if socket.assigns.type_filter != "all" do
      Map.put(filters, :type, socket.assigns.type_filter)
    else
      filters
    end
  end

  defp load_groups(socket) do
    filters = build_filters(socket)

    groups =
      Groups.list_groups(filters,
        page: socket.assigns.page,
        page_size: socket.assigns.page_size,
        sort_by: socket.assigns.sort_by
      )

    total_count = Groups.count_list_groups(filters)

    total_pages =
      if socket.assigns.page_size > 0,
        do: div(total_count + socket.assigns.page_size - 1, socket.assigns.page_size),
        else: 0

    # Build a map of member counts per group
    member_counts = Enum.into(groups, %{}, fn g -> {g.id, Groups.count_group_members(g.id)} end)

    assign(socket,
      groups: groups,
      total_count: total_count,
      total_pages: total_pages,
      member_counts: member_counts
    )
  end

  defp load_members(socket) do
    case socket.assigns.selected_group do
      nil ->
        socket

      group ->
        members =
          Groups.get_group_members_paginated(group.id,
            page: socket.assigns.members_page,
            page_size: @page_size
          )

        members_total = Groups.count_group_members(group.id)

        members_total_pages =
          if @page_size > 0, do: div(members_total + @page_size - 1, @page_size), else: 0

        assign(socket,
          selected_members: members,
          members_total: members_total,
          members_total_pages: members_total_pages
        )
    end
  end

  defp maybe_refresh_selected(socket, group_id) do
    case socket.assigns.selected_group do
      %{id: ^group_id} -> load_members(socket)
      _ -> socket
    end
  end

  # ── Render ──────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <%= if @selected_group do %>
          {render_group_detail(assigns)}
        <% else %>
          {render_group_list(assigns)}
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_group_list(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row gap-4 items-start sm:items-center">
      <form phx-change="search" phx-submit="search" class="flex-1 w-full" id="groups-search-form">
        <.input
          name="search"
          value={@search}
          placeholder={gettext("Search...")}
          phx-debounce="300"
          type="text"
        />
      </form>

      <div class="flex gap-2" id="groups-type-filter">
        <button
          :for={
            {label, value} <- [
              {gettext("All"), "all"},
              {gettext("Public"), "public"},
              {gettext("Private"), "private"}
            ]
          }
          phx-click="filter_type"
          phx-value-type={value}
          class={[
            "btn btn-sm",
            if(@type_filter == value, do: "btn-primary", else: "btn-ghost")
          ]}
        >
          {label}
        </button>
      </div>
    </div>

    <div class="flex gap-2 items-center" id="groups-sort">
      <span class="text-sm text-base-content/60">{gettext("Sort by:")}</span>
      <button
        :for={
          {label, value} <- [
            {gettext("Recent Activity"), "updated_at"},
            {gettext("Newest"), "inserted_at"},
            {gettext("Name"), "title"},
            {gettext("Members"), "max_members"}
          ]
        }
        phx-click="sort_by"
        phx-value-sort={value}
        class={[
          "btn btn-xs",
          if(@sort_by == value, do: "btn-primary", else: "btn-ghost")
        ]}
      >
        {label}
      </button>
    </div>

    <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3" id="groups-list">
      <div
        :for={group <- @groups}
        id={"group-#{group.id}"}
        class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
        phx-click="view_group"
        phx-value-id={group.id}
      >
        <div class="card-body">
          <div class="flex items-start justify-between">
            <h3 class="card-title text-lg">{group.title}</h3>
            <div class="flex flex-col items-end gap-1">
              <%= if group.type == "public" do %>
                <span class="badge badge-success">{gettext("Public")}</span>
              <% else %>
                <span class="badge badge-warning">{gettext("Private")}</span>
              <% end %>
              {render_group_action_button(
                assigns
                |> Map.put(:group, group)
              )}
            </div>
          </div>

          <%= if group.description && group.description != "" do %>
            <p class="text-sm text-base-content/70 line-clamp-2">{group.description}</p>
          <% end %>

          <div class="flex items-center gap-2 mt-1">
            <span class="badge badge-ghost badge-sm text-nowrap">
              {@member_counts[group.id] || 0} / {group.max_members} {dgettext("groups", "members")}
            </span>
          </div>
        </div>
      </div>
    </div>

    <%= if @groups == [] do %>
      <div class="text-center py-12 text-base-content/60" id="groups-empty">
        <p>{dgettext("groups", "No groups found")}</p>
      </div>
    <% end %>

    <div class="mt-6 flex gap-2 items-center justify-center">
      <button phx-click="prev_page" class="btn btn-sm" disabled={@page <= 1}>
        ← {gettext("Previous")}
      </button>
      <div class="text-sm text-base-content/70">
        {gettext("Page %{page} of %{total} (%{count} total)",
          page: @page,
          total: max(@total_pages, 1),
          count: @total_count
        )}
      </div>
      <button
        phx-click="next_page"
        class="btn btn-sm"
        disabled={@page >= @total_pages || @total_pages == 0}
      >
        {gettext("Next")} →
      </button>
    </div>
    """
  end

  defp render_group_action_button(assigns) do
    ~H"""
    <%= if @current_scope && @current_scope.user do %>
      <%= cond do %>
        <% MapSet.member?(@member_group_ids, @group.id) -> %>
          <span class="badge badge-success badge-sm">{gettext("Member")}</span>
        <% MapSet.member?(@pending_request_ids, @group.id) -> %>
          <span class="badge badge-warning badge-sm">{dgettext("groups", "Pending")}</span>
        <% @group.type == "public" -> %>
          <button
            phx-click="join_group"
            phx-value-id={@group.id}
            class="btn btn-primary btn-xs"
          >
            {gettext("Join")}
          </button>
        <% @group.type == "private" -> %>
          <button
            phx-click="request_join"
            phx-value-id={@group.id}
            class="btn btn-outline btn-xs"
          >
            {gettext("Request")}
          </button>
        <% true -> %>
      <% end %>
    <% else %>
      <.link navigate={~p"/users/log-in"} class="btn btn-ghost btn-xs">
        {gettext("Log in")}
      </.link>
    <% end %>
    """
  end

  defp render_group_detail(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 mb-6">
      <div class="flex items-center gap-4">
        <button phx-click="back_to_list" class="btn btn-outline btn-sm" id="groups-back-btn">
          ← {gettext("Back")}
        </button>
        <div>
          <h1 class="text-2xl font-bold">{@selected_group.title}</h1>
          <div class="flex items-center gap-2 mt-1">
            <%= if @selected_group.type == "public" do %>
              <span class="badge badge-success">{gettext("Public")}</span>
            <% else %>
              <span class="badge badge-warning">{gettext("Private")}</span>
            <% end %>
            <span class="text-sm text-base-content/60">
              {dgettext("groups", "Created %{date}",
                date: Calendar.strftime(@selected_group.inserted_at, "%b %d, %Y")
              )}
            </span>
          </div>
        </div>
      </div>
    </div>

    <%= if @selected_group.description && @selected_group.description != "" do %>
      <p class="text-base-content/70 mb-6">{@selected_group.description}</p>
    <% end %>

    <%!-- Action card --%>
    <div class="card bg-base-200 mb-6">
      <div class="card-body py-4">
        <div class="flex items-center justify-between">
          <div>
            <span class="text-sm text-base-content/70">{gettext("Members")}</span>
            <div class="text-2xl font-bold">{@members_total} / {@selected_group.max_members}</div>
          </div>
          <div>
            {render_detail_action_button(assigns)}
          </div>
        </div>
      </div>
    </div>

    <%!-- Members table --%>
    <div class="card bg-base-200">
      <div class="card-body">
        <h2 class="card-title">{gettext("Members")}</h2>

        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>{dgettext("groups", "Player")}</th>
                <th class="text-right">{dgettext("groups", "Role")}</th>
              </tr>
            </thead>
            <tbody id="group-members-list">
              <tr
                :for={member <- @selected_members}
                id={"member-#{member.id}"}
              >
                <td>
                  <div class="flex items-center gap-2">
                    <div class="w-8 h-8 rounded-full bg-base-300 flex items-center justify-center text-sm font-semibold">
                      {String.first(member.user.display_name || member.user.email || "?")
                      |> String.upcase()}
                    </div>
                    <span>
                      {member.user.display_name || member.user.email ||
                        dgettext("groups", "user-%{id}", id: member.user.id)}
                    </span>
                  </div>
                </td>
                <td class="text-right">
                  <%= if member.role == "admin" do %>
                    <span class="badge badge-primary badge-sm">{gettext("Admin")}</span>
                  <% else %>
                    <span class="badge badge-ghost badge-sm">{gettext("Member")}</span>
                  <% end %>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%= if @selected_members == [] do %>
          <div class="text-center py-8 text-base-content/60">
            <p>{dgettext("groups", "No members yet")}</p>
          </div>
        <% end %>

        <div class="mt-4 flex gap-2 items-center justify-center">
          <button phx-click="members_prev" class="btn btn-sm" disabled={@members_page <= 1}>
            ← {gettext("Previous")}
          </button>
          <div class="text-sm text-base-content/70">
            {gettext("Page %{page} of %{total} (%{count} total)",
              page: @members_page,
              total: max(@members_total_pages, 1),
              count: @members_total
            )}
          </div>
          <button
            phx-click="members_next"
            class="btn btn-sm"
            disabled={@members_page >= @members_total_pages || @members_total_pages == 0}
          >
            {gettext("Next")} →
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp render_detail_action_button(assigns) do
    ~H"""
    <%= if @current_scope && @current_scope.user do %>
      <%= cond do %>
        <% MapSet.member?(@member_group_ids, @selected_group.id) -> %>
          <button
            phx-click="leave_group"
            phx-value-id={@selected_group.id}
            class="btn btn-outline btn-error btn-sm"
            id="group-leave-btn"
          >
            {dgettext("groups", "Leave Group")}
          </button>
        <% MapSet.member?(@pending_request_ids, @selected_group.id) -> %>
          <span class="badge badge-warning">{dgettext("groups", "Request Pending")}</span>
        <% @selected_group.type == "public" -> %>
          <button
            phx-click="join_group"
            phx-value-id={@selected_group.id}
            class="btn btn-primary btn-sm"
            id="group-join-btn"
          >
            {dgettext("groups", "Join Group")}
          </button>
        <% @selected_group.type == "private" -> %>
          <button
            phx-click="request_join"
            phx-value-id={@selected_group.id}
            class="btn btn-outline btn-sm"
            id="group-request-btn"
          >
            {dgettext("groups", "Request to Join")}
          </button>
        <% true -> %>
      <% end %>
    <% else %>
      <.link navigate={~p"/users/log-in"} class="btn btn-outline btn-sm">
        {dgettext("groups", "Log in to join")}
      </.link>
    <% end %>
    """
  end
end
