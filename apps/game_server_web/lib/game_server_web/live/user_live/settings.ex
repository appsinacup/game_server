defmodule GameServerWeb.UserLive.Settings do
  use GameServerWeb, :live_view

  alias GameServer.Accounts
  alias GameServer.Friends
  alias GameServer.Groups
  alias GameServer.Groups.Group
  alias GameServer.KV
  alias GameServer.Notifications

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="text-center">
        <%= if @conflict_user do %>
          <div class="divider" />

          <div class="card bg-warning/10 border-warning p-4 rounded-lg">
            <div class="flex items-start justify-between">
              <div>
                <strong>{dgettext("settings", "Conflict detected")}</strong>
                <div class="text-sm text-base-content/70">
                  {dgettext(
                    "settings",
                    "The %{provider} account (ID: %{id}) is already linked to another account. If this is another account you own (matching email), you may delete it below to free the provider so you can link it to this account.",
                    provider: @conflict_provider,
                    id: @conflict_user.id
                  )}
                </div>
              </div>
              <div class="flex items-center gap-2">
                <button
                  phx-click="delete_conflicting_account"
                  phx-value-id={@conflict_user.id}
                  class="btn btn-error btn-sm"
                  data-confirm={
                    dgettext("settings", "Delete the conflicting account? This is irreversible.")
                  }
                >
                  {dgettext("settings", "Delete account")}
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Settings tabs --%>
      <div class="mt-6 flex gap-1 border-b border-base-300 pb-0 overflow-x-auto">
        <button
          :for={
            {tab, label, icon} <- [
              {"account", dgettext("settings", "Account"), "hero-user-circle"},
              {"friends", dgettext("settings", "Friends"), "hero-user-group"},
              {"data", dgettext("settings", "Data"), "hero-circle-stack"},
              {"notifications", dgettext("settings", "Notifications"), "hero-bell"},
              {"groups", dgettext("groups", "Groups"), "hero-users"}
            ]
          }
          phx-click="settings_tab"
          phx-value-tab={tab}
          class={[
            "px-4 py-2.5 text-sm font-medium rounded-t-lg transition-colors flex items-center gap-2 whitespace-nowrap",
            if(@settings_tab == tab,
              do: "bg-primary text-primary-content shadow-sm",
              else: "text-base-content/60 hover:text-base-content hover:bg-base-200/50"
            )
          ]}
        >
          <.icon name={icon} class="w-4 h-4" />
          {label}
        </button>
      </div>

      <%!-- Account tab --%>
      <div :if={@settings_tab == "account"}>
        <div class="mt-6 grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="card bg-base-200 p-4 rounded-lg">
            <div class="font-semibold">{dgettext("settings", "Account details")}</div>
            <div class="text-sm mt-2 space-y-1 text-base-content/80">
              <div><strong>{dgettext("settings", "ID:")}</strong> {@user.id}</div>
              <div><strong>{dgettext("settings", "Email:")}</strong> {@current_email}</div>

              <.form
                for={@display_form}
                id="display_form"
                phx-change="validate_display_name"
                phx-submit="update_display_name"
              >
                <.input
                  field={@display_form[:display_name]}
                  type="text"
                  label={dgettext("settings", "Display name")}
                  required
                />
                <.button variant="primary" phx-disable-with={gettext("Saving...")}>
                  {gettext("Save")}
                </.button>
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
                  label={gettext("Email")}
                  autocomplete="username"
                  required
                />
                <.button variant="primary" phx-disable-with={dgettext("settings", "Changing...")}>
                  {dgettext("settings", "Change Email")}
                </.button>
              </.form>
            </div>
          </div>

          <div class="card bg-base-200 p-4 rounded-lg">
            <div class="font-semibold">{dgettext("settings", "Metadata")}</div>
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
                label={dgettext("settings", "New password")}
                autocomplete="new-password"
                required
              />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label={dgettext("settings", "Confirm new password")}
                autocomplete="new-password"
              />
              <.button variant="primary" phx-disable-with={gettext("Saving...")}>
                {gettext("Save")}
              </.button>
            </.form>
          </div>
        </div>

        <div class="card bg-base-200 p-4 rounded-lg mt-6">
          <div class="font-semibold">{dgettext("settings", "Linked Accounts")}</div>
          <div class="mt-2 grid grid-cols-1 md:grid-cols-2 gap-4">
            <% provider_count =
              Enum.count(
                [
                  @user.discord_id,
                  @user.apple_id,
                  @user.google_id,
                  @user.facebook_id,
                  @user.steam_id
                ],
                fn v ->
                  v && v != ""
                end
              ) %>

            <div class="flex items-center justify-between">
              <div>
                <strong>{dgettext("settings", "Discord")}</strong>
                <div class="text-sm text-base-content/70">
                  {dgettext("settings", "Sign in and link")}
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
                      {dgettext("settings", "Unlink")}
                    </button>
                  <% else %>
                    <button class="btn btn-disabled btn-sm" disabled aria-disabled>
                      {dgettext("settings", "Unlink")}
                    </button>
                  <% end %>
                <% else %>
                  <.link href={~p"/auth/discord"} class="btn btn-primary btn-sm">
                    {dgettext("settings", "Link")}
                  </.link>
                <% end %>
              </div>
            </div>

            <div class="flex items-center justify-between">
              <div>
                <strong>{dgettext("settings", "Google")}</strong>
                <div class="text-sm text-base-content/70">
                  {dgettext("settings", "Sign in and link")}
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
                      {dgettext("settings", "Unlink")}
                    </button>
                  <% else %>
                    <button class="btn btn-disabled btn-sm" disabled aria-disabled>
                      {dgettext("settings", "Unlink")}
                    </button>
                  <% end %>
                <% else %>
                  <.link href={~p"/auth/google"} class="btn btn-primary btn-sm">
                    {dgettext("settings", "Link")}
                  </.link>
                <% end %>
              </div>
            </div>

            <div class="flex items-center justify-between">
              <div>
                <strong>{dgettext("settings", "Facebook")}</strong>
                <div class="text-sm text-base-content/70">
                  {dgettext("settings", "Sign in and link")}
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
                      {dgettext("settings", "Unlink")}
                    </button>
                  <% else %>
                    <button class="btn btn-disabled btn-sm" disabled aria-disabled>
                      {dgettext("settings", "Unlink")}
                    </button>
                  <% end %>
                <% else %>
                  <.link href={~p"/auth/facebook"} class="btn btn-primary btn-sm">
                    {dgettext("settings", "Link")}
                  </.link>
                <% end %>
              </div>
            </div>

            <div class="flex items-center justify-between">
              <div>
                <strong>{dgettext("settings", "Apple")}</strong>
                <div class="text-sm text-base-content/70">
                  {dgettext("settings", "Sign in and link")}
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
                      {dgettext("settings", "Unlink")}
                    </button>
                  <% else %>
                    <button class="btn btn-disabled btn-sm" disabled aria-disabled>
                      {dgettext("settings", "Unlink")}
                    </button>
                  <% end %>
                <% else %>
                  <.link href={~p"/auth/apple"} class="btn btn-primary btn-sm">
                    {dgettext("settings", "Link")}
                  </.link>
                <% end %>
              </div>
            </div>

            <div class="flex items-center justify-between">
              <div>
                <strong>{dgettext("settings", "Steam")}</strong>
                <div class="text-sm text-base-content/70">
                  {dgettext("settings", "Sign in and link")}
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
                      {dgettext("settings", "Unlink")}
                    </button>
                  <% else %>
                    <button class="btn btn-disabled btn-sm" disabled aria-disabled>
                      {dgettext("settings", "Unlink")}
                    </button>
                  <% end %>
                <% else %>
                  <.link href={~p"/auth/steam"} class="btn btn-primary btn-sm">
                    {dgettext("settings", "Link")}
                  </.link>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <div class="card bg-error/10 border-error p-4 rounded-lg mt-6">
          <div class="font-semibold text-error">{dgettext("settings", "Danger Zone")}</div>
          <div class="text-sm mt-2 text-base-content/80">
            <p>
              {dgettext(
                "settings",
                "Once you delete your account, there is no going back. Please be certain."
              )}
            </p>
            <p class="mt-2">
              {dgettext(
                "settings",
                "For information about what data is deleted and how to request deletion, see our"
              )} <.link
                href={~p"/data-deletion"}
                class="link link-primary"
              >{dgettext("settings", "Data Deletion Policy")}</.link>.
            </p>
          </div>
          <div class="mt-4">
            <button
              phx-click="delete_user"
              class="btn btn-error"
              data-confirm={
                dgettext(
                  "settings",
                  "Are you sure you want to delete your account? This action cannot be undone."
                )
              }
            >
              {dgettext("settings", "Delete Account")}
            </button>
          </div>
        </div>
      </div>

      <%!-- Friends tab --%>
      <div :if={@settings_tab == "friends"}>
        <!-- Friends panel (embedded) -->
        <div class="card bg-base-200 p-4 rounded-lg mt-6">
          <div class="flex items-center justify-between">
            <div>
              <div class="font-semibold text-lg">{dgettext("settings", "Friends")}</div>
            </div>
          </div>

          <div class="mt-4 grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <h4 class="font-semibold">{dgettext("settings", "Incoming Requests")}</h4>
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
                  <button
                    phx-click="accept_friend"
                    phx-value-id={req.id}
                    class="btn btn-sm btn-primary"
                  >
                    {gettext("Accept")}
                  </button>
                  <button phx-click="reject_friend" phx-value-id={req.id} class="btn btn-sm btn-error">
                    {gettext("Reject")}
                  </button>
                  <button
                    phx-click="block_friend"
                    phx-value-id={req.id}
                    class="btn btn-sm btn-outline btn-error"
                  >
                    {gettext("Block")}
                  </button>
                </div>
              </div>

              <div :if={@incoming_total_pages > 1} class="mt-2 flex gap-2 items-center">
                <button phx-click="incoming_prev" class="btn btn-xs" disabled={@incoming_page <= 1}>
                  {gettext("Prev")}
                </button>
                <div class="text-xs text-base-content/70">
                  page {@incoming_page} / {@incoming_total_pages} ({@incoming_total} total)
                </div>
                <button
                  phx-click="incoming_next"
                  class="btn btn-xs"
                  disabled={@incoming_page >= @incoming_total_pages || @incoming_total_pages == 0}
                >
                  {gettext("Next")}
                </button>
              </div>
            </div>

            <div>
              <h4 class="font-semibold">{dgettext("settings", "Outgoing Requests")}</h4>
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
                    {gettext("Cancel")}
                  </button>
                </div>
              </div>
              <div :if={@outgoing_total_pages > 1} class="mt-2 flex gap-2 items-center">
                <button phx-click="outgoing_prev" class="btn btn-xs" disabled={@outgoing_page <= 1}>
                  {gettext("Prev")}
                </button>
                <div class="text-xs text-base-content/70">
                  page {@outgoing_page} / {@outgoing_total_pages} ({@outgoing_total} total)
                </div>
                <button
                  phx-click="outgoing_next"
                  class="btn btn-xs"
                  disabled={@outgoing_page >= @outgoing_total_pages || @outgoing_total_pages == 0}
                >
                  {gettext("Next")}
                </button>
              </div>
            </div>

            <div>
              <h4 class="font-semibold">{dgettext("settings", "Friends")}</h4>
              <div
                :for={u <- @friends}
                id={"friend-" <> Integer.to_string(u.id)}
                class="p-2 border rounded mt-2"
              >
                <div class="flex justify-between items-center gap-2">
                  <div class="text-sm flex items-center gap-2">
                    <span
                      class={[
                        "inline-block w-2 h-2 rounded-full shrink-0",
                        if(u.is_online, do: "bg-green-500", else: "bg-gray-400")
                      ]}
                      title={if(u.is_online, do: "Online", else: "Offline")}
                    />
                    {u.display_name || u.email}
                    <span class="text-xs text-base-content/60">(id: {u.id})</span>
                  </div>
                  <button
                    phx-click="remove_friend"
                    phx-value-friend_id={u.id}
                    class="btn btn-sm btn-error btn-outline"
                  >
                    {gettext("Remove")}
                  </button>
                </div>
              </div>
              <div :if={@friends_total_pages > 1} class="mt-2 flex gap-2 items-center">
                <button phx-click="friends_prev" class="btn btn-xs" disabled={@friends_page <= 1}>
                  {gettext("Prev")}
                </button>
                <div class="text-xs text-base-content/70">
                  page {@friends_page} / {@friends_total_pages} ({@friends_total} total)
                </div>
                <button
                  phx-click="friends_next"
                  class="btn btn-xs"
                  disabled={@friends_page >= @friends_total_pages || @friends_total_pages == 0}
                >
                  {gettext("Next")}
                </button>
              </div>
            </div>
          </div>

          <div class="divider mt-4" />

          <div class="mt-2">
            <div :if={length(@blocked) > 0} class="mt-4">
              <div class="text-xs text-base-content/70">{dgettext("settings", "Blocked users")}</div>
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
                  <button
                    phx-click="unblock_friend"
                    phx-value-id={b.id}
                    class="btn btn-xs btn-outline"
                  >
                    {gettext("Unblock")}
                  </button>
                </div>
              </div>
              <div :if={@blocked_total_pages > 1} class="mt-2 flex gap-2 items-center">
                <button phx-click="blocked_prev" class="btn btn-xs" disabled={@blocked_page <= 1}>
                  {gettext("Prev")}
                </button>
                <div class="text-xs text-base-content/70">
                  page {@blocked_page} / {@blocked_total_pages} ({@blocked_total} total)
                </div>
                <button
                  phx-click="blocked_next"
                  class="btn btn-xs"
                  disabled={@blocked_page >= @blocked_total_pages || @blocked_total_pages == 0}
                >
                  {gettext("Next")}
                </button>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <form phx-change="search_users" class="w-full">
                <input
                  type="text"
                  name="q"
                  value={@search_query}
                  placeholder={gettext("Search...")}
                  class="input"
                />
              </form>
            </div>
            <div :if={length(@search_results) > 0} class="mt-3">
              <div class="text-xs text-base-content/70 mb-2">
                {dgettext("settings", "Search results")}
              </div>
              
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
                        {gettext("Send")}
                      </button>
                    </div>
                  </div>
                </div>
              </div>
              <div :if={@search_total_pages > 1} class="mt-2 flex gap-2 items-center">
                <button phx-click="search_prev" class="btn btn-xs" disabled={@search_page <= 1}>
                  {gettext("Prev")}
                </button>
                <div class="text-xs text-base-content/70">
                  page {@search_page} / {@search_total_pages} ({@search_total} total)
                </div>
                <button
                  phx-click="search_next"
                  class="btn btn-xs"
                  disabled={@search_page >= @search_total_pages || @search_total_pages == 0}
                >
                  {gettext("Next")}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Data tab --%>
      <div :if={@settings_tab == "data"}>
        <div class="card bg-base-200 p-4 rounded-lg mt-6">
          <div class="flex items-center justify-between">
            <div>
              <div class="font-semibold text-lg">{dgettext("settings", "Data")}</div>
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
                  label={dgettext("settings", "Key contains")}
                  phx-debounce="300"
                />
              </div>
              <div class="flex gap-2 mt-2">
                <button type="submit" class="btn btn-sm btn-outline">{gettext("Apply")}</button>
                <button type="button" phx-click="kv_filters_clear" class="btn btn-sm btn-ghost">
                  {gettext("Clear")}
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
                  <th class="w-16">{gettext("ID")}</th>
                  <th class="font-mono text-sm break-all">{dgettext("settings", "Key")}</th>
                  <th class="w-40">{dgettext("settings", "Updated")}</th>
                  <th>{dgettext("settings", "Value")}</th>
                  <th>{dgettext("settings", "Metadata")}</th>
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
            <button phx-click="kv_prev" class="btn btn-xs" disabled={@kv_page <= 1}>
              {gettext("Prev")}
            </button>
            <div class="text-xs text-base-content/70">
              page {@kv_page} / {@kv_total_pages} ({@kv_count} total)
            </div>
            <button
              phx-click="kv_next"
              class="btn btn-xs"
              disabled={@kv_page >= @kv_total_pages || @kv_total_pages == 0}
            >
              {gettext("Next")}
            </button>
          </div>
        </div>
      </div>

      <%!-- Notifications tab --%>
      <div :if={@settings_tab == "notifications"}>
        <%!-- Notifications section --%>
        <div class="card bg-base-200 p-4 rounded-lg mt-6">
          <div class="flex items-center justify-between">
            <div>
              <div class="font-semibold text-lg">{dgettext("settings", "Notifications")}</div>
              <div class="text-sm text-base-content/70">
                {dgettext("settings", "Your notifications (%{count})", count: @notif_count)}
              </div>
            </div>
            <div class="flex gap-2">
              <%= if @notif_count > 0 do %>
                <button
                  type="button"
                  phx-click="delete_all_notifications"
                  data-confirm={dgettext("settings", "Delete all notifications?")}
                  class="btn btn-sm btn-outline btn-error"
                >
                  {dgettext("settings", "Delete All")}
                </button>
              <% end %>
            </div>
          </div>

          <%= if @notif_count == 0 do %>
            <div class="mt-4 text-sm text-base-content/60">{gettext("None yet.")}</div>
          <% else %>
            <div class="overflow-x-auto mt-4">
              <table id="user-notifications-table" class="table table-zebra w-full">
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
                  <tr :for={n <- @notifications} id={"notif-" <> to_string(n.id)}>
                    <td class="text-sm font-semibold">{n.title}</td>
                    <td class="text-sm max-w-xs truncate">{n.content || "-"}</td>
                    <td class="text-sm font-mono">{n.sender_id}</td>
                    <td class="text-sm whitespace-nowrap">
                      {Calendar.strftime(n.inserted_at, "%Y-%m-%d %H:%M")}
                    </td>
                    <td>
                      <button
                        type="button"
                        phx-click="delete_notification"
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
              <button phx-click="notif_prev" class="btn btn-xs" disabled={@notif_page <= 1}>
                {gettext("Prev")}
              </button>
              <div class="text-xs text-base-content/70">
                page {@notif_page} / {@notif_total_pages} ({@notif_count} total)
              </div>
              <button
                phx-click="notif_next"
                class="btn btn-xs"
                disabled={@notif_page >= @notif_total_pages || @notif_total_pages == 0}
              >
                {gettext("Next")}
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Groups tab --%>
      <div :if={@settings_tab == "groups"}>
        <%!-- Groups section --%>
        <div class="card bg-base-200 p-4 rounded-lg mt-6">
          <div class="flex items-center justify-between">
            <div>
              <div class="font-semibold text-lg">{dgettext("groups", "Groups")}</div>
            </div>
            <div class="flex gap-2">
              <%= if @group_detail do %>
                <button phx-click="group_close_detail" class="btn btn-sm btn-ghost">
                  <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back")}
                </button>
              <% end %>
              <button
                phx-click="groups_toggle_create"
                class={[
                  "btn btn-sm",
                  if(@groups_show_create, do: "btn-ghost", else: "btn-primary")
                ]}
              >
                <%= if @groups_show_create do %>
                  {gettext("Cancel")}
                <% else %>
                  {gettext("Create")}
                <% end %>
              </button>
            </div>
          </div>

          <%!-- Create group form --%>
          <%= if @groups_show_create do %>
            <div class="mt-4 border border-base-300 rounded-lg p-4 bg-base-100">
              <div class="font-semibold text-sm mb-3">{dgettext("settings", "New Group")}</div>
              <.form
                for={@create_group_form}
                id="create-group-form"
                phx-change="group_validate_create"
                phx-submit="group_create"
              >
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <.input
                    field={@create_group_form[:title]}
                    type="text"
                    label={gettext("Title")}
                    required
                  />
                  <.input
                    field={@create_group_form[:description]}
                    type="text"
                    label={gettext("Description")}
                  />
                  <.input
                    field={@create_group_form[:type]}
                    type="select"
                    label={gettext("Type")}
                    options={[
                      {gettext("Public"), "public"},
                      {gettext("Private"), "private"},
                      {gettext("Hidden"), "hidden"}
                    ]}
                  />
                  <.input
                    field={@create_group_form[:max_members]}
                    type="number"
                    label={dgettext("settings", "Max members")}
                  />
                </div>
                <div class="mt-3">
                  <button type="submit" class="btn btn-sm btn-primary">
                    {gettext("Create")}
                  </button>
                </div>
              </.form>
            </div>
          <% end %>

          <%!-- Group Detail View --%>
          <%= if @group_detail && !@groups_show_create do %>
            <div class="mt-4">
              <%!-- Edit form (admin only) --%>
              <%= if @group_editing && @group_detail_role == "admin" do %>
                <.form
                  for={@group_edit_form}
                  id="group-edit-form"
                  phx-change="group_validate_edit"
                  phx-submit="group_save_edit"
                  class="space-y-3"
                >
                  <.input field={@group_edit_form[:title]} label={gettext("Name")} type="text" />
                  <.input
                    field={@group_edit_form[:description]}
                    label={gettext("Description")}
                    type="textarea"
                  />
                  <.input
                    field={@group_edit_form[:type]}
                    label={gettext("Type")}
                    type="select"
                    options={[
                      {gettext("Public"), "public"},
                      {gettext("Private"), "private"},
                      {gettext("Hidden"), "hidden"}
                    ]}
                  />
                  <.input
                    field={@group_edit_form[:max_members]}
                    label={dgettext("settings", "Max Members")}
                    type="number"
                  />
                  <div class="flex gap-2">
                    <button type="submit" class="btn btn-sm btn-primary">{gettext("Save")}</button>
                    <button
                      type="button"
                      phx-click="group_toggle_edit"
                      class="btn btn-sm btn-ghost"
                    >
                      {gettext("Cancel")}
                    </button>
                  </div>
                </.form>
              <% else %>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="space-y-2 text-sm">
                    <div><strong>{dgettext("settings", "Name:")}</strong> {@group_detail.title}</div>
                    <div>
                      <strong>{dgettext("settings", "Description:")}</strong> {@group_detail.description ||
                        "-"}
                    </div>
                    <div>
                      <strong>{dgettext("settings", "Type:")}</strong>
                      <span class={[
                        "badge badge-sm",
                        cond do
                          @group_detail.type == "public" -> "badge-success"
                          @group_detail.type == "private" -> "badge-warning"
                          true -> "badge-error"
                        end
                      ]}>
                        {@group_detail.type}
                      </span>
                    </div>
                    <div>
                      <strong>{dgettext("settings", "Max Members:")}</strong> {@group_detail.max_members}
                    </div>
                    <div>
                      <strong>{dgettext("settings", "Created:")}</strong> {Calendar.strftime(
                        @group_detail.inserted_at,
                        "%Y-%m-%d %H:%M"
                      )}
                    </div>
                  </div>
                  <div class="space-y-2 text-sm">
                    <div>
                      <strong>{dgettext("settings", "Your Role:")}</strong>
                      <span class={[
                        "badge badge-sm",
                        if(@group_detail_role == "admin", do: "badge-info", else: "badge-ghost")
                      ]}>
                        {@group_detail_role || dgettext("settings", "not a member")}
                      </span>
                    </div>
                    <div class="flex gap-2">
                      <button
                        :if={@group_detail_role == "admin"}
                        phx-click="group_toggle_edit"
                        class="btn btn-xs btn-outline btn-info"
                      >
                        {dgettext("settings", "Edit Group")}
                      </button>
                      <button
                        phx-click="group_leave"
                        phx-value-group_id={@group_detail.id}
                        class="btn btn-xs btn-outline btn-error"
                        data-confirm={dgettext("settings", "Leave this group?")}
                      >
                        {dgettext("groups", "Leave Group")}
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>

              <%!-- Members list --%>
              <div class="mt-4">
                <div class="font-semibold text-sm">{gettext("Members")} ({@group_members_total})</div>
                <div class="overflow-x-auto mt-2">
                  <table id="group-members-table" class="table table-zebra w-full">
                    <thead>
                      <tr>
                        <th></th>
                        <th>{gettext("Name")}</th>
                        <th>{gettext("Email")}</th>
                        <th>{gettext("Role")}</th>
                        <th>{gettext("Joined")}</th>
                        <%= if @group_detail_role == "admin" do %>
                          <th>{gettext("Actions")}</th>
                        <% end %>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        :for={m <- @group_members}
                        id={"gm-" <> to_string(m.id)}
                      >
                        <td>
                          <span
                            class={[
                              "inline-block w-2 h-2 rounded-full",
                              if(m.user.is_online, do: "bg-green-500", else: "bg-gray-400")
                            ]}
                            title={if(m.user.is_online, do: "Online", else: "Offline")}
                          />
                        </td>
                        <td class="text-sm">{m.user.display_name || "User #{m.user_id}"}</td>
                        <td class="text-sm text-base-content/70">{m.user.email}</td>
                        <td>
                          <span class={[
                            "badge badge-sm",
                            if(m.role == "admin", do: "badge-info", else: "badge-ghost")
                          ]}>
                            {m.role}
                          </span>
                        </td>
                        <td class="text-sm whitespace-nowrap">
                          {Calendar.strftime(m.inserted_at, "%Y-%m-%d %H:%M")}
                        </td>
                        <%= if @group_detail_role == "admin" do %>
                          <td class="flex gap-1">
                            <%= if m.user_id != @user.id do %>
                              <%= if m.role == "member" do %>
                                <button
                                  phx-click="group_promote"
                                  phx-value-group_id={@group_detail.id}
                                  phx-value-user_id={m.user_id}
                                  class="btn btn-xs btn-outline btn-primary"
                                >
                                  {gettext("Promote")}
                                </button>
                              <% else %>
                                <button
                                  phx-click="group_demote"
                                  phx-value-group_id={@group_detail.id}
                                  phx-value-user_id={m.user_id}
                                  class="btn btn-xs btn-outline btn-warning"
                                >
                                  {gettext("Demote")}
                                </button>
                              <% end %>
                              <button
                                phx-click="group_kick"
                                phx-value-group_id={@group_detail.id}
                                phx-value-user_id={m.user_id}
                                class="btn btn-xs btn-outline btn-error"
                                data-confirm={
                                  dgettext("groups", "Kick %{name}?",
                                    name: m.user.display_name || m.user.email
                                  )
                                }
                              >
                                {gettext("Kick")}
                              </button>
                            <% else %>
                              <span class="text-xs text-base-content/50">{gettext("You")}</span>
                            <% end %>
                          </td>
                        <% end %>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <div :if={@group_members_total_pages > 1} class="mt-2 flex gap-2 items-center">
                  <button
                    phx-click="group_members_prev"
                    class="btn btn-xs"
                    disabled={@group_members_page <= 1}
                  >
                    {gettext("Prev")}
                  </button>
                  <div class="text-xs text-base-content/70">
                    page {@group_members_page} / {@group_members_total_pages} ({@group_members_total} total)
                  </div>
                  <button
                    phx-click="group_members_next"
                    class="btn btn-xs"
                    disabled={
                      @group_members_page >= @group_members_total_pages ||
                        @group_members_total_pages == 0
                    }
                  >
                    {gettext("Next")}
                  </button>
                </div>
              </div>

              <%!-- Incoming Join Requests (admin only) --%>
              <div :if={@group_detail_role == "admin" && @group_join_requests != []} class="mt-6">
                <h4 class="font-semibold text-base mb-3">
                  {dgettext("settings", "Pending Join Requests")} ({length(@group_join_requests)})
                </h4>
                <div class="space-y-2">
                  <div
                    :for={req <- @group_join_requests}
                    class="flex items-center justify-between p-2 rounded-lg bg-base-200/60"
                  >
                    <div class="flex items-center gap-2">
                      <div class="text-sm font-medium">
                        {req.user.display_name || req.user.email}
                      </div>
                      <span class="text-xs text-base-content/50">
                        #{req.user_id} &mdash; {Calendar.strftime(req.inserted_at, "%Y-%m-%d %H:%M")}
                      </span>
                    </div>
                    <div class="flex gap-1">
                      <button
                        phx-click="group_approve_request"
                        phx-value-request_id={req.id}
                        class="btn btn-xs btn-primary"
                      >
                        {gettext("Approve")}
                      </button>
                      <button
                        phx-click="group_reject_request"
                        phx-value-request_id={req.id}
                        class="btn btn-xs btn-outline btn-error"
                      >
                        {gettext("Reject")}
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Send Notification to Group (any member) --%>
              <div class="mt-6">
                <h4 class="font-semibold text-base mb-3">
                  {dgettext("settings", "Send Notification")}
                </h4>
                <.form
                  for={@group_notify_form}
                  id="group-notify-form"
                  phx-submit="group_notify"
                  class="flex flex-col gap-2"
                >
                  <div class="flex gap-2 items-end">
                    <div class="w-1/3">
                      <.input
                        field={@group_notify_form[:title]}
                        type="text"
                        placeholder={dgettext("settings", "Title (optional)")}
                      />
                    </div>
                    <div class="flex-1">
                      <.input
                        field={@group_notify_form[:content]}
                        type="text"
                        placeholder={dgettext("settings", "Type a message to all members...")}
                      />
                    </div>
                    <button type="submit" class="btn btn-sm btn-primary">
                      <.icon name="hero-megaphone-mini" class="w-4 h-4 mr-1" /> {gettext("Send")}
                    </button>
                  </div>
                </.form>
              </div>

              <%!-- Invite Members (admin only) --%>
              <div :if={@group_detail_role == "admin"} class="mt-6">
                <h4 class="font-semibold text-base mb-3">{dgettext("settings", "Invite Members")}</h4>

                <%!-- Search by name, email, or user ID --%>
                <div class="form-control mb-3">
                  <label class="label">
                    <span class="label-text">{gettext("Search...")}</span>
                  </label>
                  <input
                    id="invite-search-input"
                    type="text"
                    phx-keyup="group_invite_search"
                    phx-debounce="300"
                    value={@invite_search_query}
                    placeholder={dgettext("settings", "Type to search...")}
                    class="input input-bordered input-sm w-full max-w-xs"
                    autocomplete="off"
                  />
                </div>

                <%!-- Search results --%>
                <div :if={@invite_search_results != []} class="mb-4">
                  <div class="text-xs font-medium text-base-content/60 mb-1">
                    {dgettext("settings", "Search Results")}
                  </div>
                  <div class="space-y-1 max-h-48 overflow-y-auto">
                    <div
                      :for={u <- @invite_search_results}
                      class="flex items-center justify-between p-2 rounded-lg bg-base-200/60"
                    >
                      <div class="flex items-center gap-2">
                        <div class={[
                          "w-2 h-2 rounded-full",
                          if(Map.get(u, :is_online, false),
                            do: "bg-success",
                            else: "bg-base-content/30"
                          )
                        ]} />
                        <div>
                          <span class="text-sm font-medium">{u.display_name || u.email}</span>
                          <span class="text-xs text-base-content/50 ml-1">#{u.id}</span>
                        </div>
                      </div>
                      <button
                        phx-click="group_invite_user"
                        phx-value-group_id={@group_detail.id}
                        phx-value-user_id={u.id}
                        class="btn btn-xs btn-primary"
                      >
                        {gettext("Invite")}
                      </button>
                    </div>
                  </div>
                </div>

                <div
                  :if={@invite_search_query != "" && @invite_search_results == []}
                  class="mb-4 text-sm text-base-content/50"
                >
                  {dgettext("settings", "No results for \"%{query}\"", query: @invite_search_query)}
                </div>

                <%!-- Quick invite from friends --%>
                <div :if={@invite_friends != []} class="mt-3">
                  <div class="text-xs font-medium text-base-content/60 mb-1">
                    {dgettext("settings", "Friends not in this group")}
                  </div>
                  <div class="space-y-1 max-h-48 overflow-y-auto">
                    <div
                      :for={f <- @invite_friends}
                      class="flex items-center justify-between p-2 rounded-lg bg-base-200/40"
                    >
                      <div class="flex items-center gap-2">
                        <div class={[
                          "w-2 h-2 rounded-full",
                          if(Map.get(f, :is_online, false),
                            do: "bg-success",
                            else: "bg-base-content/30"
                          )
                        ]} />
                        <span class="text-sm">{f.display_name || f.email}</span>
                      </div>
                      <button
                        phx-click="group_invite_user"
                        phx-value-group_id={@group_detail.id}
                        phx-value-user_id={f.id}
                        class="btn btn-xs btn-outline btn-primary"
                      >
                        {gettext("Invite")}
                      </button>
                    </div>
                  </div>
                </div>

                <div :if={@invite_friends == []} class="mt-3 text-sm text-base-content/40">
                  {dgettext("settings", "All friends are already members.")}
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Tabs (hidden when viewing detail) --%>
          <%= if !@group_detail && !@groups_show_create do %>
            <%!-- Sub-tabs --%>
            <div class="flex gap-2 mt-4 border-b border-base-300 pb-2">
              <button
                :for={
                  {tab, label} <- [
                    {"my_groups", dgettext("settings", "My Groups") <> " (#{@groups_count})"},
                    {"browse", dgettext("settings", "Browse Groups")},
                    {"invitations",
                     dgettext("settings", "Invitations") <> " (#{length(@group_invitations)})"},
                    {"requests",
                     dgettext("settings", "My Requests") <> " (#{length(@group_pending_requests)})"},
                    {"sent_invitations",
                     dgettext("settings", "Sent Invitations") <>
                       " (#{length(@group_sent_invitations)})"}
                  ]
                }
                phx-click="groups_tab"
                phx-value-tab={tab}
                class={[
                  "btn btn-sm",
                  if(@groups_tab == tab, do: "btn-primary", else: "btn-ghost")
                ]}
              >
                {label}
              </button>
            </div>

            <%!-- My Groups tab --%>
            <%= if @groups_tab == "my_groups" do %>
              <%= if @groups_count == 0 do %>
                <div class="mt-4 text-sm text-base-content/60">
                  {gettext("None yet.")}
                </div>
              <% else %>
                <div class="overflow-x-auto mt-4">
                  <table id="my-groups-table" class="table table-zebra w-full">
                    <thead>
                      <tr>
                        <th>{gettext("Title")}</th>
                        <th>{gettext("Type")}</th>
                        <th>{dgettext("settings", "Max Members")}</th>
                        <th>{gettext("Role")}</th>
                        <th></th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        :for={{group, role} <- @my_groups}
                        id={"my-group-" <> to_string(group.id)}
                      >
                        <td class="text-sm">
                          <button
                            phx-click="group_view_detail"
                            phx-value-group_id={group.id}
                            class="link link-primary font-medium"
                          >
                            {group.title}
                          </button>
                        </td>
                        <td>
                          <span class={[
                            "badge badge-sm",
                            cond do
                              group.type == "public" -> "badge-success"
                              group.type == "private" -> "badge-warning"
                              true -> "badge-error"
                            end
                          ]}>
                            {group.type}
                          </span>
                        </td>
                        <td class="text-sm">{group.max_members}</td>
                        <td>
                          <span class={[
                            "badge badge-sm",
                            if(role == "admin", do: "badge-info", else: "badge-ghost")
                          ]}>
                            {role}
                          </span>
                        </td>
                        <td class="flex gap-1">
                          <button
                            phx-click="group_view_detail"
                            phx-value-group_id={group.id}
                            class="btn btn-xs btn-ghost"
                          >
                            {gettext("View")}
                          </button>
                          <button
                            phx-click="group_leave"
                            phx-value-group_id={group.id}
                            class="btn btn-xs btn-outline btn-error"
                            data-confirm={dgettext("settings", "Leave this group?")}
                          >
                            {gettext("Leave")}
                          </button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              <% end %>
            <% end %>

            <%!-- Browse Groups tab --%>
            <%= if @groups_tab == "browse" do %>
              <div class="mt-4">
                <.form
                  for={@browse_groups_form}
                  id="browse-groups-form"
                  phx-change="browse_groups_filter"
                  phx-submit="browse_groups_filter"
                >
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
                    <.input
                      field={@browse_groups_form[:title]}
                      type="text"
                      label={gettext("Title")}
                      phx-debounce="300"
                    />
                    <.input
                      field={@browse_groups_form[:type]}
                      type="select"
                      label={gettext("Type")}
                      options={[
                        {gettext("All"), ""},
                        {gettext("Public"), "public"},
                        {gettext("Private"), "private"}
                      ]}
                    />
                    <div class="flex items-end">
                      <button
                        type="button"
                        phx-click="browse_groups_clear"
                        class="btn btn-sm btn-ghost"
                      >
                        {gettext("Clear")}
                      </button>
                    </div>
                  </div>
                </.form>
              </div>

              <div class="overflow-x-auto mt-4">
                <table id="browse-groups-table" class="table table-zebra w-full">
                  <thead>
                    <tr>
                      <th>{gettext("Title")}</th>
                      <th>{gettext("Type")}</th>
                      <th>{dgettext("settings", "Max Members")}</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= if length(@browse_groups) == 0 do %>
                      <tr>
                        <td colspan="4" class="text-center text-sm text-base-content/60">
                          {gettext("None available.")}
                        </td>
                      </tr>
                    <% end %>
                    <tr
                      :for={group <- @browse_groups}
                      id={"browse-group-" <> to_string(group.id)}
                    >
                      <td class="text-sm font-medium">{group.title}</td>
                      <td>
                        <span class={[
                          "badge badge-sm",
                          if(group.type == "public", do: "badge-success", else: "badge-warning")
                        ]}>
                          {group.type}
                        </span>
                      </td>
                      <td class="text-sm">{group.max_members}</td>
                      <td>
                        <%= cond do %>
                          <% Enum.any?(@my_groups, fn {g, _role} -> g.id == group.id end) -> %>
                            <span class="badge badge-sm badge-ghost">
                              {dgettext("settings", "Joined")}
                            </span>
                          <% Enum.any?(@group_pending_requests, fn r -> r.group_id == group.id end) -> %>
                            <span class="badge badge-sm badge-warning">
                              {dgettext("groups", "Pending")}
                            </span>
                          <% group.type == "public" -> %>
                            <button
                              phx-click="group_join"
                              phx-value-group_id={group.id}
                              class="btn btn-xs btn-primary"
                            >
                              {gettext("Join")}
                            </button>
                          <% group.type == "private" -> %>
                            <button
                              phx-click="group_request_join"
                              phx-value-group_id={group.id}
                              class="btn btn-xs btn-outline btn-primary"
                            >
                              {gettext("Request")}
                            </button>
                          <% true -> %>
                            <span class="text-xs text-base-content/50">-</span>
                        <% end %>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <div class="mt-4 flex gap-2 items-center">
                <button
                  phx-click="browse_groups_prev"
                  class="btn btn-xs"
                  disabled={@browse_groups_page <= 1}
                >
                  {gettext("Prev")}
                </button>
                <div class="text-xs text-base-content/70">
                  page {@browse_groups_page} / {@browse_groups_total_pages} ({@browse_groups_total} total)
                </div>
                <button
                  phx-click="browse_groups_next"
                  class="btn btn-xs"
                  disabled={
                    @browse_groups_page >= @browse_groups_total_pages ||
                      @browse_groups_total_pages == 0
                  }
                >
                  {gettext("Next")}
                </button>
              </div>
            <% end %>

            <%!-- Invitations tab --%>
            <%= if @groups_tab == "invitations" do %>
              <%= if length(@group_invitations) == 0 do %>
                <div class="mt-4 text-sm text-base-content/60">
                  {gettext("None yet.")}
                </div>
              <% else %>
                <div class="overflow-x-auto mt-4">
                  <table id="group-invitations-table" class="table table-zebra w-full">
                    <thead>
                      <tr>
                        <th>{gettext("Group")}</th>
                        <th>{gettext("From")}</th>
                        <th>{gettext("Date")}</th>
                        <th></th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        :for={inv <- @group_invitations}
                        id={"group-inv-" <> to_string(inv.id)}
                      >
                        <td class="text-sm font-mono">
                          {inv.group_name || "Group ##{inv.group_id}"}
                        </td>
                        <td class="text-sm font-mono">{inv.sender_id}</td>
                        <td class="text-sm whitespace-nowrap">
                          {Calendar.strftime(inv.inserted_at, "%Y-%m-%d %H:%M")}
                        </td>
                        <td>
                          <button
                            phx-click="group_accept_invite"
                            phx-value-group_id={inv.group_id}
                            class="btn btn-xs btn-primary"
                          >
                            {gettext("Accept")}
                          </button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              <% end %>
            <% end %>

            <%!-- My Pending Requests tab --%>
            <%= if @groups_tab == "requests" do %>
              <%= if length(@group_pending_requests) == 0 do %>
                <div class="mt-4 text-sm text-base-content/60">
                  {gettext("None yet.")}
                </div>
              <% else %>
                <div class="overflow-x-auto mt-4">
                  <table id="group-requests-table" class="table table-zebra w-full">
                    <thead>
                      <tr>
                        <th>{gettext("Group")}</th>
                        <th>{gettext("Status")}</th>
                        <th>{dgettext("settings", "Requested")}</th>
                        <th>{gettext("Actions")}</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        :for={req <- @group_pending_requests}
                        id={"group-req-" <> to_string(req.id)}
                      >
                        <td class="text-sm font-mono">{req.group.title}</td>
                        <td>
                          <span class="badge badge-sm badge-warning">{req.status}</span>
                        </td>
                        <td class="text-sm whitespace-nowrap">
                          {Calendar.strftime(req.inserted_at, "%Y-%m-%d %H:%M")}
                        </td>
                        <td>
                          <button
                            phx-click="group_cancel_request"
                            phx-value-request_id={req.id}
                            class="btn btn-xs btn-outline btn-error"
                            data-confirm={dgettext("groups", "Cancel this join request?")}
                          >
                            {gettext("Cancel")}
                          </button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              <% end %>
            <% end %>

            <%!-- Sent Invitations tab --%>
            <%= if @groups_tab == "sent_invitations" do %>
              <%= if @group_sent_invitations == [] do %>
                <div class="mt-4 text-sm text-base-content/60">{gettext("None yet.")}</div>
              <% else %>
                <div class="overflow-x-auto mt-4">
                  <table id="group-sent-invitations-table" class="table table-zebra w-full">
                    <thead>
                      <tr>
                        <th>{gettext("Group")}</th>
                        <th>{dgettext("settings", "Invited User")}</th>
                        <th>{gettext("Date")}</th>
                        <th>{gettext("Actions")}</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        :for={inv <- @group_sent_invitations}
                        id={"group-sent-inv-" <> to_string(inv.id)}
                      >
                        <td class="text-sm font-mono">
                          {inv.group_name || "Group ##{inv.group_id}"}
                        </td>
                        <td class="text-sm font-mono">
                          {inv.recipient_name || "User ##{inv.recipient_id}"}
                        </td>
                        <td class="text-sm whitespace-nowrap">
                          {Calendar.strftime(inv.inserted_at, "%Y-%m-%d %H:%M")}
                        </td>
                        <td>
                          <button
                            phx-click="group_cancel_invite"
                            phx-value-invite_id={inv.id}
                            class="btn btn-xs btn-outline btn-error"
                            data-confirm={dgettext("groups", "Cancel this invitation?")}
                          >
                            {gettext("Cancel")}
                          </button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              <% end %>
            <% end %>
          <% end %>
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
          put_flash(socket, :info, dgettext("settings", "Email changed successfully."))

        {:error, _} ->
          put_flash(
            socket,
            :error,
            dgettext("settings", "Email change link is invalid or it has expired.")
          )
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:page_title, dgettext("settings", "Settings"))
      |> assign(:settings_tab, "account")
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
      |> assign(:notif_page, 1)
      |> assign(:notif_page_size, 25)
      |> assign(:notifications, [])
      |> assign(:notif_count, 0)
      |> assign(:notif_total_pages, 0)
      |> assign(:groups_tab, "my_groups")
      |> assign(:my_groups, [])
      |> assign(:groups_count, 0)
      |> assign(:group_invitations, [])
      |> assign(:group_pending_requests, [])
      |> assign(:group_sent_invitations, [])
      |> assign(:browse_groups, [])
      |> assign(:browse_groups_page, 1)
      |> assign(:browse_groups_page_size, 25)
      |> assign(:browse_groups_total, 0)
      |> assign(:browse_groups_total_pages, 0)
      |> assign(:browse_groups_filters, %{})
      |> assign(
        :browse_groups_form,
        to_form(%{"title" => "", "type" => ""}, as: :browse_groups)
      )
      |> assign(:groups_show_create, false)
      |> assign(:create_group_form, to_form(Groups.change_group(%Group{}), as: :group))
      |> assign(:group_detail, nil)
      |> assign(:group_detail_role, nil)
      |> assign(:group_members, [])
      |> assign(:group_members_page, 1)
      |> assign(:group_members_page_size, 25)
      |> assign(:group_members_total, 0)
      |> assign(:group_members_total_pages, 0)
      |> assign(:invite_search_query, "")
      |> assign(:invite_search_results, [])
      |> assign(:invite_friends, [])
      |> assign(:group_editing, false)
      |> assign(:group_edit_form, nil)
      |> assign(:group_join_requests, [])
      |> assign(:group_notify_form, to_form(%{"content" => "", "title" => ""}, as: :notify))

    socket = reload_kv_entries(socket)
    socket = reload_notifications(socket)
    socket = reload_groups(socket)

    if connected?(socket) do
      Friends.subscribe_user(user.id)
      Notifications.subscribe(user.id)
      Groups.subscribe_groups()
      Phoenix.PubSub.subscribe(GameServer.PubSub, "user:#{user.id}")
    end

    {:ok, socket}
  end

  @impl true
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def handle_event(event, params, socket) do
    user = get_user_from_scope(socket.assigns)

    case {event, params} do
      {"settings_tab", %{"tab" => tab}}
      when tab in ~w(account friends data notifications groups) ->
        {:noreply, assign(socket, :settings_tab, tab)}

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
             |> put_flash(:info, dgettext("settings", "Friend request sent"))
             |> refresh_friend_lists(user)}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("settings", "Could not send request: %{reason}",
                 reason: inspect(cs.errors)
               )
             )}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("settings", "Could not send request: %{reason}", reason: inspect(reason))
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
               dgettext("settings", "Could not block: %{reason}", reason: inspect(reason))
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

      {"notif_prev", _} ->
        page = max(1, socket.assigns.notif_page - 1)
        {:noreply, socket |> assign(:notif_page, page) |> reload_notifications()}

      {"notif_next", _} ->
        page = socket.assigns.notif_page + 1
        {:noreply, socket |> assign(:notif_page, page) |> reload_notifications()}

      {"delete_notification", %{"id" => id}} ->
        notif_id = if is_binary(id), do: String.to_integer(id), else: id
        Notifications.delete_notifications(user.id, [notif_id])

        {:noreply,
         socket
         |> put_flash(:info, dgettext("settings", "Notification deleted"))
         |> reload_notifications()}

      {"delete_all_notifications", _} ->
        all_ids =
          Notifications.list_notifications(user.id, page: 1, page_size: 10_000)
          |> Enum.map(& &1.id)

        Notifications.delete_notifications(user.id, all_ids)

        {:noreply,
         socket
         |> put_flash(:info, dgettext("settings", "All notifications deleted"))
         |> assign(:notif_page, 1)
         |> reload_notifications()}

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
               dgettext("settings", "Could not accept: %{reason}", reason: inspect(reason))
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
               dgettext("settings", "Could not reject: %{reason}", reason: inspect(reason))
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
               dgettext("settings", "Could not cancel: %{reason}", reason: inspect(reason))
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
               dgettext("settings", "Could not remove: %{reason}", reason: inspect(reason))
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
               dgettext("settings", "Could not unblock: %{reason}", reason: inspect(reason))
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
              dgettext(
                "settings",
                "Confirmation link sent."
              )

            {:noreply, socket |> put_flash(:info, info)}

          changeset ->
            {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
        end

      {"update_display_name", %{"user" => user_params}} ->
        case Accounts.update_user_display_name(user, user_params) do
          {:ok, user} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("settings", "Display name updated."))
             |> assign(:user, user)}

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
               dgettext("settings", "Successfully unlinked %{provider}.",
                 provider: String.capitalize(provider)
               )
             )
             |> assign(:user, user)}

          {:error, :last_provider} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               dgettext(
                 "settings",
                 "At least one login method must remain linked."
               )
             )}

          {:error, _} ->
            {:noreply,
             socket |> put_flash(:error, dgettext("settings", "Failed to unlink provider."))}
        end

      {"delete_user", _} ->
        case Accounts.delete_user(user) do
          {:ok, _deleted_user} ->
            {:noreply,
             socket
             |> put_flash(
               :info,
               dgettext("settings", "Your account has been deleted successfully.")
             )
             |> Phoenix.LiveView.redirect(external: ~p"/")}

          {:error, _changeset} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("settings", "Failed to delete account. Please try again.")
             )}
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
            {:noreply, put_flash(socket, :error, dgettext("settings", "Account not found."))}
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

      # -----------------------------------------------------------------------
      # Groups events
      # -----------------------------------------------------------------------

      {"groups_tab", %{"tab" => tab}} ->
        {:noreply, assign(socket, :groups_tab, tab)}

      {"groups_toggle_create", _} ->
        show = !socket.assigns.groups_show_create

        form =
          if show,
            do: to_form(Groups.change_group(%Group{}), as: :group),
            else: socket.assigns.create_group_form

        {:noreply, assign(socket, groups_show_create: show, create_group_form: form)}

      {"group_validate_create", %{"group" => group_params}} ->
        changeset =
          Groups.change_group(%Group{}, group_params)
          |> Map.put(:action, :validate)

        {:noreply, assign(socket, create_group_form: to_form(changeset, as: :group))}

      {"group_create", %{"group" => group_params}} ->
        case Groups.create_group(user.id, group_params) do
          {:ok, _group} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Group created"))
             |> assign(:groups_show_create, false)
             |> assign(:create_group_form, to_form(Groups.change_group(%Group{}), as: :group))
             |> assign(:groups_tab, "my_groups")
             |> reload_groups()}

          {:error, changeset} ->
            changeset = Map.put(changeset, :action, :validate)

            {:noreply,
             socket
             |> put_flash(
               :error,
               dgettext("groups", "Could not create group — check the form for errors")
             )
             |> assign(create_group_form: to_form(changeset, as: :group))}
        end

      {"group_leave", %{"group_id" => gid}} ->
        gid = if is_binary(gid), do: String.to_integer(gid), else: gid

        case Groups.leave_group(user.id, gid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Left group"))
             |> assign(:group_detail, nil)
             |> assign(:group_detail_role, nil)
             |> reload_groups()}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not leave group: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_join", %{"group_id" => gid}} ->
        gid = if is_binary(gid), do: String.to_integer(gid), else: gid

        case Groups.join_group(user.id, gid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Joined group"))
             |> reload_groups()}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not join group: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_request_join", %{"group_id" => gid}} ->
        gid = if is_binary(gid), do: String.to_integer(gid), else: gid

        case Groups.request_join(user.id, gid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Join request sent"))
             |> reload_groups()}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not request to join: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_accept_invite", %{"group_id" => gid}} ->
        gid = if is_binary(gid), do: String.to_integer(gid), else: gid

        case Groups.accept_invite(user.id, gid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Invitation accepted"))
             |> reload_groups()}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not accept invite: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_cancel_request", %{"request_id" => rid}} ->
        rid = if is_binary(rid), do: String.to_integer(rid), else: rid

        case Groups.cancel_join_request(user.id, rid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Join request cancelled"))
             |> reload_groups()}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not cancel request: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_cancel_invite", %{"invite_id" => iid}} ->
        iid = if is_binary(iid), do: String.to_integer(iid), else: iid

        case Groups.cancel_invite(user.id, iid) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Invitation cancelled"))
             |> reload_groups()}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not cancel invitation: %{reason}",
                 reason: inspect(reason)
               )
             )}
        end

      {"group_approve_request", %{"request_id" => rid}} ->
        rid = if is_binary(rid), do: String.to_integer(rid), else: rid

        case Groups.approve_join_request(user.id, rid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Request approved"))
             |> assign(
               :group_join_requests,
               Enum.reject(socket.assigns.group_join_requests, &(&1.id == rid))
             )
             |> reload_group_members()
             |> reload_groups()}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not approve: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_reject_request", %{"request_id" => rid}} ->
        rid = if is_binary(rid), do: String.to_integer(rid), else: rid

        case Groups.reject_join_request(user.id, rid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Request rejected"))
             |> assign(
               :group_join_requests,
               Enum.reject(socket.assigns.group_join_requests, &(&1.id == rid))
             )}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not reject: %{reason}", reason: inspect(reason))
             )}
        end

      {"browse_groups_filter", %{"browse_groups" => filter_params}} ->
        title = String.trim(filter_params["title"] || "")
        type = filter_params["type"] || ""

        filters = %{}
        filters = if title != "", do: Map.put(filters, "title", title), else: filters
        filters = if type != "", do: Map.put(filters, "type", type), else: filters

        {:noreply,
         socket
         |> assign(:browse_groups_filters, filters)
         |> assign(:browse_groups_page, 1)
         |> assign(:browse_groups_form, to_form(filter_params, as: :browse_groups))
         |> reload_browse_groups()}

      {"browse_groups_clear", _} ->
        {:noreply,
         socket
         |> assign(:browse_groups_filters, %{})
         |> assign(:browse_groups_page, 1)
         |> assign(
           :browse_groups_form,
           to_form(%{"title" => "", "type" => ""}, as: :browse_groups)
         )
         |> reload_browse_groups()}

      {"browse_groups_prev", _} ->
        page = max(1, socket.assigns.browse_groups_page - 1)

        {:noreply,
         socket
         |> assign(:browse_groups_page, page)
         |> reload_browse_groups()}

      {"browse_groups_next", _} ->
        page = socket.assigns.browse_groups_page + 1

        {:noreply,
         socket
         |> assign(:browse_groups_page, page)
         |> reload_browse_groups()}

      {"group_view_detail", %{"group_id" => gid}} ->
        gid = if is_binary(gid), do: String.to_integer(gid), else: gid
        handle_group_view_detail(socket, gid)

      {"group_close_detail", _} ->
        {:noreply,
         socket
         |> assign(:group_detail, nil)
         |> assign(:group_detail_role, nil)
         |> assign(:group_members, [])
         |> assign(:group_members_total, 0)
         |> assign(:group_members_total_pages, 0)
         |> assign(:invite_search_query, "")
         |> assign(:invite_search_results, [])
         |> assign(:invite_friends, [])
         |> assign(:group_editing, false)
         |> assign(:group_edit_form, nil)
         |> assign(:group_join_requests, [])}

      {"group_toggle_edit", _} ->
        editing = !socket.assigns.group_editing

        form =
          if editing do
            group = socket.assigns.group_detail
            to_form(Groups.change_group(group), as: :group)
          else
            nil
          end

        {:noreply, assign(socket, group_editing: editing, group_edit_form: form)}

      {"group_validate_edit", %{"group" => group_params}} ->
        changeset =
          Groups.change_group(socket.assigns.group_detail, group_params)
          |> Map.put(:action, :validate)

        {:noreply, assign(socket, group_edit_form: to_form(changeset, as: :group))}

      {"group_save_edit", %{"group" => group_params}} ->
        group = socket.assigns.group_detail

        case Groups.update_group(user.id, group.id, group_params) do
          {:ok, updated} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Group updated"))
             |> assign(:group_detail, updated)
             |> assign(:group_editing, false)
             |> assign(:group_edit_form, nil)
             |> reload_groups()}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, group_edit_form: to_form(changeset, as: :group))}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not update: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_kick", %{"group_id" => gid, "user_id" => uid}} ->
        gid = if is_binary(gid), do: String.to_integer(gid), else: gid
        uid = if is_binary(uid), do: String.to_integer(uid), else: uid

        case Groups.kick_member(user.id, gid, uid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Member kicked"))
             |> reload_groups()
             |> reload_group_members()}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not kick: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_promote", %{"group_id" => gid, "user_id" => uid}} ->
        gid = if is_binary(gid), do: String.to_integer(gid), else: gid
        uid = if is_binary(uid), do: String.to_integer(uid), else: uid

        case Groups.promote_member(user.id, gid, uid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Member promoted to admin"))
             |> reload_group_members()}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not promote: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_demote", %{"group_id" => gid, "user_id" => uid}} ->
        gid = if is_binary(gid), do: String.to_integer(gid), else: gid
        uid = if is_binary(uid), do: String.to_integer(uid), else: uid

        case Groups.demote_member(user.id, gid, uid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Member demoted to member"))
             |> reload_group_members()}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not demote: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_members_prev", _} ->
        page = max(1, socket.assigns.group_members_page - 1)

        {:noreply,
         socket
         |> assign(:group_members_page, page)
         |> reload_group_members()}

      {"group_members_next", _} ->
        page = socket.assigns.group_members_page + 1

        {:noreply,
         socket
         |> assign(:group_members_page, page)
         |> reload_group_members()}

      {"group_invite_search", %{"value" => query}} ->
        query = String.trim(query)

        results =
          if query == "" do
            []
          else
            group_id = socket.assigns.group_detail.id

            all_member_ids =
              Groups.get_group_members(group_id)
              |> Enum.map(& &1.user_id)
              |> MapSet.new()

            Accounts.search_users(query, page: 1, page_size: 10)
            |> Enum.reject(fn u -> MapSet.member?(all_member_ids, u.id) end)
          end

        {:noreply,
         socket
         |> assign(:invite_search_query, query)
         |> assign(:invite_search_results, results)}

      {"group_invite_user", %{"group_id" => gid, "user_id" => uid}} ->
        gid = if is_binary(gid), do: String.to_integer(gid), else: gid
        uid = if is_binary(uid), do: String.to_integer(uid), else: uid

        case Groups.invite_to_group(user.id, gid, uid) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("groups", "Invitation sent"))
             |> assign(
               :invite_search_results,
               Enum.reject(socket.assigns.invite_search_results, &(&1.id == uid))
             )
             |> assign(
               :invite_friends,
               Enum.reject(socket.assigns.invite_friends, &(&1.id == uid))
             )}

          {:error, :already_member} ->
            {:noreply, put_flash(socket, :error, dgettext("groups", "User is already a member"))}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               dgettext("groups", "Could not invite: %{reason}", reason: inspect(reason))
             )}
        end

      {"group_notify", %{"notify" => notify_params}} ->
        group = socket.assigns.group_detail
        content = String.trim(Map.get(notify_params, "content", ""))
        title = String.trim(Map.get(notify_params, "title", ""))

        if group && content != "" do
          metadata = if title != "", do: %{"title" => title}, else: %{}

          case Groups.notify_group(user.id, group.id, content, metadata) do
            {:ok, sent} ->
              {:noreply,
               socket
               |> put_flash(
                 :info,
                 dngettext(
                   "groups",
                   "Notification sent to %{count} member",
                   "Notification sent to %{count} members",
                   sent,
                   count: sent
                 )
               )
               |> assign(
                 :group_notify_form,
                 to_form(%{"content" => "", "title" => ""}, as: :notify)
               )}

            {:error, reason} ->
              {:noreply,
               put_flash(
                 socket,
                 :error,
                 dgettext("groups", "Could not notify: %{reason}", reason: inspect(reason))
               )}
          end
        else
          {:noreply, put_flash(socket, :error, dgettext("groups", "Please enter a message"))}
        end

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

  defp reload_notifications(socket) do
    user = get_user_from_scope(socket.assigns)

    if user do
      page = socket.assigns.notif_page
      page_size = socket.assigns.notif_page_size

      notifications = Notifications.list_notifications(user.id, page: page, page_size: page_size)
      count = Notifications.count_notifications(user.id)
      total_pages = if page_size > 0, do: div(count + page_size - 1, page_size), else: 0

      socket
      |> assign(:notifications, notifications)
      |> assign(:notif_count, count)
      |> assign(:notif_total_pages, total_pages)
    else
      socket
    end
  end

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

  # Online status change broadcast from UserChannel (via PubSub on "user:<id>")
  def handle_info(
        %Phoenix.Socket.Broadcast{event: event},
        socket
      )
      when event in ["friend_online", "friend_offline"] do
    {:noreply, refresh_friend_lists(socket, get_user_from_scope(socket.assigns))}
  end

  # Ignore other broadcasts on the user topic (e.g. "updated" events from channel)
  def handle_info(%Phoenix.Socket.Broadcast{}, socket), do: {:noreply, socket}

  # Notification PubSub — refresh notification list when a new one arrives
  def handle_info({:new_notification, _notification}, socket) do
    {:noreply, reload_notifications(socket) |> reload_groups()}
  end

  # Groups PubSub — refresh groups when something changes
  def handle_info({event, _payload}, socket)
      when event in [
             :group_created,
             :group_updated,
             :group_deleted,
             :member_joined,
             :member_left,
             :member_kicked,
             :member_promoted,
             :member_demoted,
             :join_request_approved,
             :join_request_rejected
           ] do
    {:noreply, reload_groups(socket)}
  end

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
           dgettext("settings", "You cannot delete your currently logged-in account here.")
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
           dgettext(
             "settings",
             "Cannot delete an account you do not own. Log in to the other account directly if you control it."
           )
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
           dgettext(
             "settings",
             "Conflicting account deleted. You can now try linking the provider again."
           )
         )
         |> assign(:conflict_user, nil)}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("settings", "Failed to delete the conflicting account.")
         )}
    end
  end

  # ---------------------------------------------------------------------------
  # Groups helpers
  # ---------------------------------------------------------------------------

  defp reload_groups(socket) do
    user = get_user_from_scope(socket.assigns)

    if user do
      my_groups = Groups.list_user_groups_with_role(user.id)
      groups_count = Groups.count_user_groups(user.id)
      invitations = Groups.list_invitations(user.id)
      pending_requests = Groups.list_user_pending_requests(user.id)
      sent_invitations = Groups.list_sent_invitations(user.id)

      socket
      |> assign(:my_groups, my_groups)
      |> assign(:groups_count, groups_count)
      |> assign(:group_invitations, invitations)
      |> assign(:group_pending_requests, pending_requests)
      |> assign(:group_sent_invitations, sent_invitations)
      |> reload_browse_groups()
    else
      socket
    end
  end

  defp reload_browse_groups(socket) do
    page = socket.assigns.browse_groups_page
    page_size = socket.assigns.browse_groups_page_size
    filters = socket.assigns.browse_groups_filters

    groups = Groups.list_groups(filters, page: page, page_size: page_size)
    total = Groups.count_list_groups(filters)
    total_pages = if page_size > 0, do: div(total + page_size - 1, page_size), else: 0

    socket
    |> assign(:browse_groups, groups)
    |> assign(:browse_groups_total, total)
    |> assign(:browse_groups_total_pages, total_pages)
  end

  defp handle_group_view_detail(socket, gid) do
    user = socket.assigns.current_scope.user

    case Groups.get_group(gid) do
      nil ->
        {:noreply, put_flash(socket, :error, dgettext("groups", "Group not found"))}

      group ->
        role =
          case Groups.get_membership(gid, user.id) do
            %{role: r} -> r
            _ -> nil
          end

        member_ids =
          Groups.get_group_members(gid) |> Enum.map(& &1.user_id) |> MapSet.new()

        friends_not_in_group =
          Friends.list_friends_for_user(user.id)
          |> Enum.reject(fn f -> MapSet.member?(member_ids, f.id) end)

        join_requests = load_join_requests(role, user.id, gid)

        {:noreply,
         socket
         |> assign(:group_detail, group)
         |> assign(:group_detail_role, role)
         |> assign(:group_members_page, 1)
         |> assign(:invite_search_query, "")
         |> assign(:invite_search_results, [])
         |> assign(:invite_friends, friends_not_in_group)
         |> assign(:group_join_requests, join_requests)
         |> reload_group_members()}
    end
  end

  defp load_join_requests("admin", user_id, group_id) do
    case Groups.list_join_requests(user_id, group_id) do
      {:ok, reqs} -> reqs
      _ -> []
    end
  end

  defp load_join_requests(_role, _user_id, _group_id), do: []

  defp reload_group_members(socket) do
    group = socket.assigns.group_detail

    if group do
      page = socket.assigns.group_members_page
      page_size = socket.assigns.group_members_page_size

      members = Groups.get_group_members_paginated(group.id, page: page, page_size: page_size)
      total = Groups.count_group_members(group.id)
      total_pages = if page_size > 0, do: div(total + page_size - 1, page_size), else: 0

      socket
      |> assign(:group_members, members)
      |> assign(:group_members_total, total)
      |> assign(:group_members_total_pages, total_pages)
    else
      socket
    end
  end
end
