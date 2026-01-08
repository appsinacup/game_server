defmodule GameServerWeb.UserLive.Settings do
  use GameServerWeb, :live_view

  alias GameServer.Accounts
  alias GameServer.Friends
  alias GameServer.KV
  # Repo / Ecto.Query not needed in settings LiveView

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your account email address and password settings</:subtitle>
        </.header>

        <%= if @conflict_user do %>
          <div class="divider" />

          <div class="card bg-warning/10 border-warning p-4 rounded-lg">
            <div class="flex items-start justify-between">
              <div>
                <strong>Conflict detected</strong>
                <div class="text-sm text-base-content/70">
                  The {@conflict_provider} account (ID: {@conflict_user.id}) is already linked to another account.
                  If this is another account you own (matching email), you may delete it below to free the provider so you can link it to this account.
                </div>
              </div>
              <div class="flex items-center gap-2">
                <button
                  phx-click="delete_conflicting_account"
                  phx-value-id={@conflict_user.id}
                  class="btn btn-error btn-sm"
                  data-confirm="Delete the conflicting account? This is irreversible."
                >
                  Delete account
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <div class="mt-6 grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="card bg-base-200 p-4 rounded-lg">
          <div class="font-semibold">Account details</div>
          <div class="text-sm mt-2 space-y-1 text-base-content/80">
            <div><strong>ID:</strong> {@user.id}</div>
            <div><strong>Email:</strong> {@current_email}</div>

            <.form
              for={@display_form}
              id="display_form"
              phx-change="validate_display_name"
              phx-submit="update_display_name"
            >
              <.input
                field={@display_form[:display_name]}
                type="text"
                label="Display name"
                required
              />
              <.button variant="primary" phx-disable-with="Saving...">Save Display Name</.button>
            </.form>

            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
            >
              <.input
                field={@email_form[:email]}
                type="email"
                label="Email"
                autocomplete="username"
                required
              />
              <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
            </.form>
          </div>
        </div>

        <div class="card bg-base-200 p-4 rounded-lg">
          <div class="font-semibold">Metadata</div>
          <div class="text-sm mt-2 font-mono text-xs bg-base-300 p-3 rounded-lg overflow-auto text-base-content/80">
            <pre phx-no-curly-interpolation><%= Jason.encode!(@user.metadata || %{}, pretty: true) %></pre>
          </div>

          <.form
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              autocomplete="username"
              value={@current_email}
            />
            <.input
              field={@password_form[:password]}
              type="password"
              label="New password"
              autocomplete="new-password"
              required
            />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
            />
            <.button variant="primary" phx-disable-with="Saving...">
              Save Password
            </.button>
          </.form>
        </div>
      </div>
      
    <!-- Friends panel (embedded) -->
      <div class="card bg-base-200 p-4 rounded-lg mt-6">
        <div class="flex items-center justify-between">
          <div>
            <div class="font-semibold text-lg">Friends</div>
            <div class="text-sm text-base-content/70">
              View and manage friend requests and current friends
            </div>
          </div>
        </div>

        <div class="mt-4 grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <h4 class="font-semibold">Incoming Requests</h4>
            <div
              :for={req <- @incoming}
              id={"request-" <> Integer.to_string(req.id)}
              class="p-2 border rounded mt-2"
            >
              <div class="text-sm">
                {(req.requester && req.requester.display_name) ||
                  "User " <> to_string(req.requester_id)}
                <span class="text-xs text-base-content/60 ml-2">(id: {req.requester_id})</span>
              </div>
              <div class="flex gap-2 mt-2">
                <button phx-click="accept_friend" phx-value-id={req.id} class="btn btn-sm btn-primary">
                  Accept
                </button>
                <button phx-click="reject_friend" phx-value-id={req.id} class="btn btn-sm btn-error">
                  Reject
                </button>
                <button
                  phx-click="block_friend"
                  phx-value-id={req.id}
                  class="btn btn-sm btn-outline btn-error"
                >
                  Block
                </button>
              </div>
            </div>

            <div :if={@incoming_total_pages > 1} class="mt-2 flex gap-2 items-center">
              <button phx-click="incoming_prev" class="btn btn-xs" disabled={@incoming_page <= 1}>
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@incoming_page} / {@incoming_total_pages} ({@incoming_total} total)
              </div>
              <button
                phx-click="incoming_next"
                class="btn btn-xs"
                disabled={@incoming_page >= @incoming_total_pages || @incoming_total_pages == 0}
              >
                Next
              </button>
            </div>
          </div>

          <div>
            <h4 class="font-semibold">Outgoing Requests</h4>
            <div
              :for={req <- @outgoing}
              id={"outgoing-" <> Integer.to_string(req.id)}
              class="p-2 border rounded mt-2"
            >
              <div class="text-sm">
                {(req.target && req.target.display_name) || "User " <> to_string(req.target_id)}
              </div>
              <div class="flex gap-2 mt-2">
                <button phx-click="cancel_friend" phx-value-id={req.id} class="btn btn-sm btn-error">
                  Cancel
                </button>
              </div>
            </div>
            <div :if={@outgoing_total_pages > 1} class="mt-2 flex gap-2 items-center">
              <button phx-click="outgoing_prev" class="btn btn-xs" disabled={@outgoing_page <= 1}>
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@outgoing_page} / {@outgoing_total_pages} ({@outgoing_total} total)
              </div>
              <button
                phx-click="outgoing_next"
                class="btn btn-xs"
                disabled={@outgoing_page >= @outgoing_total_pages || @outgoing_total_pages == 0}
              >
                Next
              </button>
            </div>
          </div>

          <div>
            <h4 class="font-semibold">Friends</h4>
            <div
              :for={u <- @friends}
              id={"friend-" <> Integer.to_string(u.id)}
              class="p-2 border rounded mt-2"
            >
              <div class="flex justify-between items-center gap-2">
                <div class="text-sm">
                  {u.display_name || u.email}
                  <span class="text-xs text-base-content/60 ml-2">(id: {u.id})</span>
                </div>
                <button
                  phx-click="remove_friend"
                  phx-value-friend_id={u.id}
                  class="btn btn-sm btn-error btn-outline"
                >
                  Remove
                </button>
              </div>
            </div>
            <div :if={@friends_total_pages > 1} class="mt-2 flex gap-2 items-center">
              <button phx-click="friends_prev" class="btn btn-xs" disabled={@friends_page <= 1}>
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@friends_page} / {@friends_total_pages} ({@friends_total} total)
              </div>
              <button
                phx-click="friends_next"
                class="btn btn-xs"
                disabled={@friends_page >= @friends_total_pages || @friends_total_pages == 0}
              >
                Next
              </button>
            </div>
          </div>
        </div>

        <div class="divider mt-4" />

        <div class="mt-2">
          <div :if={length(@blocked) > 0} class="mt-4">
            <div class="text-xs text-base-content/70">Blocked users</div>
            <div
              :for={b <- @blocked}
              id={"blocked-" <> Integer.to_string(b.id)}
              class="p-2 border rounded mt-2 flex items-center justify-between"
            >
              <div class="text-sm">
                {(b.requester && b.requester.display_name) || "User " <> to_string(b.requester_id)}
                <span class="text-xs text-base-content/60 ml-2">(id: {b.requester_id})</span>
              </div>
              <div>
                <button phx-click="unblock_friend" phx-value-id={b.id} class="btn btn-xs btn-outline">
                  Unblock
                </button>
              </div>
            </div>
            <div :if={@blocked_total_pages > 1} class="mt-2 flex gap-2 items-center">
              <button phx-click="blocked_prev" class="btn btn-xs" disabled={@blocked_page <= 1}>
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@blocked_page} / {@blocked_total_pages} ({@blocked_total} total)
              </div>
              <button
                phx-click="blocked_next"
                class="btn btn-xs"
                disabled={@blocked_page >= @blocked_total_pages || @blocked_total_pages == 0}
              >
                Next
              </button>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <form phx-change="search_users" class="w-full">
              <input
                type="text"
                name="q"
                value={@search_query}
                placeholder="Search by email or display name"
                class="input"
              />
            </form>
          </div>
          <div :if={length(@search_results) > 0} class="mt-3">
            <div class="text-xs text-base-content/70 mb-2">Search results</div>
            
    <!-- Render search results as a responsive grid so multiple items show side-by-side -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-2">
              <div :for={s <- @search_results} id={"search-" <> Integer.to_string(s.id)}>
                <div class="p-2 border rounded bg-base-100 flex items-center justify-between">
                  <div class="text-sm">
                    {s.display_name || s.email}
                    <span class="text-xs text-base-content/60 ml-2">(id: {s.id})</span>
                  </div>
                  <div>
                    <button
                      phx-click="send_friend"
                      phx-value-target={s.id}
                      class="btn btn-xs btn-primary"
                    >
                      Send
                    </button>
                  </div>
                </div>
              </div>
            </div>
            <div :if={@search_total_pages > 1} class="mt-2 flex gap-2 items-center">
              <button phx-click="search_prev" class="btn btn-xs" disabled={@search_page <= 1}>
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@search_page} / {@search_total_pages} ({@search_total} total)
              </div>
              <button
                phx-click="search_next"
                class="btn btn-xs"
                disabled={@search_page >= @search_total_pages || @search_total_pages == 0}
              >
                Next
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="card bg-base-200 p-4 rounded-lg mt-6">
        <div class="flex items-center justify-between">
          <div>
            <div class="font-semibold text-lg">Data</div>
            <div class="text-sm text-base-content/70">View your User Data</div>
          </div>
        </div>

        <div class="mt-4">
          <.form
            for={@kv_filter_form}
            id="kv-filters"
            phx-change="kv_filters_change"
            phx-submit="kv_filters_apply"
          >
            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <.input
                field={@kv_filter_form[:key]}
                type="text"
                label="Key contains"
                phx-debounce="300"
              />
            </div>
            <div class="flex gap-2 mt-2">
              <button type="submit" class="btn btn-sm btn-outline">Apply</button>
              <button type="button" phx-click="kv_filters_clear" class="btn btn-sm btn-ghost">
                Clear
              </button>
            </div>
          </.form>
        </div>

        <div class="overflow-x-auto mt-4">
          <table id="user-kv-table" class="table table-zebra w-full table-fixed">
            <colgroup>
              <col class="w-16" />
              <col class="w-[40%]" />
              <col class="w-40" />
              <col class="w-[20%]" />
              <col class="w-[20%]" />
            </colgroup>
            <thead>
              <tr>
                <th class="w-16">ID</th>
                <th class="font-mono text-sm break-all">Key</th>
                <th class="w-40">Updated</th>
                <th>Value</th>
                <th>Metadata</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={e <- @kv_entries} id={"user-kv-" <> to_string(e.id)}>
                <td class="font-mono text-sm w-16">{e.id}</td>
                <td class="font-mono text-sm break-all">{e.key}</td>
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
              </tr>
            </tbody>
          </table>
        </div>

        <div class="mt-4 flex gap-2 items-center">
          <button phx-click="kv_prev" class="btn btn-xs" disabled={@kv_page <= 1}>Prev</button>
          <div class="text-xs text-base-content/70">
            page {@kv_page} / {@kv_total_pages} ({@kv_count} total)
          </div>
          <button
            phx-click="kv_next"
            class="btn btn-xs"
            disabled={@kv_page >= @kv_total_pages || @kv_total_pages == 0}
          >
            Next
          </button>
        </div>
      </div>

      <div class="card bg-base-200 p-4 rounded-lg">
        <div class="font-semibold">Linked Accounts</div>
        <div class="mt-2 grid grid-cols-1 md:grid-cols-2 gap-4">
          <% provider_count =
            Enum.count(
              [@user.discord_id, @user.apple_id, @user.google_id, @user.facebook_id, @user.steam_id],
              fn v ->
                v && v != ""
              end
            ) %>

          <div class="flex items-center justify-between">
            <div>
              <strong>Discord</strong>
              <div class="text-sm text-base-content/70">
                Sign in with Discord and link to your account
              </div>
            </div>
            <div class="flex items-center gap-2">
              <%= if @user.discord_id do %>
                <%= if provider_count > 1 do %>
                  <button
                    phx-click="unlink_provider"
                    phx-value-provider="discord"
                    class="btn btn-outline btn-sm"
                  >
                    Unlink
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>Unlink</button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/discord"} class="btn btn-primary btn-sm">Link</.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>Google</strong>
              <div class="text-sm text-base-content/70">
                Sign in with Google and link to your account
              </div>
            </div>
            <div class="flex items-center gap-2">
              <%= if @user.google_id do %>
                <%= if provider_count > 1 do %>
                  <button
                    phx-click="unlink_provider"
                    phx-value-provider="google"
                    class="btn btn-outline btn-sm"
                  >
                    Unlink
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>Unlink</button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/google"} class="btn btn-primary btn-sm">Link</.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>Facebook</strong>
              <div class="text-sm text-base-content/70">
                Sign in with Facebook and link to your account
              </div>
            </div>
            <div class="flex items-center gap-2">
              <%= if @user.facebook_id do %>
                <%= if provider_count > 1 do %>
                  <button
                    phx-click="unlink_provider"
                    phx-value-provider="facebook"
                    class="btn btn-outline btn-sm"
                  >
                    Unlink
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>Unlink</button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/facebook"} class="btn btn-primary btn-sm">Link</.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>Apple</strong>
              <div class="text-sm text-base-content/70">
                Sign in with Apple and link to your account
              </div>
            </div>
            <div class="flex items-center gap-2">
              <%= if @user.apple_id do %>
                <%= if provider_count > 1 do %>
                  <button
                    phx-click="unlink_provider"
                    phx-value-provider="apple"
                    class="btn btn-outline btn-sm"
                  >
                    Unlink
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>Unlink</button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/apple"} class="btn btn-primary btn-sm">Link</.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>Steam</strong>
              <div class="text-sm text-base-content/70">
                Sign in with Steam and link to your account
              </div>
            </div>
            <div class="flex items-center gap-2">
              <%= if @user.steam_id do %>
                <%= if provider_count > 1 do %>
                  <button
                    phx-click="unlink_provider"
                    phx-value-provider="steam"
                    class="btn btn-outline btn-sm"
                  >
                    Unlink
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>Unlink</button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/steam"} class="btn btn-primary btn-sm">Link</.link>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <div class="card bg-error/10 border-error p-4 rounded-lg">
        <div class="font-semibold text-error">Danger Zone</div>
        <div class="text-sm mt-2 text-base-content/80">
          <p>Once you delete your account, there is no going back. Please be certain.</p>
          <p class="mt-2">
            {gettext(
              "For information about what data is deleted and how to request deletion, see our"
            )}
            <.link
              href={~p"/data-deletion"}
              class="link link-primary"
            >{gettext("Data Deletion Policy")}</.link>.
          </p>
        </div>
        <div class="mt-4">
          <button
            phx-click="delete_user"
            class="btn btn-error"
            data-confirm={
              gettext("Are you sure you want to delete your account? This action cannot be undone.")
            }
          >
            {gettext("Delete Account")}
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, gettext("Email changed successfully."))

        {:error, _} ->
          put_flash(socket, :error, gettext("Email change link is invalid or it has expired."))
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:user, user)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:display_form, to_form(Accounts.change_user_display_name(user)))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:conflict_user, nil)
      |> assign(:conflict_provider, nil)
      |> assign(:incoming_page, 1)
      |> assign(:incoming_page_size, 25)
      |> assign(:incoming_total, Friends.count_incoming_requests(user))
      |> assign(
        :incoming_total_pages,
        if(25 > 0, do: div(Friends.count_incoming_requests(user) + 25 - 1, 25), else: 0)
      )
      |> assign(:outgoing_page, 1)
      |> assign(:outgoing_page_size, 25)
      |> assign(:outgoing_total, Friends.count_outgoing_requests(user))
      |> assign(
        :outgoing_total_pages,
        if(25 > 0, do: div(Friends.count_outgoing_requests(user) + 25 - 1, 25), else: 0)
      )
      |> assign(:friends_page, 1)
      |> assign(:friends_page_size, 25)
      |> assign(:friends_total, Friends.count_friends_for_user(user))
      |> assign(
        :friends_total_pages,
        if(25 > 0, do: div(Friends.count_friends_for_user(user) + 25 - 1, 25), else: 0)
      )
      |> assign(:blocked_page, 1)
      |> assign(:blocked_page_size, 25)
      |> assign(:blocked_total, Friends.count_blocked_for_user(user))
      |> assign(
        :blocked_total_pages,
        if(25 > 0, do: div(Friends.count_blocked_for_user(user) + 25 - 1, 25), else: 0)
      )
      |> assign(:incoming, Friends.list_incoming_requests(user, page: 1, page_size: 25))
      |> assign(:outgoing, Friends.list_outgoing_requests(user, page: 1, page_size: 25))
      |> assign(:friends, Friends.list_friends_for_user(user, page: 1, page_size: 25))
      |> assign(:blocked, Friends.list_blocked_for_user(user, page: 1, page_size: 25))
      |> assign(:new_target_id, "")
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:search_page, 1)
      |> assign(:search_page_size, 25)
      |> assign(:search_total, 0)
      |> assign(:search_total_pages, 0)
      |> assign(:kv_page, 1)
      |> assign(:kv_page_size, 50)
      |> assign(:kv_key_filter, nil)
      |> assign(:kv_filter_form, to_form(%{"key" => ""}, as: :filters))
      |> assign(:kv_entries, [])
      |> assign(:kv_count, 0)
      |> assign(:kv_total_pages, 0)

    socket = reload_kv_entries(socket)

    if connected?(socket) do
      Friends.subscribe_user(user.id)
    end

    {:ok, socket}
  end

  @impl true
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def handle_event(event, params, socket) do
    user = get_user_from_scope(socket.assigns)

    case {event, params} do
      {"validate_email", %{"user" => user_params}} ->
        email_form =
          user
          |> Accounts.change_user_email(user_params, validate_unique: false)
          |> Map.put(:action, :validate)
          |> to_form()

        {:noreply, assign(socket, email_form: email_form)}

      {"validate_display_name", %{"user" => user_params}} ->
        display_form =
          user
          |> Accounts.change_user_display_name(user_params)
          |> Map.put(:action, :validate)
          |> to_form()

        {:noreply, assign(socket, display_form: display_form)}

      {"search_users", params} ->
        q = params["q"] || ""
        page = socket.assigns.search_page || 1
        page_size = socket.assigns.search_page_size || 25
        results = Accounts.search_users(q, page: page, page_size: page_size)
        total = if q == "", do: 0, else: Accounts.count_search_users(q)
        total_pages = if page_size > 0, do: div(total + page_size - 1, page_size), else: 0

        {:noreply,
         assign(socket,
           search_query: q,
           search_results: results,
           search_total: total,
           search_total_pages: total_pages
         )}

      {"send_friend", params} ->
        target = params["target_id"] || params["target"]
        target_id = if is_binary(target), do: String.to_integer(target), else: target

        case Friends.create_request(user.id, target_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Friend request sent"))
             |> refresh_friend_lists(user)}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Could not send request: %{reason}", reason: inspect(cs.errors))
             )}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Could not send request: %{reason}", reason: inspect(reason))
             )}
        end

      {"block_friend", %{"id" => id}} ->
        id = if is_binary(id), do: String.to_integer(id), else: id

        case Friends.block_friend_request(id, user) do
          {:ok, _} ->
            {:noreply, refresh_friend_lists(socket, user)}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Could not block: %{reason}", reason: inspect(reason))
             )}
        end

      {"search_prev", _} ->
        page = max(1, (socket.assigns.search_page || 1) - 1)
        q = socket.assigns.search_query || ""
        page_size = socket.assigns.search_page_size || 25
        results = Accounts.search_users(q, page: page, page_size: page_size)
        total = if q == "", do: 0, else: Accounts.count_search_users(q)
        total_pages = if page_size > 0, do: div(total + page_size - 1, page_size), else: 0

        {:noreply,
         assign(socket,
           search_page: page,
           search_results: results,
           search_total: total,
           search_total_pages: total_pages
         )}

      {"search_next", _} ->
        page = (socket.assigns.search_page || 1) + 1
        q = socket.assigns.search_query || ""
        page_size = socket.assigns.search_page_size || 25
        results = Accounts.search_users(q, page: page, page_size: page_size)
        total = if q == "", do: 0, else: Accounts.count_search_users(q)
        total_pages = if page_size > 0, do: div(total + page_size - 1, page_size), else: 0

        {:noreply,
         assign(socket,
           search_page: page,
           search_results: results,
           search_total: total,
           search_total_pages: total_pages
         )}

      {"kv_prev", _} ->
        page = max(1, (socket.assigns.kv_page || 1) - 1)

        {:noreply, socket |> assign(:kv_page, page) |> reload_kv_entries()}

      {"kv_next", _} ->
        page = (socket.assigns.kv_page || 1) + 1

        {:noreply, socket |> assign(:kv_page, page) |> reload_kv_entries()}

      {"kv_filters_change", %{"filters" => params}} ->
        socket = assign(socket, :kv_filter_form, to_form(params, as: :filters))
        key = (Map.get(params, "key") || "") |> String.trim()
        key = if key == "", do: nil, else: String.downcase(key)

        {:noreply,
         socket |> assign(:kv_key_filter, key) |> assign(:kv_page, 1) |> reload_kv_entries()}

      {"kv_filters_apply", %{"filters" => params}} ->
        socket = assign(socket, :kv_filter_form, to_form(params, as: :filters))
        key = (Map.get(params, "key") || "") |> String.trim()
        key = if key == "", do: nil, else: String.downcase(key)

        {:noreply,
         socket |> assign(:kv_key_filter, key) |> assign(:kv_page, 1) |> reload_kv_entries()}

      {"kv_filters_clear", _} ->
        {:noreply,
         socket
         |> assign(:kv_key_filter, nil)
         |> assign(:kv_filter_form, to_form(%{"key" => ""}, as: :filters))
         |> assign(:kv_page, 1)
         |> reload_kv_entries()}

      {"accept_friend", %{"id" => id}} ->
        id = if is_binary(id), do: String.to_integer(id), else: id

        case Friends.accept_friend_request(id, user) do
          {:ok, _} ->
            {:noreply, refresh_friend_lists(socket, user)}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Could not accept: %{reason}", reason: inspect(reason))
             )}
        end

      {"reject_friend", %{"id" => id}} ->
        id = if is_binary(id), do: String.to_integer(id), else: id

        case Friends.reject_friend_request(id, user) do
          {:ok, _} ->
            {:noreply, refresh_friend_lists(socket, user)}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Could not reject: %{reason}", reason: inspect(reason))
             )}
        end

      {"cancel_friend", %{"id" => id}} ->
        id = if is_binary(id), do: String.to_integer(id), else: id

        case Friends.cancel_request(id, user) do
          {:ok, _} ->
            {:noreply, refresh_friend_lists(socket, user)}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Could not cancel: %{reason}", reason: inspect(reason))
             )}
        end

      {"remove_friend", %{"friend_id" => fid}} ->
        fid = if is_binary(fid), do: String.to_integer(fid), else: fid

        case Friends.remove_friend(user.id, fid) do
          {:ok, _} ->
            {:noreply, refresh_friend_lists(socket, user)}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Could not remove: %{reason}", reason: inspect(reason))
             )}
        end

      {"unblock_friend", %{"id" => id}} ->
        id = if is_binary(id), do: String.to_integer(id), else: id

        case Friends.unblock_friendship(id, user) do
          {:ok, :unblocked} ->
            {:noreply, refresh_friend_lists(socket, user)}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Could not unblock: %{reason}", reason: inspect(reason))
             )}
        end

      {"update_email", %{"user" => user_params}} ->
        case Accounts.change_user_email(user, user_params) do
          %{valid?: true} = changeset ->
            Accounts.deliver_user_update_email_instructions(
              Ecto.Changeset.apply_action!(changeset, :insert),
              user.email,
              &url(~p"/users/settings/confirm-email/#{&1}")
            )

            info =
              gettext("A link to confirm your email change has been sent to the new address.")

            {:noreply, socket |> put_flash(:info, info)}

          changeset ->
            {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
        end

      {"update_display_name", %{"user" => user_params}} ->
        case Accounts.update_user_display_name(user, user_params) do
          {:ok, user} ->
            {:noreply,
             socket |> put_flash(:info, gettext("Display name updated.")) |> assign(:user, user)}

          {:error, changeset} ->
            {:noreply, assign(socket, display_form: to_form(changeset, action: :insert))}
        end

      {"validate_password", %{"user" => user_params}} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params, hash_password: false)
          |> Map.put(:action, :validate)
          |> to_form()

        {:noreply, assign(socket, password_form: password_form)}

      {"update_password", %{"user" => user_params}} ->
        case Accounts.change_user_password(user, user_params) do
          %{valid?: true} = changeset ->
            {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

          changeset ->
            {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
        end

      {"unlink_provider", %{"provider" => provider}} ->
        provider_atom = String.to_existing_atom(provider)

        case Accounts.unlink_provider(user, provider_atom) do
          {:ok, user} ->
            {:noreply,
             socket
             |> put_flash(
               :info,
               gettext("Successfully unlinked %{provider}.",
                 provider: String.capitalize(provider)
               )
             )
             |> assign(:user, user)}

          {:error, :last_provider} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               gettext(
                 "Cannot unlink the last linked social provider (you must have at least one social login connected)."
               )
             )}

          {:error, _} ->
            {:noreply, socket |> put_flash(:error, gettext("Failed to unlink provider."))}
        end

      {"delete_user", _} ->
        case Accounts.delete_user(user) do
          {:ok, _deleted_user} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Your account has been deleted successfully."))
             |> redirect(to: ~p"/")}

          {:error, _changeset} ->
            {:noreply,
             put_flash(socket, :error, gettext("Failed to delete account. Please try again."))}
        end

      {"delete_conflicting_account", %{"id" => id}} ->
        current = user

        other_user =
          case Integer.parse(id) do
            {id, ""} -> Accounts.get_user(id)
            _ -> nil
          end

        case other_user do
          %GameServer.Accounts.User{} = other_user ->
            handle_delete_conflicting_account(socket, current, other_user)

          _ ->
            {:noreply, put_flash(socket, :error, gettext("Account not found."))}
        end

      {"incoming_prev", _} ->
        page = max(1, (socket.assigns.incoming_page || 1) - 1)

        {:noreply,
         socket
         |> assign(incoming_page: page)
         |> refresh_friend_lists(get_user_from_scope(socket.assigns))}

      {"incoming_next", _} ->
        page = (socket.assigns.incoming_page || 1) + 1

        {:noreply,
         socket
         |> assign(incoming_page: page)
         |> refresh_friend_lists(get_user_from_scope(socket.assigns))}

      {"outgoing_prev", _} ->
        page = max(1, (socket.assigns.outgoing_page || 1) - 1)

        {:noreply,
         socket
         |> assign(outgoing_page: page)
         |> refresh_friend_lists(get_user_from_scope(socket.assigns))}

      {"outgoing_next", _} ->
        page = (socket.assigns.outgoing_page || 1) + 1

        {:noreply,
         socket
         |> assign(outgoing_page: page)
         |> refresh_friend_lists(get_user_from_scope(socket.assigns))}

      {"friends_prev", _} ->
        page = max(1, (socket.assigns.friends_page || 1) - 1)

        {:noreply,
         socket
         |> assign(friends_page: page)
         |> refresh_friend_lists(get_user_from_scope(socket.assigns))}

      {"friends_next", _} ->
        page = (socket.assigns.friends_page || 1) + 1

        {:noreply,
         socket
         |> assign(friends_page: page)
         |> refresh_friend_lists(get_user_from_scope(socket.assigns))}

      {"blocked_prev", _} ->
        page = max(1, (socket.assigns.blocked_page || 1) - 1)

        {:noreply,
         socket
         |> assign(blocked_page: page)
         |> refresh_friend_lists(get_user_from_scope(socket.assigns))}

      {"blocked_next", _} ->
        page = (socket.assigns.blocked_page || 1) + 1

        {:noreply,
         socket
         |> assign(blocked_page: page)
         |> refresh_friend_lists(get_user_from_scope(socket.assigns))}

      _ ->
        {:noreply, socket}
    end
  end

  defp refresh_friend_lists(socket, user) do
    incoming_page = socket.assigns.incoming_page || 1
    incoming_page_size = socket.assigns.incoming_page_size || 25
    outgoing_page = socket.assigns.outgoing_page || 1
    outgoing_page_size = socket.assigns.outgoing_page_size || 25
    friends_page = socket.assigns.friends_page || 1
    friends_page_size = socket.assigns.friends_page_size || 25
    blocked_page = socket.assigns.blocked_page || 1
    blocked_page_size = socket.assigns.blocked_page_size || 25

    incoming =
      Friends.list_incoming_requests(user, page: incoming_page, page_size: incoming_page_size)

    outgoing =
      Friends.list_outgoing_requests(user, page: outgoing_page, page_size: outgoing_page_size)

    friends =
      Friends.list_friends_for_user(user, page: friends_page, page_size: friends_page_size)

    blocked =
      Friends.list_blocked_for_user(user, page: blocked_page, page_size: blocked_page_size)

    incoming_total = Friends.count_incoming_requests(user)
    outgoing_total = Friends.count_outgoing_requests(user)
    friends_total = Friends.count_friends_for_user(user)
    blocked_total = Friends.count_blocked_for_user(user)

    incoming_total_pages =
      if incoming_page_size > 0,
        do: div(incoming_total + incoming_page_size - 1, incoming_page_size),
        else: 0

    outgoing_total_pages =
      if outgoing_page_size > 0,
        do: div(outgoing_total + outgoing_page_size - 1, outgoing_page_size),
        else: 0

    friends_total_pages =
      if friends_page_size > 0,
        do: div(friends_total + friends_page_size - 1, friends_page_size),
        else: 0

    blocked_total_pages =
      if blocked_page_size > 0,
        do: div(blocked_total + blocked_page_size - 1, blocked_page_size),
        else: 0

    assign(socket,
      incoming: incoming,
      outgoing: outgoing,
      friends: friends,
      blocked: blocked,
      incoming_total: incoming_total,
      outgoing_total: outgoing_total,
      friends_total: friends_total,
      blocked_total: blocked_total,
      incoming_total_pages: incoming_total_pages,
      outgoing_total_pages: outgoing_total_pages,
      friends_total_pages: friends_total_pages,
      blocked_total_pages: blocked_total_pages
    )
  end

  defp reload_kv_entries(socket) do
    page = socket.assigns.kv_page || 1
    page_size = socket.assigns.kv_page_size || 50
    key = socket.assigns.kv_key_filter
    user = socket.assigns.user

    entries = KV.list_entries(page: page, page_size: page_size, key: key, user_id: user.id)
    count = KV.count_entries(key: key, user_id: user.id)
    total_pages = if page_size > 0, do: div(count + page_size - 1, page_size), else: 0

    socket
    |> assign(:kv_entries, entries)
    |> assign(:kv_count, count)
    |> assign(:kv_total_pages, total_pages)
    |> clamp_kv_page()
  end

  defp clamp_kv_page(socket) do
    page = socket.assigns.kv_page
    total_pages = socket.assigns.kv_total_pages

    page =
      cond do
        total_pages == 0 -> 1
        page < 1 -> 1
        page > total_pages -> total_pages
        true -> page
      end

    assign(socket, :kv_page, page)
  end

  defp json_preview(nil), do: ""

  defp json_preview(map) when is_map(map) do
    Jason.encode!(map)
    |> String.slice(0, 2048)
  end

  defp json_preview(_), do: ""

  defp get_user_from_scope(%{current_scope: %{user: user}}), do: user
  defp get_user_from_scope(_), do: nil

  # PubSub handlers
  @impl true
  def handle_info({:incoming_request, _f}, socket) do
    user = get_user_from_scope(socket.assigns)
    {:noreply, refresh_friend_lists(socket, user)}
  end

  def handle_info({:outgoing_request, _f}, socket) do
    user = get_user_from_scope(socket.assigns)
    {:noreply, refresh_friend_lists(socket, user)}
  end

  def handle_info({:friend_accepted, _f}, socket),
    do: {:noreply, refresh_friend_lists(socket, get_user_from_scope(socket.assigns))}

  def handle_info({:friend_rejected, _f}, socket),
    do: {:noreply, refresh_friend_lists(socket, get_user_from_scope(socket.assigns))}

  def handle_info({:friend_blocked, _f}, socket),
    do: {:noreply, refresh_friend_lists(socket, get_user_from_scope(socket.assigns))}

  def handle_info({:request_cancelled, _f}, socket),
    do: {:noreply, refresh_friend_lists(socket, get_user_from_scope(socket.assigns))}

  def handle_info({:friend_removed, _f}, socket),
    do: {:noreply, refresh_friend_lists(socket, get_user_from_scope(socket.assigns))}

  def handle_info({:friend_unblocked, _f}, socket),
    do:
      {:noreply,
       refresh_friend_lists(socket, get_user_from_scope(socket.assigns))
       |> assign(:blocked, Friends.list_blocked_for_user(get_user_from_scope(socket.assigns)))}

  ## handle_params is implemented after event handlers to keep handle_event/3
  ## clauses grouped together (avoid compile warnings about grouping clauses).

  @impl true
  def handle_params(params, _url, socket) do
    conflict_user =
      case params do
        %{"conflict_user_id" => id} when is_binary(id) ->
          case Integer.parse(id) do
            {id, ""} -> Accounts.get_user(id)
            _ -> nil
          end

        _ ->
          nil
      end

    conflict_provider = Map.get(params, "conflict_provider")

    {:noreply, assign(socket, conflict_user: conflict_user, conflict_provider: conflict_provider)}
  end

  defp handle_delete_conflicting_account(socket, current, other_user) do
    current_email = (current.email || "") |> String.downcase()
    other_email = (other_user.email || "") |> String.downcase()

    cond do
      other_user.id == current.id ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "You cannot delete your currently logged-in account here."
         )}

      other_email == current_email and other_email != "" ->
        perform_conflicting_account_deletion(socket, other_user)

      other_user.hashed_password == nil ->
        perform_conflicting_account_deletion(socket, other_user)

      true ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Cannot delete an account you do not own. Log in to the other account directly if you control it."
         )}
    end
  end

  defp perform_conflicting_account_deletion(socket, user) do
    case Accounts.delete_user(user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Conflicting account deleted. You can now try linking the provider again."
         )
         |> assign(:conflict_user, nil)}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, gettext("Failed to delete the conflicting account."))}
    end
  end
end
