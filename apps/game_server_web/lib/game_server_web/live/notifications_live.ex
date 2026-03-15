defmodule GameServerWeb.NotificationsLive do
  use GameServerWeb, :live_view

  alias GameServer.Notifications

  @page_size 25

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold">{dgettext("settings", "Notifications")}</h1>
            <p class="text-base-content/60 mt-1">
              {dgettext("settings", "%{count} notifications, %{unread} unread",
                count: @notif_count,
                unread: @notif_unread_count
              )}
            </p>
          </div>
          <div class="flex gap-2">
            <%= if @notif_count > 0 do %>
              <button
                type="button"
                phx-click="delete_all"
                data-confirm={dgettext("settings", "Delete all notifications?")}
                class="btn btn-sm btn-outline btn-error"
              >
                {dgettext("settings", "Delete All")}
              </button>
            <% end %>
          </div>
        </div>

        <%= if @notif_count > 0 do %>
          <div class="card bg-base-200 p-4 rounded-lg">
            <div class="overflow-x-auto">
              <table id="notifications-table" class="table table-zebra w-full">
                <thead>
                  <tr>
                    <th>{gettext("Title")}</th>
                    <th>{gettext("Content")}</th>
                    <th>{gettext("From")}</th>
                    <th>{gettext("Date")}</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    :for={n <- @notifications}
                    id={"notif-" <> to_string(n.id)}
                  >
                    <td class="text-sm">
                      {n.title}
                    </td>
                    <td class="text-sm max-w-xs truncate">
                      <%= cond do %>
                        <% msg_count = n.metadata["message_count"] -> %>
                          <%= if msg_count == 1 do %>
                            {gettext("1 new message")}
                          <% else %>
                            {dgettext("settings", "%{count} new messages", count: msg_count)}
                          <% end %>
                        <% true -> %>
                          {n.content || "-"}
                      <% end %>
                    </td>
                    <td class="text-sm">
                      <%= cond do %>
                        <% n.metadata["chat_type"] != nil -> %>
                          <span class="badge badge-sm badge-outline badge-info">
                            {gettext("Chat")}
                          </span>
                        <% Ecto.assoc_loaded?(n.sender) && n.sender -> %>
                          {n.sender.display_name || n.sender.email}
                        <% true -> %>
                          {"User #{n.sender_id}"}
                      <% end %>
                    </td>
                    <td class="text-sm whitespace-nowrap">
                      {Calendar.strftime(n.inserted_at, "%Y-%m-%d %H:%M")}
                    </td>
                    <td class="flex gap-1 flex-wrap">
                      <%= if action = notification_action(n) do %>
                        <% {label, path} = action %>
                        <.link navigate={path} class="btn btn-xs btn-outline btn-primary">
                          {label}
                        </.link>
                      <% end %>
                      <button
                        type="button"
                        phx-click="delete"
                        phx-value-id={n.id}
                        class="btn btn-xs btn-outline btn-error"
                      >
                        {gettext("Delete")}
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div :if={@notif_total_pages > 1} class="mt-4 flex gap-2 items-center">
              <button phx-click="prev_page" class="btn btn-xs" disabled={@notif_page <= 1}>
                {gettext("Prev")}
              </button>
              <div class="text-xs text-base-content/70">
                page {@notif_page} / {@notif_total_pages} ({@notif_count} total)
              </div>
              <button
                phx-click="next_page"
                class="btn btn-xs"
                disabled={@notif_page >= @notif_total_pages || @notif_total_pages == 0}
              >
                {gettext("Next")}
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if connected?(socket) do
      Notifications.subscribe(user.id)
      # Auto-mark all notifications as read when the user opens the page
      Notifications.mark_all_notifications_read(user.id)
    end

    socket =
      socket
      |> assign(:page_title, gettext("Notifications"))
      |> assign(:notif_page, 1)
      |> assign(:notif_page_size, @page_size)
      |> assign(:notifications, [])
      |> assign(:notif_count, 0)
      |> assign(:notif_unread_count, 0)
      |> assign(:notif_total_pages, 0)
      |> reload_notifications()

    {:ok, socket}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    page = max(1, socket.assigns.notif_page - 1)
    {:noreply, socket |> assign(:notif_page, page) |> reload_notifications()}
  end

  def handle_event("next_page", _params, socket) do
    page = socket.assigns.notif_page + 1
    {:noreply, socket |> assign(:notif_page, page) |> reload_notifications()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    notif_id = if is_binary(id), do: String.to_integer(id), else: id
    Notifications.delete_notifications(user.id, [notif_id])

    {:noreply,
     socket
     |> put_flash(:info, dgettext("settings", "Notification deleted"))
     |> reload_notifications()}
  end

  def handle_event("delete_all", _params, socket) do
    user = socket.assigns.current_scope.user

    all_ids =
      Notifications.list_notifications(user.id, page: 1, page_size: 10_000)
      |> Enum.map(& &1.id)

    Notifications.delete_notifications(user.id, all_ids)

    {:noreply,
     socket
     |> put_flash(:info, dgettext("settings", "All notifications deleted"))
     |> assign(:notif_page, 1)
     |> reload_notifications()}
  end

  @impl true
  def handle_info({:new_notification, _notification}, socket) do
    user = socket.assigns.current_scope.user
    # Auto-mark new notifications as read since the user is viewing the page
    Notifications.mark_all_notifications_read(user.id)
    {:noreply, reload_notifications(socket)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp notification_action(n) do
    cond do
      # Group invites
      n.title == "New Group Invite" ->
        group_id = n.metadata["group_id"]

        if group_id,
          do: {gettext("View Group"), ~p"/groups/#{group_id}"},
          else: {gettext("View Groups"), ~p"/groups"}

      # Party invites
      n.title == "New Party Invite" ->
        {gettext("View Party"), ~p"/play"}

      # Chat: group messages
      n.metadata["chat_type"] == "group" ->
        group_id = n.metadata["group_id"]

        if group_id,
          do: {gettext("Open Chat"), ~p"/chat?#{[type: "group", id: group_id]}"},
          else: {gettext("Open Chat"), ~p"/chat"}

      # Chat: friend messages
      n.metadata["chat_type"] == "friend" ->
        friend_id = n.metadata["friend_id"] || n.metadata["sender_id"]

        if friend_id,
          do: {gettext("Open Chat"), ~p"/chat?#{[type: "friend", id: friend_id]}"},
          else: {gettext("Open Chat"), ~p"/chat"}

      # Chat: lobby messages
      n.metadata["chat_type"] == "lobby" ->
        {gettext("Open Chat"), ~p"/lobbies"}

      # Chat: party messages
      n.metadata["chat_type"] == "party" ->
        {gettext("View Party"), ~p"/play"}

      # Friend requests
      n.title == "New Friend Request" ->
        {gettext("View Friends"), ~p"/users/settings?#{[tab: "friends"]}"}

      # Friend request accepted
      n.title == "Friend Request Accepted" ->
        friend_id = n.metadata["friend_id"] || n.sender_id

        if friend_id,
          do: {gettext("Open Chat"), ~p"/chat?#{[type: "friend", id: friend_id]}"},
          else: {gettext("Open Chat"), ~p"/chat"}

      # Game invites
      n.title == "Game invite" ->
        {gettext("View Lobbies"), ~p"/lobbies"}

      # Leaderboard notifications (via metadata)
      n.metadata["leaderboard_slug"] != nil ->
        slug = n.metadata["leaderboard_slug"]
        {gettext("View Leaderboard"), ~p"/leaderboards/#{slug}"}

      n.metadata["leaderboard_id"] != nil ->
        {gettext("View Leaderboards"), ~p"/leaderboards"}

      # Group notifications (group_id in metadata)
      n.metadata["group_id"] != nil ->
        group_id = n.metadata["group_id"]
        {gettext("View Group"), ~p"/groups/#{group_id}"}

      # Lobby notifications (lobby_id in metadata)
      n.metadata["lobby_id"] != nil ->
        {gettext("View Lobbies"), ~p"/lobbies"}

      # Party notifications (party_id in metadata)
      n.metadata["party_id"] != nil ->
        {gettext("View Party"), ~p"/play"}

      true ->
        nil
    end
  end

  defp reload_notifications(socket) do
    user = socket.assigns.current_scope.user
    page = socket.assigns.notif_page
    page_size = socket.assigns.notif_page_size

    notifications = Notifications.list_notifications(user.id, page: page, page_size: page_size)
    count = Notifications.count_notifications(user.id)
    unread_count = Notifications.count_unread_notifications(user.id)
    total_pages = if page_size > 0, do: div(count + page_size - 1, page_size), else: 0

    socket
    |> assign(:notifications, notifications)
    |> assign(:notif_count, count)
    |> assign(:notif_unread_count, unread_count)
    |> assign(:notif_total_pages, total_pages)
  end
end
