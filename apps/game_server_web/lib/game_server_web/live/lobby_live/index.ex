defmodule GameServerWeb.LobbyLive.Index do
  use GameServerWeb, :live_view

  alias GameServer.Accounts
  alias GameServer.Lobbies

  @impl true
  def mount(_params, _session, socket) do
    # Get current user from scope if available
    user =
      case socket.assigns do
        %{current_scope: %{user: u}} when u != nil -> u
        _ -> nil
      end

    # Subscribe to global lobby events
    if connected?(socket) do
      Lobbies.subscribe_lobbies()

      # If user is in a lobby, subscribe to that lobby's events
      if user && user.lobby_id do
        Lobbies.subscribe_lobby(user.lobby_id)
      end
    end

    # default pagination values for the lobbies listing
    lobbies_page = 1
    lobbies_page_size = 12

    lobbies =
      Lobbies.list_lobbies_for_user(user, %{}, page: lobbies_page, page_size: lobbies_page_size)

    total_count = Lobbies.count_list_lobbies(%{})

    total_pages =
      if lobbies_page_size > 0,
        do: div(total_count + lobbies_page_size - 1, lobbies_page_size),
        else: 0

    memberships_map =
      Enum.into(lobbies, %{}, fn l -> {l.id, Lobbies.list_memberships_for_lobby(l.id)} end)

    {:ok,
     assign(socket,
       lobbies: lobbies,
       memberships_map: memberships_map,
       lobbies_page: lobbies_page,
       lobbies_page_size: lobbies_page_size,
       lobbies_total: total_count,
       lobbies_total_pages: total_pages,
       title: "",
       joining_lobby_id: nil,
       join_password: "",
       editing_lobby_id: nil,
       edit_attrs: %{},
       editing_can_edit: false,
       subscribed_lobby_id: user && user.lobby_id
     )}
  end

  @impl true
  def handle_event("create", %{"title" => title}, socket) do
    attrs = %{"title" => title}

    case socket.assigns.current_scope do
      %{user: %{id: id}} when id != nil ->
        attrs = Map.put(attrs, "host_id", id)

        # prevent creating more than one lobby for the same user
        case Accounts.get_user(id) do
          %GameServer.Accounts.User{lobby_id: existing} when existing != nil ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("lobbies", "You are already in a lobby and cannot create another")
             )}

          _ ->
            create_lobby_for_user(socket, attrs, id)
        end

      _ ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("leave", _params, socket) do
    case socket.assigns.current_scope do
      %{user: user} when user != nil ->
        case Lobbies.leave_lobby(user) do
          {:ok, _} ->
            # refresh user to update lobby_id first
            refreshed_user = GameServer.Accounts.get_user!(user.id)

            lobbies =
              Lobbies.list_lobbies_for_user(refreshed_user, %{},
                page: socket.assigns[:lobbies_page] || 1,
                page_size: socket.assigns[:lobbies_page_size] || 12
              )

            memberships_map =
              Enum.into(lobbies, %{}, fn l -> {l.id, Lobbies.list_memberships_for_lobby(l.id)} end)

            updated_scope = %{socket.assigns.current_scope | user: refreshed_user}

            {:noreply,
             assign(socket,
               lobbies: lobbies,
               memberships_map: memberships_map,
               current_scope: updated_scope
             )}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("lobbies", "Could not leave: %{reason}", reason: inspect(reason))
             )}
        end

      _ ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("join_lobby", %{"id" => id}, socket) do
    case Lobbies.get_lobby(String.to_integer(id)) do
      lobby when lobby != nil ->
        if lobby.is_private do
          {:noreply, assign(socket, :password_modal_lobby, lobby)}
        else
          # Public lobby, join directly
          handle_start_join_for_lobby(socket, lobby)
        end

      nil ->
        {:noreply, put_flash(socket, :error, dgettext("lobbies", "Lobby not found"))}
    end
  end

  def handle_event("confirm_join", %{"_id" => id, "password" => password}, socket) do
    case socket.assigns.current_scope do
      %{user: user} when user != nil ->
        confirm_lobby_join(socket, user, String.to_integer(id), password)

      _ ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("start_join", %{"id" => id}, socket) do
    case parse_int(id) do
      {:ok, lobby_id} ->
        case Lobbies.get_lobby(lobby_id) do
          nil ->
            {:noreply, put_flash(socket, :error, dgettext("lobbies", "Lobby not found"))}

          %{} = l when l.is_locked ->
            {:noreply, put_flash(socket, :error, dgettext("lobbies", "Lobby is locked"))}

          %{} = l when l.password_hash != nil ->
            {:noreply, assign(socket, joining_lobby_id: l.id, join_password: "")}

          %{} = l ->
            # delegate the complicated user check / join flow to helpers to keep
            # the public handler shallow and readable
            handle_start_join_for_lobby(socket, l)
        end

      :error ->
        {:noreply, put_flash(socket, :error, dgettext("lobbies", "Lobby not found"))}
    end
  end

  def handle_event("cancel_join", _params, socket) do
    {:noreply, assign(socket, joining_lobby_id: nil, join_password: "")}
  end

  def handle_event("start_manage", %{"id" => id}, socket) do
    lobby_id = if is_binary(id), do: String.to_integer(id), else: id
    lobby = Lobbies.get_lobby(lobby_id)

    edit_attrs = %{
      "title" => lobby.title || "",
      "max_users" => lobby.max_users,
      "is_hidden" => lobby.is_hidden,
      "is_locked" => lobby.is_locked
    }

    # only allow editing for the host or hostless lobbies; others get a view-only modal
    can_edit =
      case socket.assigns.current_scope do
        %{user: %{id: uid}} when uid != nil -> uid == lobby.host_id or lobby.hostless
        _ -> false
      end

    {:noreply,
     assign(socket,
       editing_lobby_id: lobby.id,
       edit_attrs: edit_attrs,
       editing_can_edit: can_edit
     )}
  end

  def handle_event("cancel_manage", _params, socket) do
    {:noreply, assign(socket, editing_lobby_id: nil, edit_attrs: %{}, editing_can_edit: false)}
  end

  def handle_event("update_lobby", params, socket) do
    case socket.assigns.current_scope do
      %{user: user} when user != nil ->
        id = params["_id"] || params["id"]
        id = if is_binary(id), do: String.to_integer(id), else: id
        lobby = Lobbies.get_lobby(id)

        attrs = %{}
        attrs = if params["title"], do: Map.put(attrs, "title", params["title"]), else: attrs

        attrs =
          if params["max_users"] && params["max_users"] != "" do
            Map.put(attrs, "max_users", String.to_integer(params["max_users"]))
          else
            attrs
          end

        attrs =
          if Map.get(params, "is_locked") == "true",
            do: Map.put(attrs, "is_locked", true),
            else: Map.put(attrs, "is_locked", false)

        attrs =
          if Map.get(params, "is_hidden") == "true",
            do: Map.put(attrs, "is_hidden", true),
            else: Map.put(attrs, "is_hidden", false)

        attrs =
          if params["password"] && params["password"] != "",
            do: Map.put(attrs, "password", params["password"]),
            else: attrs

        case Lobbies.update_lobby_by_host(user, lobby, attrs) do
          {:ok, updated_lobby} ->
            lobbies =
              Lobbies.list_lobbies_for_user(user, %{},
                page: socket.assigns[:lobbies_page] || 1,
                page_size: socket.assigns[:lobbies_page_size] || 12
              )

            memberships_map =
              Enum.into(lobbies, %{}, fn lp ->
                {lp.id, Lobbies.list_memberships_for_lobby(lp.id)}
              end)

            # refresh edit_attrs so the form shows updated values
            new_edit_attrs = %{
              "title" => updated_lobby.title || "",
              "max_users" => updated_lobby.max_users,
              "is_hidden" => updated_lobby.is_hidden,
              "is_locked" => updated_lobby.is_locked
            }

            {:noreply,
             socket
             |> put_flash(:info, dgettext("lobbies", "Lobby updated"))
             |> assign(
               lobbies: lobbies,
               memberships_map: memberships_map,
               editing_lobby_id: updated_lobby.id,
               edit_attrs: new_edit_attrs
             )}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("lobbies", "Could not update: %{reason}", reason: inspect(reason))
             )}
        end

      _ ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("kick", %{"lobby_id" => lobby_id, "target_id" => target_id}, socket) do
    case socket.assigns.current_scope do
      %{user: user} when user != nil ->
        lobby_id = if is_binary(lobby_id), do: String.to_integer(lobby_id), else: lobby_id
        lobby = Lobbies.get_lobby(lobby_id)
        target = GameServer.Accounts.get_user!(target_id)

        case Lobbies.kick_user(user, lobby, target) do
          {:ok, _} ->
            lobbies =
              Lobbies.list_lobbies_for_user(user, %{},
                page: socket.assigns[:lobbies_page] || 1,
                page_size: socket.assigns[:lobbies_page_size] || 12
              )

            memberships_map =
              Enum.into(lobbies, %{}, fn lp ->
                {lp.id, Lobbies.list_memberships_for_lobby(lp.id)}
              end)

            {:noreply, assign(socket, lobbies: lobbies, memberships_map: memberships_map)}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("lobbies", "Could not kick: %{reason}", reason: inspect(reason))
             )}
        end

      _ ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("lobbies_prev", _params, socket) do
    page = max(1, (socket.assigns[:lobbies_page] || 1) - 1)
    {:noreply, refresh_lobbies(assign(socket, lobbies_page: page))}
  end

  def handle_event("lobbies_next", _params, socket) do
    page = (socket.assigns[:lobbies_page] || 1) + 1
    {:noreply, refresh_lobbies(assign(socket, lobbies_page: page))}
  end

  defp create_lobby_for_user(socket, attrs, user_id) do
    case Lobbies.create_lobby(attrs) do
      {:ok, _lobby} ->
        # refresh user to update lobby_id first
        refreshed_user = GameServer.Accounts.get_user!(user_id)

        lobbies =
          Lobbies.list_lobbies_for_user(refreshed_user, %{},
            page: socket.assigns[:lobbies_page] || 1,
            page_size: socket.assigns[:lobbies_page_size] || 12
          )

        memberships_map =
          Enum.into(lobbies, %{}, fn l ->
            {l.id, Lobbies.list_memberships_for_lobby(l.id)}
          end)

        updated_scope = %{socket.assigns.current_scope | user: refreshed_user}

        {:noreply,
         assign(socket,
           lobbies: lobbies,
           memberships_map: memberships_map,
           title: "",
           current_scope: updated_scope
         )}

      {:error, :already_in_lobby} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("lobbies", "You are already in a lobby and cannot create another")
         )}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp confirm_lobby_join(socket, user, lobby_id, password) do
    # use atom-keyed map so the Lobbies.do_join Map.get(:password) recognizes it
    result = Lobbies.join_lobby(user, lobby_id, %{password: password})

    case result do
      {:ok, _} ->
        # refresh user to update lobby_id first
        refreshed_user = GameServer.Accounts.get_user!(user.id)

        lobbies =
          Lobbies.list_lobbies_for_user(refreshed_user, %{},
            page: socket.assigns[:lobbies_page] || 1,
            page_size: socket.assigns[:lobbies_page_size] || 12
          )

        memberships_map =
          Enum.into(lobbies, %{}, fn lp ->
            {lp.id, Lobbies.list_memberships_for_lobby(lp.id)}
          end)

        updated_scope = %{socket.assigns.current_scope | user: refreshed_user}

        {:noreply,
         assign(socket,
           lobbies: lobbies,
           memberships_map: memberships_map,
           joining_lobby_id: nil,
           join_password: "",
           current_scope: updated_scope
         )}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("lobbies", "Could not join: %{reason}", reason: inspect(reason))
         )}
    end
  end

  # Helpers for start_join flow that were moved here so all public
  # `handle_event/3` clauses stay grouped together at the top of the file.
  defp handle_start_join_for_lobby(socket, lobby) do
    case socket.assigns.current_scope do
      %{user: user} when user != nil -> handle_start_join_for_user(socket, lobby, user)
      _ -> {:noreply, push_navigate(socket, to: ~p"/users/log-in")}
    end
  end

  defp handle_start_join_for_user(socket, lobby, user) do
    if user.lobby_id == lobby.id do
      {:noreply, put_flash(socket, :info, dgettext("lobbies", "You are already in this lobby"))}
    else
      case Lobbies.join_lobby(user, lobby.id) do
        {:ok, _member} ->
          # refresh user to update lobby_id first
          refreshed_user = GameServer.Accounts.get_user!(user.id)

          lobbies =
            Lobbies.list_lobbies_for_user(refreshed_user, %{},
              page: socket.assigns[:lobbies_page] || 1,
              page_size: socket.assigns[:lobbies_page_size] || 12
            )

          memberships_map =
            Enum.into(lobbies, %{}, fn lp ->
              {lp.id, Lobbies.list_memberships_for_lobby(lp.id)}
            end)

          updated_scope = %{socket.assigns.current_scope | user: refreshed_user}

          {:noreply,
           assign(socket,
             lobbies: lobbies,
             memberships_map: memberships_map,
             current_scope: updated_scope
           )}

        {:error, reason} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             dgettext("lobbies", "Could not join: %{reason}", reason: inspect(reason))
           )}
      end
    end
  end

  defp parse_int(v) when is_integer(v), do: {:ok, v}

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_int(_), do: :error

  # PubSub handlers for real-time updates

  @impl true
  def handle_info({:lobby_created, _lobby}, socket) do
    {:noreply, refresh_lobbies(socket)}
  end

  @impl true
  def handle_info({:lobby_updated, _lobby}, socket) do
    {:noreply, refresh_lobbies(socket)}
  end

  @impl true
  def handle_info({:lobby_deleted, _lobby_id}, socket) do
    {:noreply, refresh_lobbies(socket)}
  end

  @impl true
  def handle_info({:lobby_membership_changed, _lobby_id}, socket) do
    {:noreply, refresh_lobbies(socket)}
  end

  @impl true
  def handle_info({:user_joined, lobby_id, _user_id}, socket) do
    # Update memberships for the specific lobby
    {:noreply, refresh_lobby_memberships(socket, lobby_id)}
  end

  @impl true
  def handle_info({:user_left, lobby_id, _user_id}, socket) do
    {:noreply, refresh_lobby_memberships(socket, lobby_id)}
  end

  @impl true
  def handle_info({:user_kicked, lobby_id, user_id}, socket) do
    socket = refresh_lobby_memberships(socket, lobby_id)

    # If I was kicked, update my user state and show a message
    case socket.assigns.current_scope do
      %{user: %{id: ^user_id}} ->
        refreshed_user = GameServer.Accounts.get_user!(user_id)
        updated_scope = %{socket.assigns.current_scope | user: refreshed_user}

        # Unsubscribe from the old lobby
        if socket.assigns[:subscribed_lobby_id] do
          Lobbies.unsubscribe_lobby(socket.assigns.subscribed_lobby_id)
        end

        {:noreply,
         socket
         |> assign(current_scope: updated_scope, subscribed_lobby_id: nil, editing_lobby_id: nil)
         |> put_flash(:error, dgettext("lobbies", "You have been kicked from the lobby"))}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:host_changed, lobby_id, _new_host_id}, socket) do
    {:noreply, refresh_lobby_memberships(socket, lobby_id)}
  end

  # Helper to refresh all lobbies and memberships
  defp refresh_lobbies(socket) do
    user =
      case socket.assigns do
        %{current_scope: %{user: u}} when u != nil ->
          # Refresh user to get latest lobby_id
          GameServer.Accounts.get_user!(u.id)

        _ ->
          nil
      end

    lobbies =
      Lobbies.list_lobbies_for_user(user, %{},
        page: socket.assigns[:lobbies_page] || 1,
        page_size: socket.assigns[:lobbies_page_size] || 12
      )

    memberships_map =
      Enum.into(lobbies, %{}, fn l -> {l.id, Lobbies.list_memberships_for_lobby(l.id)} end)

    # Update subscription if user's lobby changed
    socket = maybe_update_lobby_subscription(socket, user)

    # Update current_scope with refreshed user
    socket =
      if user do
        updated_scope = %{socket.assigns.current_scope | user: user}
        assign(socket, current_scope: updated_scope)
      else
        socket
      end

    total_count = Lobbies.count_list_lobbies(%{})

    total_pages =
      if (socket.assigns[:lobbies_page_size] || 12) > 0,
        do:
          div(
            total_count + (socket.assigns[:lobbies_page_size] || 12) - 1,
            socket.assigns[:lobbies_page_size] || 12
          ),
        else: 0

    assign(socket,
      lobbies: lobbies,
      memberships_map: memberships_map,
      lobbies_total: total_count,
      lobbies_total_pages: total_pages
    )
  end

  # Helper to refresh just one lobby's memberships
  defp refresh_lobby_memberships(socket, lobby_id) do
    memberships = Lobbies.list_memberships_for_lobby(lobby_id)
    memberships_map = Map.put(socket.assigns.memberships_map, lobby_id, memberships)

    # Also refresh the lobby itself in case it was updated
    user =
      case socket.assigns do
        %{current_scope: %{user: u}} when u != nil -> u
        _ -> nil
      end

    lobbies =
      Lobbies.list_lobbies_for_user(user, %{},
        page: socket.assigns[:lobbies_page] || 1,
        page_size: socket.assigns[:lobbies_page_size] || 12
      )

    assign(socket, lobbies: lobbies, memberships_map: memberships_map)
  end

  # Helper to manage lobby subscriptions
  defp maybe_update_lobby_subscription(socket, user) do
    current_subscription = socket.assigns[:subscribed_lobby_id]
    new_lobby_id = user && user.lobby_id

    cond do
      current_subscription == new_lobby_id ->
        # No change needed
        socket

      current_subscription != nil and new_lobby_id != current_subscription ->
        # Unsubscribe from old, subscribe to new
        Lobbies.unsubscribe_lobby(current_subscription)

        if new_lobby_id do
          Lobbies.subscribe_lobby(new_lobby_id)
        end

        assign(socket, subscribed_lobby_id: new_lobby_id)

      new_lobby_id != nil ->
        # Subscribe to new lobby
        Lobbies.subscribe_lobby(new_lobby_id)
        assign(socket, subscribed_lobby_id: new_lobby_id)

      true ->
        socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="p-6">
        <.header>
          {dgettext("lobbies", "Lobbies")}
          <:subtitle>{dgettext("lobbies", "Browse and join lobbies")}</:subtitle>
        </.header>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-4">
          <div class="card bg-base-200 p-4 rounded-lg">
            <div class="font-semibold">{dgettext("lobbies", "Create a Lobby")}</div>
            <div class="text-sm text-base-content/80 mt-2">
              {dgettext("lobbies", "Create a lobby to host a match.")}
            </div>
            <div class="mt-2 flex gap-2 items-center">
              <button phx-click="lobbies_prev" class="btn btn-xs" disabled={@lobbies_page <= 1}>
                {gettext("Prev")}
              </button>
              <div class="text-xs text-base-content/70">
                {gettext("page %{page} / %{total_pages} (%{total} total)",
                  page: @lobbies_page,
                  total_pages: @lobbies_total_pages,
                  total: @lobbies_total
                )}
              </div>
              <button
                phx-click="lobbies_next"
                class="btn btn-xs"
                disabled={@lobbies_page >= @lobbies_total_pages || @lobbies_total_pages == 0}
              >
                {gettext("Next")}
              </button>
            </div>

            <form phx-submit="create" class="mt-4 space-y-3">
              <.input name="title" label={gettext("Title")} value={@title} />
              <div class="flex items-center gap-2">
                <button type="submit" class="btn btn-primary">{gettext("Create")}</button>
                <%= if @current_scope && @current_scope.user && @current_scope.user.lobby_id do %>
                  <span class="text-sm text-warning">
                    {dgettext("lobbies", "You are already in a lobby")}
                  </span>
                <% end %>
              </div>
            </form>
          </div>

          <div class="lg:col-span-2">
            <div class="font-semibold">{dgettext("lobbies", "Open Lobbies")}</div>
            <div class="mt-3 grid grid-cols-1 md:grid-cols-2 gap-4">
              <div
                :for={lobby <- @lobbies}
                id={"lobby-" <> to_string(lobby.id)}
                class="card bg-base-200 p-4 rounded-lg"
              >
                <div class="flex justify-between items-start">
                  <div>
                    <div class="text-lg font-semibold">{lobby.title}</div>
                    <div class="text-xs text-base-content/60 mt-2">
                      {dgettext("lobbies", "%{count} / %{max} members",
                        count: length(@memberships_map[lobby.id] || []),
                        max: lobby.max_users
                      )}
                    </div>
                  </div>
                  <div class="flex flex-col items-end gap-2">
                    <%= if @current_scope && @current_scope.user do %>
                      <% user = @current_scope.user %>

                      <%= cond do %>
                        <% user.id == lobby.host_id -> %>
                          <%!-- Host sees Manage button --%>
                          <button
                            phx-click="start_manage"
                            phx-value-id={lobby.id}
                            class="btn btn-outline btn-sm"
                          >
                            {dgettext("lobbies", "Manage")}
                          </button>
                        <% user.lobby_id == lobby.id -> %>
                          <%!-- Non-host member can View (with Leave inside) --%>
                          <button
                            phx-click="start_manage"
                            phx-value-id={lobby.id}
                            class="btn btn-ghost btn-sm"
                          >
                            {gettext("View")}
                          </button>
                        <% user.lobby_id != nil -> %>
                          <%!-- User in another lobby can only view this one --%>
                          <button
                            phx-click="start_manage"
                            phx-value-id={lobby.id}
                            class="btn btn-ghost btn-sm"
                          >
                            {gettext("View")}
                          </button>
                        <% lobby.is_locked -> %>
                          <button class="btn btn-disabled btn-sm">{gettext("Locked")}</button>
                        <% true -> %>
                          <button
                            phx-click="start_join"
                            phx-value-id={lobby.id}
                            class="btn btn-primary btn-sm"
                          >
                            {gettext("Join")}
                          </button>
                      <% end %>
                    <% else %>
                      <%= if lobby.is_locked do %>
                        <button class="btn btn-disabled btn-sm">{gettext("Locked")}</button>
                      <% else %>
                        <button
                          phx-click="start_join"
                          phx-value-id={lobby.id}
                          class="btn btn-primary btn-sm"
                        >
                          {gettext("Join")}
                        </button>
                      <% end %>
                    <% end %>
                  </div>
                </div>

                <%= if @joining_lobby_id == lobby.id do %>
                  <div class="mt-3">
                    <form phx-submit="confirm_join">
                      <input type="hidden" name="_id" value={lobby.id} />
                      <div class="flex items-center gap-2">
                        <input
                          name="password"
                          value={@join_password}
                          placeholder={gettext("Password")}
                          class="input input-sm"
                        />
                        <button type="submit" class="btn btn-primary btn-sm">
                          {gettext("Confirm")}
                        </button>
                        <button type="button" phx-click="cancel_join" class="btn btn-ghost btn-sm">
                          {gettext("Cancel")}
                        </button>
                      </div>
                    </form>
                  </div>
                <% end %>

                <%= if @editing_lobby_id == lobby.id do %>
                  <div class="mt-3 bg-base-300 p-3 rounded">
                    <%= if @editing_can_edit do %>
                      <form phx-submit="update_lobby">
                        <input type="hidden" name="_id" value={lobby.id} />
                        <div class="grid grid-cols-1 gap-2">
                          <input
                            name="title"
                            class="input input-sm"
                            value={@edit_attrs["title"] || lobby.title || ""}
                          />
                          <input
                            name="max_users"
                            type="number"
                            class="input input-sm"
                            value={@edit_attrs["max_users"] || lobby.max_users}
                          />
                          <div class="flex items-center gap-2">
                            <input
                              type="checkbox"
                              name="is_locked"
                              value="true"
                              checked={@edit_attrs["is_locked"]}
                            />
                            <label class="text-sm">{gettext("Locked")}</label>
                          </div>
                          <div class="flex items-center gap-2">
                            <input
                              type="checkbox"
                              name="is_hidden"
                              value="true"
                              checked={@edit_attrs["is_hidden"]}
                            />
                            <label class="text-sm">{gettext("Hidden")}</label>
                          </div>
                          <input
                            name="password"
                            class="input input-sm"
                            placeholder={dgettext("lobbies", "Leave empty to clear")}
                          />
                          <div class="flex items-center gap-2 mt-2">
                            <button type="submit" class="btn btn-primary btn-sm">
                              {gettext("Save")}
                            </button>
                            <button
                              type="button"
                              phx-click="cancel_manage"
                              class="btn btn-ghost btn-sm"
                            >
                              {gettext("Close")}
                            </button>
                          </div>
                        </div>
                      </form>

                      <div class="mt-3">
                        <h4 class="font-semibold">{gettext("Members")}</h4>
                        <ul>
                          <li
                            :for={m <- @memberships_map[lobby.id] || []}
                            id={"member-" <> to_string(m.id)}
                            class="flex items-center justify-between py-1"
                          >
                            <div>{m.display_name || m.email || "user-#{m.id}"}</div>
                            <div class="flex items-center gap-2">
                              <%= if m.id == lobby.host_id do %>
                                <span class="text-xs text-muted">
                                  {dgettext("lobbies", "(host)")}
                                </span>
                              <% end %>
                              <%= cond do %>
                                <% @current_scope && @current_scope.user && m.id == @current_scope.user.id -> %>
                                  <%!-- Current user (host or member) can leave --%>
                                  <button phx-click="leave" class="btn btn-xs btn-warning">
                                    {gettext("Leave")}
                                  </button>
                                <% m.id == lobby.host_id -> %>
                                  <%!-- Host row without Leave (handled above if current user) --%>
                                <% true -> %>
                                  <button
                                    phx-click="kick"
                                    phx-value-lobby_id={lobby.id}
                                    phx-value-target_id={m.id}
                                    class="btn btn-xs btn-outline"
                                  >
                                    {gettext("Kick")}
                                  </button>
                              <% end %>
                            </div>
                          </li>
                        </ul>
                      </div>
                    <% else %>
                      <div class="mt-3">
                        <h4 class="font-semibold">{gettext("Members")}</h4>
                        <ul>
                          <li
                            :for={m <- @memberships_map[lobby.id] || []}
                            id={"member-" <> to_string(m.id)}
                            class="flex items-center justify-between py-1"
                          >
                            <div>{m.display_name || m.email || "user-#{m.id}"}</div>
                            <div>
                              <%= if m.id == lobby.host_id do %>
                                <span class="text-xs text-muted">
                                  {dgettext("lobbies", "(host)")}
                                </span>
                              <% end %>
                              <%= if @current_scope && @current_scope.user && m.id == @current_scope.user.id do %>
                                <button phx-click="leave" class="btn btn-xs btn-warning ml-2">
                                  {gettext("Leave")}
                                </button>
                              <% end %>
                            </div>
                          </li>
                        </ul>
                      </div>
                      <div class="flex items-center gap-2 mt-2">
                        <button type="button" phx-click="cancel_manage" class="btn btn-ghost btn-sm">
                          {gettext("Close")}
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
