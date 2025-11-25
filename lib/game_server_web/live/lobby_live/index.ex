defmodule GameServerWeb.LobbyLive.Index do
  use GameServerWeb, :live_view

  alias GameServer.Lobbies

  @impl true
  def mount(_params, _session, socket) do
    # Get current user from scope if available
    user =
      case socket.assigns do
        %{current_scope: %{user: u}} when not is_nil(u) -> u
        _ -> nil
      end

    lobbies = Lobbies.list_lobbies_for_user(user)

    memberships_map =
      Enum.into(lobbies, %{}, fn l -> {l.id, Lobbies.list_memberships_for_lobby(l.id)} end)

    {:ok,
     assign(socket,
       lobbies: lobbies,
       memberships_map: memberships_map,
       title: "",
       joining_lobby_id: nil,
       join_password: "",
       editing_lobby_id: nil,
       edit_attrs: %{},
       editing_can_edit: false
     )}
  end

  @impl true
  def handle_event("create", %{"title" => title}, socket) do
    attrs = %{"title" => title}

    case socket.assigns.current_scope do
      %{user: %{id: id}} when not is_nil(id) ->
        attrs = Map.put(attrs, "host_id", id)

        # prevent creating more than one lobby for the same user
        case GameServer.Repo.get(GameServer.Accounts.User, id) do
          %GameServer.Accounts.User{lobby_id: existing} when not is_nil(existing) ->
            {:noreply,
             put_flash(socket, :error, "You are already in a lobby and cannot create another")}

          _ ->
            case Lobbies.create_lobby(attrs) do
              {:ok, _lobby} ->
                # refresh user to update lobby_id first
                refreshed_user = GameServer.Accounts.get_user!(id)
                lobbies = Lobbies.list_lobbies_for_user(refreshed_user)

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
                 put_flash(socket, :error, "You are already in a lobby and cannot create another")}

              {:error, _} ->
                {:noreply, socket}
            end
        end

      _ ->
        {:noreply, push_navigate(socket, to: "/users/log-in")}
    end
  end

  def handle_event("leave", _params, socket) do
    case socket.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        case Lobbies.leave_lobby(user) do
          {:ok, _} ->
            # refresh user to update lobby_id first
            refreshed_user = GameServer.Accounts.get_user!(user.id)
            lobbies = Lobbies.list_lobbies_for_user(refreshed_user)

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
            {:noreply, put_flash(socket, :error, "Could not leave: #{inspect(reason)}")}
        end

      _ ->
        {:noreply, push_navigate(socket, to: "/users/log-in")}
    end
  end

  @impl true
  def handle_event("start_join", %{"id" => id}, socket) do
    lobby = Lobbies.get_lobby(id)

    case lobby do
      %{} = l when l.is_locked ->
        {:noreply, put_flash(socket, :error, "Lobby is locked")}

      %{} = l when not is_nil(l.password_hash) ->
        {:noreply, assign(socket, joining_lobby_id: l.id, join_password: "")}

      %{} = l ->
        case socket.assigns.current_scope do
          %{user: user} when not is_nil(user) ->
            # prevent joining a lobby if already in it or in another lobby
            if user.lobby_id == l.id do
              {:noreply, put_flash(socket, :info, "You are already in this lobby")}
            else
              case Lobbies.join_lobby(user, l.id) do
                {:ok, _member} ->
                  # refresh user to update lobby_id first
                  refreshed_user = GameServer.Accounts.get_user!(user.id)
                  lobbies = Lobbies.list_lobbies_for_user(refreshed_user)

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
                  {:noreply, put_flash(socket, :error, "Could not join: #{inspect(reason)}")}
              end
            end

          _ ->
            {:noreply, push_navigate(socket, to: "/users/log-in")}
        end
    end
  end

  def handle_event("confirm_join", %{"_id" => id, "password" => password}, socket) do
    case socket.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        id = if is_binary(id), do: String.to_integer(id), else: id

        # prevent joining the lobby if already a member
        if user.lobby_id == id do
          {:noreply, put_flash(socket, :info, "You are already in this lobby")}
        else
          # use atom-keyed map so the Lobbies.do_join Map.get(:password) recognizes it
          result = Lobbies.join_lobby(user, id, %{password: password})

          case result do
            {:ok, _} ->
              # refresh user to update lobby_id first
              refreshed_user = GameServer.Accounts.get_user!(user.id)
              lobbies = Lobbies.list_lobbies_for_user(refreshed_user)

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
              {:noreply, put_flash(socket, :error, "Could not join: #{inspect(reason)}")}
          end
        end

      _ ->
        {:noreply, push_navigate(socket, to: "/users/log-in")}
    end
  end

  def handle_event("cancel_join", _params, socket) do
    {:noreply, assign(socket, joining_lobby_id: nil, join_password: "")}
  end

  def handle_event("start_manage", %{"id" => id}, socket) do
    lobby = Lobbies.get_lobby(id)

    edit_attrs = %{
      "title" => lobby.title || "",
      "max_users" => lobby.max_users,
      "is_hidden" => lobby.is_hidden,
      "is_locked" => lobby.is_locked
    }

    # only allow editing for the host or hostless lobbies; others get a view-only modal
    can_edit =
      case socket.assigns.current_scope do
        %{user: %{id: uid}} when not is_nil(uid) -> uid == lobby.host_id or lobby.hostless
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
      %{user: user} when not is_nil(user) ->
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
            lobbies = Lobbies.list_lobbies_for_user(user)

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
             |> put_flash(:info, "Lobby updated")
             |> assign(
               lobbies: lobbies,
               memberships_map: memberships_map,
               editing_lobby_id: updated_lobby.id,
               edit_attrs: new_edit_attrs
             )}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Could not update: #{inspect(reason)}")}
        end

      _ ->
        {:noreply, push_navigate(socket, to: "/users/log-in")}
    end
  end

  def handle_event("kick", %{"lobby_id" => lobby_id, "target_id" => target_id}, socket) do
    case socket.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        lobby = Lobbies.get_lobby(lobby_id)
        target = GameServer.Accounts.get_user!(target_id)

        case Lobbies.kick_user(user, lobby, target) do
          {:ok, _} ->
            lobbies = Lobbies.list_lobbies_for_user(user)

            memberships_map =
              Enum.into(lobbies, %{}, fn lp ->
                {lp.id, Lobbies.list_memberships_for_lobby(lp.id)}
              end)

            {:noreply, assign(socket, lobbies: lobbies, memberships_map: memberships_map)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Could not kick: #{inspect(reason)}")}
        end

      _ ->
        {:noreply, push_navigate(socket, to: "/users/log-in")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="p-6">
        <.header>
          Lobbies
          <:subtitle>Find, create and join public lobbies</:subtitle>
        </.header>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-4">
          <div class="card bg-base-200 p-4 rounded-lg">
            <div class="font-semibold">Create a Lobby</div>
            <div class="text-sm text-base-content/80 mt-2">
              Create a lobby to host a match. You will automatically join the lobby you create.
            </div>

            <form phx-submit="create" class="mt-4 space-y-3">
              <.input name="title" label="Title" value={@title} />
              <div class="flex items-center gap-2">
                <button type="submit" class="btn btn-primary">Create</button>
                <%= if @current_scope && @current_scope.user && @current_scope.user.lobby_id do %>
                  <span class="text-sm text-warning">You are already in a lobby</span>
                <% end %>
              </div>
            </form>
          </div>

          <div class="lg:col-span-2">
            <div class="font-semibold">Open Lobbies</div>
            <div class="mt-3 grid grid-cols-1 md:grid-cols-2 gap-4">
              <div
                :for={lobby <- @lobbies}
                id={"lobby-" <> to_string(lobby.id)}
                class="card bg-base-200 p-4 rounded-lg"
              >
                <div class="flex justify-between items-start">
                  <div>
                    <div class="text-lg font-semibold">{lobby.title || lobby.name}</div>
                    <div class="text-xs text-base-content/60 mt-2">
                      Members: {length(@memberships_map[lobby.id] || [])} / {lobby.max_users}
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
                            Manage
                          </button>
                        <% user.lobby_id == lobby.id -> %>
                          <%!-- Non-host member can View (with Leave inside) --%>
                          <button
                            phx-click="start_manage"
                            phx-value-id={lobby.id}
                            class="btn btn-ghost btn-sm"
                          >
                            View
                          </button>
                        <% user.lobby_id != nil -> %>
                          <%!-- User in another lobby can only view this one --%>
                          <button
                            phx-click="start_manage"
                            phx-value-id={lobby.id}
                            class="btn btn-ghost btn-sm"
                          >
                            View
                          </button>
                        <% lobby.is_locked -> %>
                          <button class="btn btn-disabled btn-sm">Locked</button>
                        <% true -> %>
                          <button
                            phx-click="start_join"
                            phx-value-id={lobby.id}
                            class="btn btn-primary btn-sm"
                          >
                            Join
                          </button>
                      <% end %>
                    <% else %>
                      <%= if lobby.is_locked do %>
                        <button class="btn btn-disabled btn-sm">Locked</button>
                      <% else %>
                        <button
                          phx-click="start_join"
                          phx-value-id={lobby.id}
                          class="btn btn-primary btn-sm"
                        >
                          Join
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
                          placeholder="Password"
                          class="input input-sm"
                        />
                        <button type="submit" class="btn btn-primary btn-sm">Confirm</button>
                        <button type="button" phx-click="cancel_join" class="btn btn-ghost btn-sm">
                          Cancel
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
                            <label class="text-sm">Locked</label>
                          </div>
                          <div class="flex items-center gap-2">
                            <input
                              type="checkbox"
                              name="is_hidden"
                              value="true"
                              checked={@edit_attrs["is_hidden"]}
                            />
                            <label class="text-sm">Hidden</label>
                          </div>
                          <input
                            name="password"
                            class="input input-sm"
                            placeholder="leave empty to clear"
                          />
                          <div class="flex items-center gap-2 mt-2">
                            <button type="submit" class="btn btn-primary btn-sm">Save</button>
                            <button
                              type="button"
                              phx-click="cancel_manage"
                              class="btn btn-ghost btn-sm"
                            >
                              Close
                            </button>
                          </div>
                        </div>
                      </form>

                      <div class="mt-3">
                        <h4 class="font-semibold">Members</h4>
                        <ul>
                          <li
                            :for={m <- @memberships_map[lobby.id] || []}
                            id={"member-" <> to_string(m.id)}
                            class="flex items-center justify-between py-1"
                          >
                            <div>{m.display_name || m.email || "user-#{m.id}"}</div>
                            <div class="flex items-center gap-2">
                              <%= if m.id == lobby.host_id do %>
                                <span class="text-xs text-muted">(host)</span>
                              <% end %>
                              <%= cond do %>
                                <% @current_scope && @current_scope.user && m.id == @current_scope.user.id -> %>
                                  <%!-- Current user (host or member) can leave --%>
                                  <button phx-click="leave" class="btn btn-xs btn-warning">
                                    Leave
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
                                    Kick
                                  </button>
                              <% end %>
                            </div>
                          </li>
                        </ul>
                      </div>
                    <% else %>
                      <div class="mt-3">
                        <h4 class="font-semibold">Members</h4>
                        <ul>
                          <li
                            :for={m <- @memberships_map[lobby.id] || []}
                            id={"member-" <> to_string(m.id)}
                            class="flex items-center justify-between py-1"
                          >
                            <div>{m.display_name || m.email || "user-#{m.id}"}</div>
                            <div>
                              <%= if m.id == lobby.host_id do %>
                                <span class="text-xs text-muted">(host)</span>
                              <% end %>
                              <%= if @current_scope && @current_scope.user && m.id == @current_scope.user.id do %>
                                <button phx-click="leave" class="btn btn-xs btn-warning ml-2">
                                  Leave
                                </button>
                              <% end %>
                            </div>
                          </li>
                        </ul>
                      </div>
                      <div class="flex items-center gap-2 mt-2">
                        <button type="button" phx-click="cancel_manage" class="btn btn-ghost btn-sm">
                          Close
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
