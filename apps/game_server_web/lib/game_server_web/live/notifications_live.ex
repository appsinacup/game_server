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
                      {translate_notification_title(n)}
                    </td>
                    <td class="text-sm max-w-xs truncate">
                      {translate_notification_content(n)}
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

            <div class="mt-4">
              <.pagination
                page={@notif_page}
                total_pages={@notif_total_pages}
                total_count={@notif_count}
                page_size={@notif_page_size}
                on_prev="prev_page"
                on_next="next_page"
                on_page_size="notif_page_size"
              />
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

  def handle_event("notif_page_size", %{"size" => size}, socket) do
    {:noreply,
     socket
     |> assign(:notif_page_size, String.to_integer(size))
     |> assign(:notif_page, 1)
     |> reload_notifications()}
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
    action_for_type(n.metadata["type"], n) || action_for_metadata(n.metadata)
  end

  defp action_for_type("group_invite", n) do
    group_id = n.metadata["group_id"]

    if group_id,
      do: {gettext("View Group"), ~p"/groups/#{group_id}"},
      else: {gettext("View Groups"), ~p"/groups"}
  end

  defp action_for_type("party_invite", _n), do: {gettext("View Party"), ~p"/play"}
  defp action_for_type("chat_lobby", _n), do: {gettext("Open Play"), ~p"/play"}
  defp action_for_type("chat_party", _n), do: {gettext("View Party"), ~p"/play"}

  defp action_for_type("friend_request", _n),
    do: {gettext("View Friends"), ~p"/users/settings?#{[tab: "friends"]}"}

  defp action_for_type("achievement_unlocked", _n),
    do: {gettext("Achievements"), ~p"/achievements"}

  defp action_for_type("chat_group", n) do
    group_id = n.metadata["group_id"]

    if group_id,
      do: {gettext("Open Chat"), ~p"/chat?#{[type: "group", id: group_id]}"},
      else: {gettext("Open Chat"), ~p"/chat"}
  end

  defp action_for_type("chat_friend", n) do
    friend_id = n.metadata["friend_id"] || n.metadata["sender_id"]

    if friend_id,
      do: {gettext("Open Chat"), ~p"/chat?#{[type: "friend", id: friend_id]}"},
      else: {gettext("Open Chat"), ~p"/chat"}
  end

  defp action_for_type("friend_accepted", n) do
    friend_id = n.metadata["friend_id"] || n.sender_id

    if friend_id,
      do: {gettext("Open Chat"), ~p"/chat?#{[type: "friend", id: friend_id]}"},
      else: {gettext("Open Chat"), ~p"/chat"}
  end

  defp action_for_type(_type, _n), do: nil

  # Fallback: infer action from metadata keys for notifications without a known type
  defp action_for_metadata(%{"leaderboard_slug" => slug}) when is_binary(slug),
    do: {gettext("View Leaderboard"), ~p"/leaderboards/#{slug}"}

  defp action_for_metadata(%{"leaderboard_id" => _}),
    do: {gettext("View Leaderboards"), ~p"/leaderboards"}

  defp action_for_metadata(%{"group_id" => group_id}) when is_integer(group_id),
    do: {gettext("View Group"), ~p"/groups/#{group_id}"}

  defp action_for_metadata(%{"lobby_id" => _}), do: {gettext("Open Play"), ~p"/play"}
  defp action_for_metadata(%{"party_id" => _}), do: {gettext("View Party"), ~p"/play"}
  defp action_for_metadata(_), do: nil

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

  # ---------------------------------------------------------------------------
  # Notification display-time translation
  #
  # Dispatches on metadata["type"] via function heads so each type is a small,
  # simple clause. Falls back to the DB-stored English strings for unknown
  # types or missing metadata.
  # ---------------------------------------------------------------------------

  defp translate_notification_title(n), do: title_for_type(n.metadata["type"], n)

  defp title_for_type("friend_request", _n), do: dgettext("notifications", "New Friend Request")

  defp title_for_type("friend_accepted", _n),
    do: dgettext("notifications", "Friend Request Accepted")

  defp title_for_type("friend_declined", _n),
    do: dgettext("notifications", "Friend Request Declined")

  defp title_for_type("group_invite", _n), do: dgettext("notifications", "New Group Invite")

  defp title_for_type("group_invite_accepted", _n),
    do: dgettext("notifications", "Group Invite Accepted")

  defp title_for_type("group_invite_declined", _n),
    do: dgettext("notifications", "Group Invite Declined")

  defp title_for_type("group_join_request", _n),
    do: dgettext("notifications", "New Group Join Request")

  defp title_for_type("group_join_approved", _n),
    do: dgettext("notifications", "Group Join Request Approved")

  defp title_for_type("group_join_declined", _n),
    do: dgettext("notifications", "Group Join Request Declined")

  defp title_for_type("group_kicked", _n), do: dgettext("notifications", "Removed From Group")
  defp title_for_type("group_promoted", _n), do: dgettext("notifications", "Promoted To Admin")
  defp title_for_type("group_demoted", _n), do: dgettext("notifications", "Demoted From Admin")
  defp title_for_type("party_invite", _n), do: dgettext("notifications", "New Party Invite")

  defp title_for_type("party_invite_accepted", _n),
    do: dgettext("notifications", "Party Invite Accepted")

  defp title_for_type("party_invite_declined", _n),
    do: dgettext("notifications", "Party Invite Declined")

  defp title_for_type("party_kicked", _n), do: dgettext("notifications", "Removed From Party")
  defp title_for_type("lobby_kicked", _n), do: dgettext("notifications", "Removed From Lobby")

  defp title_for_type("chat_friend", _n),
    do: dgettext("notifications", "New messages from friends")

  defp title_for_type("chat_party", _n), do: dgettext("notifications", "New message in party")

  defp title_for_type("achievement_unlocked", n) do
    name = n.metadata["achievement_title"] || ""
    dgettext("notifications", "Achievement Unlocked: %{name}", name: name)
  end

  defp title_for_type("chat_group", n) do
    name = n.metadata["group_name"] || ""
    dgettext("notifications", "New messages from %{name}", name: name)
  end

  defp title_for_type("chat_lobby", n) do
    name = n.metadata["lobby_name"] || ""
    dgettext("notifications", "New messages from %{name}", name: name)
  end

  defp title_for_type(_unknown, n), do: n.title

  # Content translation — dispatches on type, with message_count special case.

  defp translate_notification_content(%{metadata: %{"message_count" => 1}}),
    do: gettext("1 new message")

  defp translate_notification_content(%{metadata: %{"message_count" => count}})
       when is_integer(count),
       do: dgettext("settings", "%{count} new messages", count: count)

  defp translate_notification_content(n), do: content_for_type(n.metadata["type"], n)

  defp content_for_type("friend_request", _n),
    do: dgettext("notifications", "You have a new friend request.")

  defp content_for_type("friend_accepted", _n),
    do: dgettext("notifications", "Your friend request has been accepted.")

  defp content_for_type("friend_declined", _n),
    do: dgettext("notifications", "Your friend request has been declined.")

  defp content_for_type("party_invite", _n),
    do: dgettext("notifications", "You have been invited to join a party")

  defp content_for_type("party_kicked", _n),
    do: dgettext("notifications", "You have been removed from the party")

  defp content_for_type("group_invite", n) do
    name = n.metadata["group_title"] || ""
    dgettext("notifications", "You have been invited to join %{name}", name: name)
  end

  defp content_for_type("group_kicked", n) do
    name = n.metadata["group_title"] || ""
    dgettext("notifications", "You have been removed from %{name}", name: name)
  end

  defp content_for_type("group_promoted", n) do
    name = n.metadata["group_title"] || ""
    dgettext("notifications", "You have been promoted to admin in %{name}", name: name)
  end

  defp content_for_type("group_demoted", n) do
    name = n.metadata["group_title"] || ""
    dgettext("notifications", "You have been demoted to member in %{name}", name: name)
  end

  defp content_for_type("lobby_kicked", n) do
    name = n.metadata["lobby_title"] || ""
    dgettext("notifications", "You have been removed from %{name}", name: name)
  end

  defp content_for_type(_type, n), do: n.content || "-"
end
