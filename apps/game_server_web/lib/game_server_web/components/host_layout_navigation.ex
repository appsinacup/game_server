defmodule GameServerWeb.HostLayoutNavigation do
  @moduledoc false

  use GameServerWeb, :html

  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: nil
  attr :current_query, :string, default: ""
  attr :navigation, :map, default: %{}
  attr :notif_unread_count, :integer, default: 0
  attr :locale, :string, required: true
  attr :known_locales, :list, default: []

  def desktop_nav(assigns) do
    assigns = prepare_navigation_assigns(assigns)

    ~H"""
    <ul class="hidden xl:flex flex-row px-1 space-x-4 items-center">
      <.main_nav_links
        links={@primary_links}
        current_path={@current_path}
        inactive_class="btn-outline"
      />

      <%= if @current_scope do %>
        <%= if @authenticated_links != [] do %>
          <.nav_divider />
          <.main_nav_links
            links={@authenticated_links}
            current_path={@current_path}
            inactive_class="btn-outline"
          />
        <% end %>
      <% else %>
        <%= if @guest_links != [] do %>
          <.nav_divider />
          <.main_nav_links
            links={@guest_links}
            current_path={@current_path}
            inactive_class="btn-outline"
          />
        <% end %>

        <.nav_divider />

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
            {GameServerWeb.HostLayouts.translate("Log in")}
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
            {GameServerWeb.HostLayouts.translate("Register")}
          </.link>
        </li>
      <% end %>

      <%= if @current_scope do %>
        <.nav_divider />
        <li>
          <.user_menu
            current_scope={@current_scope}
            current_path={@current_path}
            notif_unread_count={@notif_unread_count}
            account_links={@account_links}
          />
        </li>
      <% end %>

      <%= if length(@known_locales) > 1 do %>
        <.nav_divider />
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
  attr :account_links, :list, default: []

  def user_menu(assigns) do
    assigns =
      assign(assigns,
        custom_link_active?: any_link_active?(assigns.account_links, assigns.current_path)
      )

    ~H"""
    <div class="dropdown dropdown-end">
      <button
        tabindex="0"
        class={[
          "btn gap-1",
          if(
            @custom_link_active? or
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
            class={[
              if(String.starts_with?(@current_path, "/users/settings"), do: "active", else: "")
            ]}
          >
            <.icon name="hero-user-circle-solid" class="w-4 h-4" />
            {GameServerWeb.HostLayouts.translate("Account")}
          </.link>
        </li>

        <.account_menu_links links={@account_links} current_path={@current_path} />

        <li>
          <.link
            href={~p"/notifications"}
            class={[
              if(String.starts_with?(@current_path, "/notifications"), do: "active", else: "")
            ]}
          >
            <.icon name="hero-bell-solid" class="w-4 h-4" />
            {GameServerWeb.HostLayouts.translate("Notifications")}
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
            {GameServerWeb.HostLayouts.translate("Chat")}
          </.link>
        </li>
        <%= if @current_scope.user.is_admin do %>
          <li>
            <.link
              href={~p"/admin"}
              class={[if(String.starts_with?(@current_path, "/admin"), do: "active", else: "")]}
            >
              <.icon name="hero-cog-6-tooth-solid" class="w-4 h-4" />
              {GameServerWeb.HostLayouts.translate("Admin")}
            </.link>
          </li>
        <% end %>
        <li class="border-t border-base-300 mt-1 pt-1">
          <.link href={~p"/users/log-out"} method="delete">
            <.icon name="hero-arrow-left-on-rectangle-solid" class="w-4 h-4" />
            {GameServerWeb.HostLayouts.translate("Log out")}
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: nil
  attr :current_query, :string, default: ""
  attr :navigation, :map, default: %{}
  attr :notif_unread_count, :integer, default: 0
  attr :locale, :string, required: true
  attr :known_locales, :list, default: []

  def mobile_nav(assigns) do
    assigns = prepare_navigation_assigns(assigns)

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
                {GameServerWeb.HostLayouts.translate("Account")}
              </a>
            </li>

            <.mobile_nav_links
              links={@account_links}
              current_path={@current_path}
              inactive_class="btn-ghost"
            />

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
                {GameServerWeb.HostLayouts.translate("Notifications")}
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
                {GameServerWeb.HostLayouts.translate("Chat")}
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
                  {GameServerWeb.HostLayouts.translate("Admin")}
                </a>
              </li>
            <% end %>

            <.mobile_nav_links
              links={@primary_links ++ @authenticated_links}
              current_path={@current_path}
              inactive_class="btn-ghost"
            />
          <% else %>
            <.mobile_nav_links
              links={@guest_links}
              current_path={@current_path}
              inactive_class="btn-ghost"
            />

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
                {GameServerWeb.HostLayouts.translate("Log in")}
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
                {GameServerWeb.HostLayouts.translate("Register")}
              </a>
            </li>

            <.mobile_nav_links
              links={@primary_links}
              current_path={@current_path}
              inactive_class="btn-ghost"
            />
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
                {GameServerWeb.HostLayouts.translate("Log out")}
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

  attr :links, :list, default: []
  attr :current_path, :string, default: nil
  attr :inactive_class, :string, required: true

  defp main_nav_links(assigns) do
    ~H"""
    <%= for link <- @links do %>
      <li>
        <.main_nav_link_item
          link={link}
          current_path={@current_path}
          inactive_class={@inactive_class}
        />
      </li>
    <% end %>
    """
  end

  attr :links, :list, default: []
  attr :current_path, :string, default: nil
  attr :inactive_class, :string, required: true

  defp mobile_nav_links(assigns) do
    ~H"""
    <%= for link <- @links do %>
      <li>
        <.main_nav_link_item
          link={link}
          current_path={@current_path}
          inactive_class={@inactive_class}
        />
      </li>
    <% end %>
    """
  end

  attr :link, :map, required: true
  attr :current_path, :string, default: nil
  attr :inactive_class, :string, required: true

  defp main_nav_link_item(assigns) do
    active? = link_active?(assigns.link, assigns.current_path)

    assigns = assign(assigns, active?: active?)

    ~H"""
    <a
      href={@link["href"]}
      target={if(@link["external"], do: "_blank", else: nil)}
      rel={if(@link["external"], do: "noopener noreferrer", else: nil)}
      class={["btn", if(@active?, do: "btn-primary", else: @inactive_class)]}
    >
      <.icon :if={@link["icon"]} name={@link["icon"]} class="w-4 h-4" />
      {translate_label(@link["label"])}
    </a>
    """
  end

  attr :links, :list, default: []
  attr :current_path, :string, default: nil

  defp account_menu_links(assigns) do
    ~H"""
    <%= for link <- @links do %>
      <li>
        <a
          href={link["href"]}
          target={if(link["external"], do: "_blank", else: nil)}
          rel={if(link["external"], do: "noopener noreferrer", else: nil)}
          class={[if(link_active?(link, @current_path), do: "active", else: "")]}
        >
          <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
          {translate_label(link["label"])}
        </a>
      </li>
    <% end %>
    """
  end

  defp prepare_navigation_assigns(assigns) do
    auth_level = auth_level(assigns.current_scope)

    assign(assigns,
      primary_links: section_links(assigns.navigation, "primary_links", auth_level, "any"),
      guest_links:
        section_links(assigns.navigation, "guest_links", auth_level, "unauthenticated"),
      authenticated_links:
        section_links(assigns.navigation, "authenticated_links", auth_level, "authenticated"),
      account_links:
        section_links(assigns.navigation, "account_links", auth_level, "authenticated")
    )
  end

  defp section_links(navigation, key, auth_level, default_auth) do
    navigation
    |> Map.get(key, [])
    |> Enum.filter(fn link ->
      valid_link?(link) and link_visible?(link, auth_level, default_auth)
    end)
  end

  defp valid_link?(%{"label" => label, "href" => href}) do
    is_binary(label) and label != "" and is_binary(href) and href != ""
  end

  defp valid_link?(_link), do: false

  defp link_visible?(link, auth_level, default_auth) do
    required = Map.get(link, "auth", default_auth)

    case {required, auth_level} do
      {"any", _} -> true
      {"unauthenticated", :unauthenticated} -> true
      {"authenticated", :authenticated} -> true
      {"authenticated", :admin} -> true
      {"admin", :admin} -> true
      _ -> false
    end
  end

  defp auth_level(nil), do: :unauthenticated
  defp auth_level(%{user: %{is_admin: true}}), do: :admin
  defp auth_level(%{user: _user}), do: :authenticated
  defp auth_level(_), do: :unauthenticated

  defp any_link_active?(links, current_path) do
    Enum.any?(links, &link_active?(&1, current_path))
  end

  defp link_active?(%{"href" => href} = link, current_path)
       when is_binary(href) and is_binary(current_path) do
    if external_href?(href) do
      false
    else
      case Map.get(link, "match", "prefix") do
        "exact" -> current_path == href
        _ -> String.starts_with?(current_path, href)
      end
    end
  end

  defp link_active?(_link, _current_path), do: false

  defp external_href?(href) do
    String.starts_with?(href, "http://") or String.starts_with?(href, "https://")
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

  defp translate_label(label) when is_binary(label) do
    GameServerWeb.HostLayouts.translate(label)
  end

  defp translate_label(label), do: label

  defp nav_divider(assigns) do
    ~H"""
    <li class="flex items-center px-0">
      <div class="w-px h-6 bg-base-content/20"></div>
    </li>
    """
  end
end
