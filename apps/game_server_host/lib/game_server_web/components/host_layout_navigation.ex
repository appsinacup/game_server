defmodule GameServerWeb.HostLayoutNavigation do
  @moduledoc false

  use GameServerWeb, :html

  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: nil
  attr :current_query, :string, default: ""
  attr :nav_links, :list, default: []
  attr :notif_unread_count, :integer, default: 0
  attr :locale, :string, required: true
  attr :known_locales, :list, default: []

  def desktop_nav(assigns) do
    ~H"""
    <ul class="hidden xl:flex flex-row px-1 space-x-4 items-center">
      <%= if @current_scope do %>
        <li>
          <.link
            href={~p"/leaderboards"}
            class={[
              "btn",
              if(String.starts_with?(@current_path, "/leaderboards"),
                do: "btn-primary",
                else: "btn-outline"
              )
            ]}
          >
            <.icon name="hero-chart-bar-solid" class="w-4 h-4" />
            {gettext("Leaderboards")}
          </.link>
        </li>
        <li>
          <.link
            href={~p"/achievements"}
            class={[
              "btn",
              if(String.starts_with?(@current_path, "/achievements"),
                do: "btn-primary",
                else: "btn-outline"
              )
            ]}
          >
            <.icon name="hero-trophy-solid" class="w-4 h-4" />
            {gettext("Achievements")}
          </.link>
        </li>
        <li>
          <.link
            href={~p"/groups"}
            class={[
              "btn",
              if(@current_path == "/groups", do: "btn-primary", else: "btn-outline")
            ]}
          >
            <.icon name="hero-user-group-solid" class="w-4 h-4" />
            {gettext("Groups")}
          </.link>
        </li>
        <li class="flex items-center px-0">
          <div class="w-px h-6 bg-base-content/20"></div>
        </li>
        <%= for link <- filtered_nav_links(@nav_links, if(@current_scope.user.is_admin, do: :admin, else: :authenticated), true) do %>
          <li>
            <a
              href={link["href"]}
              target={if(link["external"], do: "_blank", else: nil)}
              rel={if(link["external"], do: "noopener noreferrer", else: nil)}
              class={[
                "btn",
                if(String.starts_with?(@current_path, link["href"]),
                  do: "btn-primary",
                  else: "btn-outline"
                )
              ]}
            >
              <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
              {link["label"]}
            </a>
          </li>
        <% end %>
      <% else %>
        <li>
          <.link
            href={~p"/leaderboards"}
            class={[
              "btn",
              if(String.starts_with?(@current_path, "/leaderboards"),
                do: "btn-primary",
                else: "btn-outline"
              )
            ]}
          >
            <.icon name="hero-chart-bar-solid" class="w-4 h-4" />
            {gettext("Leaderboards")}
          </.link>
        </li>
        <li>
          <.link
            href={~p"/achievements"}
            class={[
              "btn",
              if(String.starts_with?(@current_path, "/achievements"),
                do: "btn-primary",
                else: "btn-outline"
              )
            ]}
          >
            <.icon name="hero-trophy-solid" class="w-4 h-4" />
            {gettext("Achievements")}
          </.link>
        </li>
        <li>
          <.link
            href={~p"/groups"}
            class={[
              "btn",
              if(@current_path == "/groups", do: "btn-primary", else: "btn-outline")
            ]}
          >
            <.icon name="hero-user-group-solid" class="w-4 h-4" />
            {gettext("Groups")}
          </.link>
        </li>
        <li class="flex items-center px-0">
          <div class="w-px h-6 bg-base-content/20"></div>
        </li>
        <%= for link <- filtered_nav_links(@nav_links, :unauthenticated) do %>
          <li>
            <a
              href={link["href"]}
              target={if(link["external"], do: "_blank", else: nil)}
              rel={if(link["external"], do: "noopener noreferrer", else: nil)}
              class={[
                "btn",
                if(String.starts_with?(@current_path, link["href"]),
                  do: "btn-primary",
                  else: "btn-outline"
                )
              ]}
            >
              <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
              {link["label"]}
            </a>
          </li>
        <% end %>
        <li class="flex items-center px-0">
          <div class="w-px h-6 bg-base-content/20"></div>
        </li>
        <li>
          <.link
            href={~p"/users/log-in"}
            class={[
              "btn",
              if(String.starts_with?(@current_path, "/users/log-in"),
                do: "btn-primary",
                else: "btn-outline"
              )
            ]}
          >
            <.icon name="hero-arrow-right-on-rectangle-solid" class="w-4 h-4" />
            {gettext("Log in")}
          </.link>
        </li>
        <li>
          <.link
            href={~p"/users/register"}
            class={[
              "btn",
              if(String.starts_with?(@current_path, "/users/register"),
                do: "btn-primary",
                else: "btn-outline"
              )
            ]}
          >
            <.icon name="hero-user-plus-solid" class="w-4 h-4" />
            {gettext("Register")}
          </.link>
        </li>
      <% end %>

      <%= if @current_scope do %>
        <%= for link <- filtered_nav_links(@nav_links, :authenticated) do %>
          <li>
            <a
              href={link["href"]}
              target={if(link["external"], do: "_blank", else: nil)}
              rel={if(link["external"], do: "noopener noreferrer", else: nil)}
              class={[
                "btn",
                if(String.starts_with?(@current_path, link["href"]),
                  do: "btn-primary",
                  else: "btn-outline"
                )
              ]}
            >
              <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
              {link["label"]}
            </a>
          </li>
        <% end %>
      <% end %>

      <li class="flex items-center px-0">
        <div class="w-px h-6 bg-base-content/20"></div>
      </li>

      <%= if @current_scope do %>
        <li>
          <.user_menu
            current_scope={@current_scope}
            current_path={@current_path}
            notif_unread_count={@notif_unread_count}
          />
        </li>
      <% end %>

      <%= if length(@known_locales) > 1 do %>
        <li class="flex items-center px-0">
          <div class="w-px h-6 bg-base-content/20"></div>
        </li>
        <li>
          <.language_dropdown
            locale={@locale}
            current_path={@current_path}
            current_query={@current_query}
            known_locales={@known_locales}
            mobile={false}
          />
        </li>
      <% end %>

      <li>
        <GameServerWeb.HostLayouts.theme_toggle />
      </li>
    </ul>
    """
  end

  attr :current_scope, :map, required: true
  attr :current_path, :string, default: nil
  attr :notif_unread_count, :integer, default: 0

  def user_menu(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <button
        tabindex="0"
        class={[
          "btn gap-1",
          if(
            String.starts_with?(@current_path, "/users/settings") or
              String.starts_with?(@current_path, "/notifications") or
              String.starts_with?(@current_path, "/chat") or
              String.starts_with?(@current_path, "/admin"),
            do: "btn-primary",
            else: "btn-outline"
          )
        ]}
      >
        <.icon name="hero-user-circle-solid" class="w-5 h-5" />
        <span class="max-w-[8rem] truncate">{display_name(@current_scope.user)}</span>
        <span
          :if={@notif_unread_count > 0}
          class="inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs font-bold rounded-full bg-error text-error-content"
        >
          {@notif_unread_count}
        </span>
        <.icon name="hero-chevron-down-solid" class="w-3 h-3" />
      </button>
      <ul
        tabindex="0"
        class="menu menu-sm dropdown-content mt-2 z-[1] p-2 shadow-lg bg-base-100 rounded-box w-56"
      >
        <li>
          <.link
            href={~p"/users/settings"}
            class={[if(String.starts_with?(@current_path, "/users/settings"), do: "active", else: "")]}
          >
            <.icon name="hero-user-circle-solid" class="w-4 h-4" />
            {gettext("Account")}
          </.link>
        </li>
        <li>
          <.link
            href={~p"/notifications"}
            class={[if(String.starts_with?(@current_path, "/notifications"), do: "active", else: "")]}
          >
            <.icon name="hero-bell-solid" class="w-4 h-4" />
            {gettext("Notifications")}
            <span
              :if={@notif_unread_count > 0}
              class="inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs font-bold rounded-full bg-error text-error-content"
            >
              {@notif_unread_count}
            </span>
          </.link>
        </li>
        <li>
          <.link
            href={~p"/chat"}
            class={[if(String.starts_with?(@current_path, "/chat"), do: "active", else: "")]}
          >
            <.icon name="hero-chat-bubble-left-right-solid" class="w-4 h-4" />
            {gettext("Chat")}
          </.link>
        </li>
        <%= if @current_scope.user.is_admin do %>
          <li>
            <.link
              href={~p"/admin"}
              class={[if(String.starts_with?(@current_path, "/admin"), do: "active", else: "")]}
            >
              <.icon name="hero-cog-6-tooth-solid" class="w-4 h-4" />
              {gettext("Admin")}
            </.link>
          </li>
        <% end %>
        <li class="border-t border-base-300 mt-1 pt-1">
          <.link href={~p"/users/log-out"} method="delete">
            <.icon name="hero-arrow-left-on-rectangle-solid" class="w-4 h-4" />
            {gettext("Log out")}
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: nil
  attr :current_query, :string, default: ""
  attr :nav_links, :list, default: []
  attr :notif_unread_count, :integer, default: 0
  attr :locale, :string, required: true
  attr :known_locales, :list, default: []

  def mobile_nav(assigns) do
    ~H"""
    <div class="xl:hidden">
      <div class="dropdown dropdown-end">
        <button tabindex="0" class="btn btn-ghost btn-circle">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 6h16M4 12h16M4 18h16"
            >
            </path>
          </svg>
        </button>
        <ul
          tabindex="0"
          class="menu menu-sm dropdown-content mt-3 z-[1] p-2 shadow bg-base-100 rounded-box w-80 text-lg"
        >
          <%= if @current_scope do %>
            <li>
              <a
                href={~p"/users/settings"}
                class={[
                  "btn",
                  if(String.starts_with?(@current_path, "/users/settings"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-user-circle-solid" class="w-4 h-4" />
                {gettext("Account")}
              </a>
            </li>
            <li>
              <a
                href={~p"/notifications"}
                class={[
                  "btn",
                  if(String.starts_with?(@current_path, "/notifications"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-bell-solid" class="w-4 h-4" />
                {gettext("Notifications")}
                <span
                  :if={@notif_unread_count > 0}
                  class="ml-0.5 inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs font-bold rounded-full bg-error text-error-content"
                >
                  {@notif_unread_count}
                </span>
              </a>
            </li>
            <li>
              <a
                href={~p"/chat"}
                class={[
                  "btn",
                  if(String.starts_with?(@current_path, "/chat"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-chat-bubble-left-right-solid" class="w-4 h-4" />
                {gettext("Chat")}
              </a>
            </li>
            <%= if @current_scope.user.is_admin do %>
              <li>
                <a
                  href={~p"/admin"}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, "/admin"),
                      do: "btn-primary",
                      else: "btn-ghost"
                    )
                  ]}
                >
                  <.icon name="hero-cog-6-tooth-solid" class="w-4 h-4" />
                  {gettext("Admin")}
                </a>
              </li>
            <% end %>
            <li class="mt-3">
              <a
                href={~p"/leaderboards"}
                class={[
                  "btn",
                  if(String.starts_with?(@current_path, "/leaderboards"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-chart-bar-solid" class="w-4 h-4" />
                {gettext("Leaderboards")}
              </a>
            </li>
            <li>
              <a
                href={~p"/achievements"}
                class={[
                  "btn",
                  if(String.starts_with?(@current_path, "/achievements"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-trophy-solid" class="w-4 h-4" />
                {gettext("Achievements")}
              </a>
            </li>
            <li>
              <a
                href={~p"/groups"}
                class={[
                  "btn",
                  if(@current_path == "/groups", do: "btn-primary", else: "btn-ghost")
                ]}
              >
                <.icon name="hero-user-group-solid" class="w-4 h-4" />
                {gettext("Groups")}
              </a>
            </li>
            <%= for link <- filtered_nav_links(@nav_links, if(@current_scope.user.is_admin, do: :admin, else: :authenticated), true) do %>
              <li>
                <a
                  href={link["href"]}
                  target={if(link["external"], do: "_blank", else: nil)}
                  rel={if(link["external"], do: "noopener noreferrer", else: nil)}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, link["href"]),
                      do: "btn-primary",
                      else: "btn-ghost"
                    )
                  ]}
                >
                  <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
                  {link["label"]}
                </a>
              </li>
            <% end %>
          <% else %>
            <li>
              <a
                href={~p"/users/log-in"}
                class={[
                  "btn",
                  if(String.starts_with?(@current_path, "/users/log-in"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-arrow-right-on-rectangle-solid" class="w-4 h-4" />
                {gettext("Log in")}
              </a>
            </li>
            <li>
              <a
                href={~p"/users/register"}
                class={[
                  "btn",
                  if(String.starts_with?(@current_path, "/users/register"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-user-plus-solid" class="w-4 h-4" />
                {gettext("Register")}
              </a>
            </li>
            <li>
              <a
                href={~p"/leaderboards"}
                class={[
                  "btn",
                  if(String.starts_with?(@current_path, "/leaderboards"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-chart-bar-solid" class="w-4 h-4" />
                {gettext("Leaderboards")}
              </a>
            </li>
            <li>
              <a
                href={~p"/achievements"}
                class={[
                  "btn",
                  if(String.starts_with?(@current_path, "/achievements"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-trophy-solid" class="w-4 h-4" />
                {gettext("Achievements")}
              </a>
            </li>
            <li>
              <a
                href={~p"/groups"}
                class={[
                  "btn",
                  if(@current_path == "/groups", do: "btn-primary", else: "btn-ghost")
                ]}
              >
                <.icon name="hero-user-group-solid" class="w-4 h-4" />
                {gettext("Groups")}
              </a>
            </li>
          <% end %>

          <%= for link <- filtered_nav_links(@nav_links, if(@current_scope, do: :authenticated, else: :unauthenticated)) do %>
            <li>
              <a
                href={link["href"]}
                target={if(link["external"], do: "_blank", else: nil)}
                rel={if(link["external"], do: "noopener noreferrer", else: nil)}
                class={[
                  "btn",
                  if(String.starts_with?(@current_path, link["href"]),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
                {link["label"]}
              </a>
            </li>
          <% end %>

          <%= if @current_scope do %>
            <div class="mt-3"></div>
          <% end %>

          <%= if length(@known_locales) > 1 do %>
            <li class="[&>*]:!p-0 [&>*]:!bg-transparent mt-3">
              <.language_dropdown
                locale={@locale}
                current_path={@current_path}
                current_query={@current_query}
                known_locales={@known_locales}
                mobile={true}
              />
            </li>
          <% end %>

          <%= if @current_scope do %>
            <li class="mt-3">
              <.link href={~p"/users/log-out"} method="delete" class="btn btn-ghost">
                <.icon name="hero-arrow-left-on-rectangle-solid" class="w-4 h-4" />
                {gettext("Log out")}
              </.link>
            </li>
          <% end %>

          <li class="mt-2">
            <div class="flex justify-center">
              <GameServerWeb.HostLayouts.theme_toggle />
            </div>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :locale, :string, required: true
  attr :current_path, :string, default: nil
  attr :current_query, :string, default: ""
  attr :known_locales, :list, default: []
  attr :mobile, :boolean, default: false

  def language_dropdown(assigns) do
    locale_links =
      locale_links(assigns.current_path, assigns.current_query, assigns.known_locales)

    label = locale_label(assigns.locale)

    assigns = assign(assigns, locale_links: locale_links, label: label)

    ~H"""
    <%= if @mobile do %>
      <label for="lang-modal" class="btn btn-ghost btn-sm w-full relative cursor-pointer">
        <.icon name="hero-globe-alt-solid" class="w-4 h-4" />
        {@label}
        <.icon name="hero-chevron-down-solid" class="w-3 h-3 absolute right-3" />
      </label>
    <% else %>
      <details class="dropdown dropdown-end">
        <summary class="btn btn-outline list-none">
          <.icon name="hero-globe-alt-solid" class="w-4 h-4" />
          {@label}
          <.icon name="hero-chevron-down-solid" class="w-3 h-3" />
        </summary>
        <ul class="dropdown-content mt-2 p-2 shadow bg-base-100 rounded-box overflow-y-auto grid grid-cols-3 gap-0.5 w-[28rem] z-[1] max-h-[60vh]">
          <%= for link <- @locale_links do %>
            <li class="list-none">
              <a
                href={link.href}
                class={[
                  "block px-2 py-1.5 rounded text-sm whitespace-nowrap hover:bg-base-200 transition-colors text-center",
                  link.locale == @locale && "bg-primary/10 font-semibold text-primary"
                ]}
              >
                {link.label}
              </a>
            </li>
          <% end %>
        </ul>
      </details>
    <% end %>
    """
  end

  attr :locale, :string, required: true
  attr :current_path, :string, default: nil
  attr :current_query, :string, default: ""
  attr :known_locales, :list, default: []

  def language_modal(assigns) do
    locale_links =
      locale_links(assigns.current_path, assigns.current_query, assigns.known_locales)

    label = locale_label(assigns.locale)

    assigns = assign(assigns, locale_links: locale_links, label: label)

    ~H"""
    <input type="checkbox" id="lang-modal" class="modal-toggle" />
    <div class="modal modal-bottom sm:modal-middle z-[100]" role="dialog">
      <div class="modal-box max-w-2xl">
        <label for="lang-modal" class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">
          ✕
        </label>
        <h3 class="font-bold text-lg mb-4 flex items-center gap-2">
          <.icon name="hero-globe-alt-solid" class="w-5 h-5" />
          {@label}
        </h3>
        <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-1">
          <%= for link <- @locale_links do %>
            <a
              href={link.href}
              class={[
                "block px-2 py-2 rounded text-sm whitespace-nowrap hover:bg-base-200 transition-colors text-center",
                link.locale == @locale && "bg-primary/10 font-semibold text-primary"
              ]}
            >
              {link.label}
            </a>
          <% end %>
        </div>
      </div>
      <label class="modal-backdrop" for="lang-modal">Close</label>
    </div>
    """
  end

  defp locale_links(current_path, current_query, known_locales) do
    locale_labels = GameServerWeb.HostLayouts.locale_labels()
    base_path = GameServerWeb.HostLayouts.strip_locale_prefix(current_path || "/", known_locales)

    query_suffix =
      if is_binary(current_query) and current_query != "", do: "?" <> current_query, else: ""

    Enum.map(known_locales, fn locale ->
      href =
        if(base_path == "/", do: "/" <> locale, else: "/" <> locale <> base_path) <> query_suffix

      %{locale: locale, label: Map.get(locale_labels, locale, locale), href: href}
    end)
  end

  defp locale_label(locale) do
    locale
    |> then(&Map.get(GameServerWeb.HostLayouts.locale_labels(), &1, &1))
  end

  defp display_name(user) do
    cond do
      is_binary(user.display_name) and user.display_name != "" -> user.display_name
      is_binary(user.email) and user.email != "" -> user.email
      true -> "User"
    end
  end

  defp filtered_nav_links(nav_links, auth_level, exact? \\ false) do
    Enum.filter(nav_links, fn link ->
      required = Map.get(link, "auth", "any")

      case {required, auth_level, exact?} do
        {"any", _, false} -> true
        {"any", _, true} -> false
        {"authenticated", :authenticated, _} -> true
        {"authenticated", :admin, _} -> true
        {"admin", :admin, _} -> true
        _ -> false
      end
    end)
  end
end
