defmodule GamendWeb.HostLayoutNavigation do
  @moduledoc false

  use GamendWeb, :html

  alias Gamend.Accounts.Scope
  alias GamendWeb.Plugs.LocalePath

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
          <details class="dropdown dropdown-end" data-navbar-dropdown>
            <summary class={[
              "btn gap-1 list-none",
              if(
                here?(@current_path, "/users/log_in") or
                  here?(@current_path, "/users/register"),
                do: "btn-primary",
                else: "btn-outline"
              )
            ]}>
              <.icon name="hero-user-circle-solid" class="w-4 h-4" />
              {GamendWeb.HostLayouts.translate("Account")}
              <.icon name="hero-chevron-down-solid" class="w-3 h-3" />
            </summary>
            <ul class="menu menu-sm dropdown-content mt-2 z-[1] p-2 shadow-lg bg-base-100 rounded-box w-56">
              <li>
                <.link
                  href={lp(~p"/users/log_in")}
                  class={[
                    if(here?(@current_path, "/users/log_in"),
                      do: "menu-active",
                      else: ""
                    )
                  ]}
                >
                  <.icon name="hero-arrow-right-on-rectangle-solid" class="w-4 h-4" />
                  {GamendWeb.HostLayouts.translate("Log in")}
                </.link>
              </li>
              <li>
                <.link
                  href={lp(~p"/users/register")}
                  class={[
                    if(here?(@current_path, "/users/register"),
                      do: "menu-active",
                      else: ""
                    )
                  ]}
                >
                  <.icon name="hero-user-plus-solid" class="w-4 h-4" />
                  {GamendWeb.HostLayouts.translate("Register")}
                </.link>
              </li>
            </ul>
          </details>
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

      <%!-- The language picker is NOT here: the shell renders it once, outside
            both layouts. A copy per layout puts the ~30 locale entries into the
            page twice — 26 KB of a 77 KB document — and a test asserts each
            locale link appears exactly once. It therefore sits to the right of
            this toggle rather than left of it, as it used to. --%>
      <li>
        <GamendWeb.HostLayouts.theme_toggle />
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
        custom_link_active?: any_entry_active?(assigns.account_links, assigns.current_path)
      )

    ~H"""
    <details class="dropdown dropdown-end" data-navbar-dropdown>
      <summary class={[
        "btn gap-1 list-none",
        if(
          @custom_link_active? or
            here?(@current_path, "/users/settings") or
            here?(@current_path, "/notifications") or
            here?(@current_path, "/chat"),
          do: "btn-primary",
          else: "btn-outline"
        )
      ]}>
        <.user_avatar user={Scope.user(@current_scope)} class="w-6 h-6" />
        <span class="max-w-[8rem] truncate">{display_name(Scope.user(@current_scope))}</span>
        <span
          :if={@notif_unread_count > 0}
          class="inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs font-bold rounded-full bg-error text-error-content"
        >
          {@notif_unread_count}
        </span>
        <.icon name="hero-chevron-down-solid" class="w-3 h-3" />
      </summary>
      <ul class="menu menu-sm dropdown-content mt-2 z-[1] p-2 shadow-lg bg-base-100 rounded-box w-56">
        <%!-- The nearest thing the site has to a profile card: who you are,
              and the game's own line under it (a rank, when the host stamps
              one) — the same title that shows under this player everywhere
              else, so it is not a surprise to see it here. --%>
        <li class="menu-title px-2 py-1">
          <span class="flex flex-col leading-tight text-base-content">
            <span class="truncate font-semibold">{display_name(Scope.user(@current_scope))}</span>
            <.user_title user={Scope.user(@current_scope)} />
          </span>
        </li>
        <li>
          <.link
            href={lp(~p"/users/settings")}
            class={[
              if(here?(@current_path, "/users/settings"), do: "menu-active", else: "")
            ]}
          >
            <.icon name="hero-user-circle-solid" class="w-4 h-4" />
            {GamendWeb.HostLayouts.translate("Account")}
          </.link>
        </li>
        <.dropdown_menu_entries entries={@account_links} current_path={@current_path} />

        <li>
          <.link
            href={lp(~p"/notifications")}
            class={[
              if(here?(@current_path, "/notifications"), do: "menu-active", else: "")
            ]}
          >
            <.icon name="hero-bell-solid" class="w-4 h-4" />
            {GamendWeb.HostLayouts.translate("Notifications")}
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
            href={lp(~p"/chat")}
            class={[if(here?(@current_path, "/chat"), do: "menu-active", else: "")]}
          >
            <.icon name="hero-chat-bubble-left-right-solid" class="w-4 h-4" />
            {GamendWeb.HostLayouts.translate("Chat")}
          </.link>
        </li>
        <li class="border-t border-base-300 mt-1 pt-1">
          <.link href={~p"/users/log_out"} method="delete">
            <.icon name="hero-arrow-left-on-rectangle-solid" class="w-4 h-4" />
            {GamendWeb.HostLayouts.translate("Log out")}
          </.link>
        </li>
      </ul>
    </details>
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

    # Items flagged "mobile": "pinned" render inline (left of the hamburger)
    # instead of inside the dropdown, so they stay visible on mobile.
    pinned = Enum.filter(assigns.primary_links ++ assigns.authenticated_links, &pinned_link?/1)

    assigns =
      assign(assigns,
        pinned_links: pinned,
        primary_links: Enum.reject(assigns.primary_links, &pinned_link?/1),
        authenticated_links: Enum.reject(assigns.authenticated_links, &pinned_link?/1)
      )

    ~H"""
    <div class="xl:hidden flex items-center gap-1">
      <.mobile_pinned_links links={@pinned_links} current_path={@current_path} />
      <details class="dropdown dropdown-end" data-navbar-dropdown>
        <summary
          aria-label={GamendWeb.HostLayouts.translate("Open navigation menu")}
          class="btn btn-ghost btn-circle list-none"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 6h16M4 12h16M4 18h16"
            >
            </path>
          </svg>
        </summary>
        <%!-- The menu is taller than a phone once the Learn/Social/News groups
              and the account section are expanded, and a dropdown does not
              scroll on its own: the overflowing items were simply unreachable.
              Cap it to the viewport (dvh, so the mobile URL bar collapsing does
              not cut it off) and scroll inside. `overscroll-contain` keeps the
              scroll from continuing into the page behind it.

              `flex-nowrap` is what makes the cap scroll instead of reflow:
              daisyUI's `.menu` is `flex-flow: column wrap`, so a max-height on
              its own wrapped the items into a SECOND COLUMN off to the side —
              vertically unscrollable and horizontally clipped, which is worse
              than the overflow it was meant to fix. --%>
        <ul class="menu menu-sm dropdown-content mt-3 z-[1] max-h-[calc(100dvh-5rem)] flex-nowrap overflow-y-auto overflow-x-hidden overscroll-contain p-2 shadow bg-base-100 rounded-box w-80 text-lg">
          <%= if @current_scope do %>
            <.mobile_account_menu
              current_scope={@current_scope}
              current_path={@current_path}
              notif_unread_count={@notif_unread_count}
              account_links={@account_links}
            />

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
                href={lp(~p"/users/log_in")}
                class={[
                  "btn w-full",
                  if(here?(@current_path, "/users/log_in"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-arrow-right-on-rectangle-solid" class="w-4 h-4" />
                {GamendWeb.HostLayouts.translate("Log in")}
              </a>
            </li>
            <li>
              <a
                href={lp(~p"/users/register")}
                class={[
                  "btn w-full",
                  if(here?(@current_path, "/users/register"),
                    do: "btn-primary",
                    else: "btn-ghost"
                  )
                ]}
              >
                <.icon name="hero-user-plus-solid" class="w-4 h-4" />
                {GamendWeb.HostLayouts.translate("Register")}
              </a>
            </li>

            <.mobile_nav_links
              links={@primary_links}
              current_path={@current_path}
              inactive_class="btn-ghost"
            />
          <% end %>

          <%!-- The language picker lives in the header bar beside this menu,
                rendered once for both layouts — see `desktop_nav/1`. --%>
          <li class="mt-2">
            <div class="flex justify-center">
              <GamendWeb.HostLayouts.theme_toggle />
            </div>
          </li>
        </ul>
      </details>
    </div>
    """
  end

  attr :locale, :string, required: true
  attr :current_path, :string, default: nil
  attr :current_query, :string, default: ""
  attr :known_locales, :list, default: []

  @doc """
  The language picker's button(s).

  Two controls, one visible at a time, mirroring the in-page language selector
  (the host's in-page selector) so the site opens a language list
  the same way everywhere:

    * from `sm` up, a `<details>` dropdown like every other navbar menu;
    * below it, a button opening the bottom sheet `language_modal/1` renders.

  A phone gets a sheet rather than a panel because a dropdown is positioned
  against its *button*, and the globe is not the last thing in the bar — the
  hamburger is. Any panel wide enough to be useful therefore starts off the left
  edge of the screen.

  This does mean the ~30 locale entries are in the document twice, about 13 KB.
  The sheet is why: it is `position: fixed`, and the header's `backdrop-blur`
  makes the header a containing block for fixed descendants, so the sheet has to
  live outside the header while the dropdown lives inside it.
  """
  def language_dropdown(assigns) do
    assigns =
      assign(assigns,
        label: locale_label(assigns.locale),
        flag_code: locale_flag_code(assigns.locale),
        locale_links:
          locale_links(assigns.current_path, assigns.current_query, assigns.known_locales)
      )

    ~H"""
    <div class="contents">
      <%!-- `priority`: this flag is in the header of every page, so a lazy one
            pops in after the label on each refresh, and a merely eager one
            queues behind whatever that page is full of. --%>
      <label for="lang-modal" class="btn gap-1 list-none btn-outline cursor-pointer sm:hidden">
        <.flag code={@flag_code} priority class="rounded-[2px] ring-1 ring-base-content/10" />
        <.icon name="hero-chevron-down-solid" class="w-3 h-3" />
      </label>

      <details class="dropdown dropdown-end hidden sm:block" data-navbar-dropdown>
        <summary class="btn gap-1 list-none btn-outline">
          <.flag code={@flag_code} priority class="rounded-[2px] ring-1 ring-base-content/10" />
          {@label}
          <.icon name="hero-chevron-down-solid" class="w-3 h-3" />
        </summary>

        <%!-- Four columns at most: "Espa\u00f1ol" and "Espa\u00f1ol (Espa\u00f1a)" truncate to
              the same string in five, which makes them impossible to tell apart.

              Deliberately not daisyUI's `menu menu-sm` like the sibling panels:
              `.menu li` is `display:flex` and its `> a` will not shrink below
              its content, so long labels ("Portugu\u00eas do Brasil") burst out of
              their grid track and over the next column. `menu` is built for a
              vertical list; this is a grid, and it only needs the surface. --%>
        <ul class="dropdown-content z-[100] mt-2 grid max-h-[70vh] w-[min(78vw,44rem)] grid-cols-3 gap-1 overflow-y-auto rounded-box bg-base-100 p-2 shadow-lg lg:grid-cols-4">
          <.locale_option :for={link <- @locale_links} link={link} locale={@locale} />
        </ul>
      </details>
    </div>
    """
  end

  attr :locale, :string, required: true
  attr :current_path, :string, default: nil
  attr :current_query, :string, default: ""
  attr :known_locales, :list, default: []

  @doc """
  The phone-sized language picker: a bottom sheet, like the in-page selector's.

  Rendered by the shell **outside** `<header>`. It is `position: fixed`, and the
  header's `backdrop-blur` would make the header its containing block — the
  sheet would then pin to the header's box and open above the fold instead of
  along the bottom of the screen.
  """
  def language_modal(assigns) do
    assigns =
      assign(assigns,
        label: locale_label(assigns.locale),
        locale_links:
          locale_links(assigns.current_path, assigns.current_query, assigns.known_locales)
      )

    ~H"""
    <%!-- The checkbox is only a state holder — the visible labels toggle it.
          Without tabindex="-1" it is a Tab stop (daisyUI hides it with
          `opacity: 0`, not `display: none`), and on desktop it was the page's
          *first* one: an invisible control receiving focus. --%>
    <input
      type="checkbox"
      id="lang-modal"
      class="peer modal-toggle sm:hidden"
      tabindex="-1"
      aria-label={GamendWeb.HostLayouts.translate("Choose language")}
    />
    <%!-- `peer` + `content-visibility`: a closed daisyUI modal is only
          `visibility: hidden`, so its subtree is still laid out and every flag
          in it is fetched on page load for a sheet nobody opened. Skipping the
          subtree outright is what stops that; it renders normally the moment
          the toggle is checked. --%>
    <div
      class="modal modal-bottom z-[100] peer-[:not(:checked)]:[content-visibility:hidden] sm:hidden"
      role="dialog"
    >
      <div class="modal-box max-w-2xl p-3">
        <div class="flex items-center justify-between gap-3">
          <h3 class="flex items-center gap-2 text-sm font-black uppercase tracking-[0.12em]">
            <.icon name="hero-globe-alt-solid" class="w-4 h-4" />
            {@label}
          </h3>
          <label
            for="lang-modal"
            aria-label={GamendWeb.HostLayouts.translate("Close language picker")}
            class="btn btn-ghost btn-square btn-sm"
          >
            <.icon name="hero-x-mark-solid" class="size-4" />
          </label>
        </div>

        <%!-- Same rule as the in-page selector: fit as many tiles as there is
              room for, rather than a fixed column count that squeezes them. --%>
        <ul class="mt-3 grid max-h-[60vh] grid-cols-[repeat(auto-fit,minmax(7rem,1fr))] gap-1 overflow-y-auto">
          <.locale_option :for={link <- @locale_links} link={link} locale={@locale} />
        </ul>
      </div>
      <label class="modal-backdrop" for="lang-modal">Close</label>
    </div>
    """
  end

  attr :link, :map, required: true
  attr :locale, :string, required: true

  # One row, shared by the dropdown and the sheet so they cannot drift apart.
  # `min-w-0` on both the item and the anchor: a grid track and a flex item each
  # default to min-content width, so without it the longest label ("Portugu\u00eas do
  # Brasil") pushes its column over the next one instead of letting `truncate` do
  # its job.
  #
  # The current locale is a solid `bg-primary` with its paired content color:
  # the previous primary-tinted text on a primary-tinted fill fell below AA
  # contrast on themed hosts.
  defp locale_option(assigns) do
    ~H"""
    <li class="min-w-0 list-none">
      <a
        href={@link.href}
        rel={@link[:rel]}
        aria-current={if(@link.locale == @locale, do: "true")}
        class={[
          "flex min-w-0 items-center gap-2 rounded px-2 py-2 text-sm transition-colors",
          if(@link.locale == @locale,
            do: "bg-primary font-semibold text-primary-content",
            else: "hover:bg-base-200"
          )
        ]}
      >
        <%!-- `deferred`: this row is in the document ~30 times over, in a
              dropdown and a sheet that are both closed. --%>
        <.flag
          code={@link.flag_code}
          deferred
          class="rounded-[2px] shadow-sm ring-1 ring-base-content/10"
        />
        <span class="truncate">{@link.label}</span>
      </a>
    </li>
    """
  end

  attr :links, :list, default: []
  attr :current_path, :string, default: nil
  attr :inactive_class, :string, required: true

  defp main_nav_links(assigns) do
    ~H"""
    <%= for entry <- @links do %>
      <li>
        <.main_nav_link_item
          link={entry}
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
    <%= for entry <- @links do %>
      <li class="w-full">
        <.mobile_nav_link_item
          link={entry}
          current_path={@current_path}
          inactive_class={@inactive_class}
        />
      </li>
    <% end %>
    """
  end

  attr :links, :list, default: []
  attr :current_path, :string, default: nil

  # Compact inline buttons for "mobile": "pinned" leaf links, shown left of the
  # hamburger. Icon + (possibly dynamic) label, no dropdown wrapping.
  defp mobile_pinned_links(assigns) do
    ~H"""
    <a
      :for={link <- @links}
      href={if(readonly?(link), do: nil, else: link["href"])}
      aria-disabled={if(readonly?(link), do: "true")}
      class={
        if readonly?(link) do
          "inline-flex items-center gap-1 px-2 pointer-events-none cursor-default"
        else
          [
            "btn btn-ghost btn-sm gap-1 px-2",
            if(entry_active?(link, @current_path), do: "btn-active")
          ]
        end
      }
    >
      <.icon :if={link["icon"]} name={link["icon"]} class={icon_class(link["color"])} />
      <span class="text-sm font-semibold">{translate_label(link["label"])}</span>
    </a>
    """
  end

  # A leaf link (not a dropdown group) explicitly pinned outside the mobile menu.
  defp pinned_link?(entry) do
    Map.get(entry, "mobile") == "pinned" and not dropdown_entry?(entry)
  end

  attr :current_scope, :map, required: true
  attr :current_path, :string, default: nil
  attr :notif_unread_count, :integer, default: 0
  attr :account_links, :list, default: []

  # Mobile account section: collapsible group headed by the user's name (like
  # the desktop user menu). Holds Account, Notifications, Chat, then the
  # config account_links (admin items) last, then Log out.
  defp mobile_account_menu(assigns) do
    active? =
      account_path_active?(assigns.current_path, "/users/settings") or
        account_path_active?(assigns.current_path, "/notifications") or
        account_path_active?(assigns.current_path, "/chat") or
        any_entry_active?(assigns.account_links, assigns.current_path)

    assigns = assign(assigns, active?: active?)

    ~H"""
    <li class="w-full">
      <details open={@active?} class="group w-full">
        <summary class={[
          "btn w-full relative cursor-pointer list-none summary-no-marker",
          if(@active?, do: "btn-primary", else: "btn-ghost")
        ]}>
          <span class="flex items-center gap-2">
            <.user_avatar user={Scope.user(@current_scope)} class="w-5 h-5" />
            <span class="truncate">{display_name(Scope.user(@current_scope))}</span>
            <span
              :if={@notif_unread_count > 0}
              class="ms-0.5 inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs font-bold rounded-full bg-error text-error-content"
            >
              {@notif_unread_count}
            </span>
          </span>
          <.icon
            name="hero-chevron-down-solid"
            class="w-3 h-3 absolute end-3 transition-transform group-open:rotate-180"
          />
        </summary>
        <ul class="ps-4 mt-1 w-full">
          <li class="w-full">
            <a
              href={lp(~p"/users/settings")}
              class={["btn w-full", account_item_class(@current_path, "/users/settings")]}
            >
              <.icon name="hero-user-circle-solid" class="w-4 h-4" />
              {GamendWeb.HostLayouts.translate("Account")}
            </a>
          </li>
          <li class="w-full">
            <a
              href={lp(~p"/notifications")}
              class={["btn w-full", account_item_class(@current_path, "/notifications")]}
            >
              <.icon name="hero-bell-solid" class="w-4 h-4" />
              {GamendWeb.HostLayouts.translate("Notifications")}
              <span
                :if={@notif_unread_count > 0}
                class="ms-0.5 inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs font-bold rounded-full bg-error text-error-content"
              >
                {@notif_unread_count}
              </span>
            </a>
          </li>
          <li class="w-full">
            <a href={lp(~p"/chat")} class={["btn w-full", account_item_class(@current_path, "/chat")]}>
              <.icon name="hero-chat-bubble-left-right-solid" class="w-4 h-4" />
              {GamendWeb.HostLayouts.translate("Chat")}
            </a>
          </li>
          <.mobile_nav_links
            links={@account_links}
            current_path={@current_path}
            inactive_class="btn-ghost"
          />
          <li class="border-t border-base-300 mt-1 pt-1 w-full">
            <.link href={~p"/users/log_out"} method="delete" class="btn btn-ghost w-full">
              <.icon name="hero-arrow-left-on-rectangle-solid" class="w-4 h-4" />
              {GamendWeb.HostLayouts.translate("Log out")}
            </.link>
          </li>
        </ul>
      </details>
    </li>
    """
  end

  defp account_path_active?(current_path, prefix), do: here?(current_path || "", prefix)

  defp account_item_class(current_path, prefix) do
    if account_path_active?(current_path, prefix), do: "btn-primary", else: "btn-ghost"
  end

  attr :link, :map, required: true
  attr :current_path, :string, default: nil
  attr :inactive_class, :string, required: true

  defp main_nav_link_item(assigns) do
    active? = entry_active?(assigns.link, assigns.current_path)

    assigns = assign(assigns, active?: active?)

    ~H"""
    <%= if dropdown_entry?(@link) do %>
      <details class="dropdown" data-navbar-dropdown>
        <summary class={[
          "btn list-none",
          if(@active?, do: "btn-primary", else: @inactive_class)
        ]}>
          <.icon :if={@link["icon"]} name={@link["icon"]} class={icon_class(@link["color"])} />
          {translate_label(@link["label"])}
          <.icon name="hero-chevron-down-solid" class="w-3 h-3" />
        </summary>
        <ul class="menu menu-sm dropdown-content mt-2 z-[1] p-2 shadow-lg bg-base-100 rounded-box w-64">
          <.dropdown_menu_entries entries={@link["items"]} current_path={@current_path} />
        </ul>
      </details>
    <% else %>
      <a
        href={if(readonly?(@link), do: nil, else: @link["href"])}
        target={if(@link["external"], do: "_blank", else: nil)}
        rel={if(@link["external"], do: "noopener noreferrer", else: nil)}
        aria-disabled={if(readonly?(@link), do: "true")}
        class={
          if readonly?(@link) do
            "inline-flex items-center gap-2 px-2 pointer-events-none cursor-default"
          else
            ["btn", if(@active?, do: "btn-primary", else: @inactive_class)]
          end
        }
      >
        <.icon :if={@link["icon"]} name={@link["icon"]} class={icon_class(@link["color"])} />
        {translate_label(@link["label"])}
      </a>
    <% end %>
    """
  end

  attr :link, :map, required: true
  attr :current_path, :string, default: nil
  attr :inactive_class, :string, required: true

  defp mobile_nav_link_item(assigns) do
    active? = entry_active?(assigns.link, assigns.current_path)

    assigns = assign(assigns, active?: active?)

    ~H"""
    <%= if dropdown_entry?(@link) do %>
      <details open={@active?} class="group w-full">
        <summary class={[
          "btn w-full relative cursor-pointer list-none summary-no-marker",
          if(@active?, do: "btn-primary", else: @inactive_class)
        ]}>
          <span class="flex items-center gap-2">
            <.icon :if={@link["icon"]} name={@link["icon"]} class={icon_class(@link["color"])} />
            <span>{translate_label(@link["label"])}</span>
          </span>
          <.icon
            name="hero-chevron-down-solid"
            class="w-3 h-3 absolute end-3 transition-transform group-open:rotate-180"
          />
        </summary>
        <ul class="ps-4 mt-1 w-full">
          <.mobile_nav_links
            links={@link["items"]}
            current_path={@current_path}
            inactive_class={@inactive_class}
          />
        </ul>
      </details>
    <% else %>
      <a
        href={if(readonly?(@link), do: nil, else: @link["href"])}
        target={if(@link["external"], do: "_blank", else: nil)}
        rel={if(@link["external"], do: "noopener noreferrer", else: nil)}
        aria-disabled={if(readonly?(@link), do: "true")}
        class={
          if readonly?(@link) do
            "inline-flex items-center gap-2 px-2 w-full pointer-events-none cursor-default"
          else
            ["btn w-full", if(@active?, do: "btn-primary", else: @inactive_class)]
          end
        }
      >
        <.icon :if={@link["icon"]} name={@link["icon"]} class={icon_class(@link["color"])} />
        {translate_label(@link["label"])}
      </a>
    <% end %>
    """
  end

  attr :entries, :list, default: []
  attr :current_path, :string, default: nil

  defp dropdown_menu_entries(assigns) do
    ~H"""
    <%= for entry <- @entries do %>
      <.dropdown_menu_entry entry={entry} current_path={@current_path} />
    <% end %>
    """
  end

  attr :entry, :map, required: true
  attr :current_path, :string, default: nil

  defp dropdown_menu_entry(assigns) do
    active? = entry_active?(assigns.entry, assigns.current_path)

    assigns = assign(assigns, active?: active?)

    ~H"""
    <%= if dropdown_entry?(@entry) do %>
      <li>
        <details open={@active?}>
          <summary class={[if(@active?, do: "menu-active", else: "")]}>
            <.icon :if={@entry["icon"]} name={@entry["icon"]} class={icon_class(@entry["color"])} />
            {translate_label(@entry["label"])}
          </summary>
          <ul>
            <.dropdown_menu_entries entries={@entry["items"]} current_path={@current_path} />
          </ul>
        </details>
      </li>
    <% else %>
      <li>
        <a
          href={if(readonly?(@entry), do: nil, else: @entry["href"])}
          target={if(@entry["external"], do: "_blank", else: nil)}
          rel={if(@entry["external"], do: "noopener noreferrer", else: nil)}
          aria-disabled={if(readonly?(@entry), do: "true")}
          class={[
            if(@active?, do: "menu-active", else: ""),
            if(readonly?(@entry), do: "pointer-events-none cursor-default")
          ]}
        >
          <.icon :if={@entry["icon"]} name={@entry["icon"]} class={icon_class(@entry["color"])} />
          {translate_label(@entry["label"])}
        </a>
      </li>
    <% end %>
    """
  end

  defp prepare_navigation_assigns(assigns) do
    scope = assigns.current_scope
    auth_level = auth_level(Scope.user(scope))

    assign(assigns,
      primary_links:
        section_entries(assigns.navigation, "primary_links", auth_level, "any", scope),
      guest_links:
        section_entries(assigns.navigation, "guest_links", auth_level, "unauthenticated", scope),
      authenticated_links:
        section_entries(
          assigns.navigation,
          "authenticated_links",
          auth_level,
          "authenticated",
          scope
        ),
      account_links:
        section_entries(assigns.navigation, "account_links", auth_level, "authenticated", scope)
    )
  end

  defp section_entries(navigation, key, auth_level, default_auth, scope) do
    navigation
    |> Map.get(key, [])
    |> Enum.map(&normalize_navigation_entry(&1, auth_level, default_auth, scope))
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_navigation_entry(%{"items" => items} = entry, auth_level, default_auth, scope)
       when is_list(items) do
    visible_items =
      items
      |> Enum.map(&normalize_navigation_entry(&1, auth_level, default_auth, scope))
      |> Enum.reject(&is_nil/1)

    if valid_group?(entry) and visible_items != [] and
         link_visible?(entry, auth_level, default_auth) do
      entry
      |> Map.put("items", visible_items)
      |> resolve_entry_label(scope)
    end
  end

  defp normalize_navigation_entry(entry, auth_level, default_auth, scope) do
    if valid_link?(entry) and link_visible?(entry, auth_level, default_auth) do
      resolve_entry_label(entry, scope)
    end
  end

  # Resolves {Module.Func} tokens in a nav entry's label. Each token calls the
  # named function (arity 1, given the current scope) and substitutes its
  # stringified result; the config is host-authored, and resolution is guarded
  # (only already-loaded module/atoms, failures render as empty). Labels
  # without a token are untouched (translation happens later at render).
  defp resolve_entry_label(%{"label" => label} = entry, scope) when is_binary(label) do
    if String.contains?(label, "{") do
      Map.put(entry, "label", resolve_dynamic_tokens(label, scope))
    else
      entry
    end
  end

  defp resolve_entry_label(entry, _scope), do: entry

  defp resolve_dynamic_tokens(label, scope) do
    Regex.replace(~r/\{([^{}]+)\}/, label, fn _match, token ->
      resolve_token(String.trim(token), scope)
    end)
  end

  defp resolve_token(token, scope) do
    parts = String.split(token, ".")
    {fun_str, mod_parts} = List.pop_at(parts, -1)

    # Build + load the module rather than String.to_existing_atom: the provider
    # module is named only in trusted config (never referenced as a literal in
    # code), so its atom/beam may not be loaded yet in this process.
    with false <- mod_parts == [],
         module = Module.concat(mod_parts),
         true <- Code.ensure_loaded?(module),
         fun = String.to_atom(fun_str),
         true <- function_exported?(module, fun, 1) do
      module |> apply(fun, [scope]) |> to_string()
    else
      _ -> ""
    end
  rescue
    _ -> ""
  catch
    _, _ -> ""
  end

  defp valid_group?(%{"label" => label, "items" => items}) do
    is_binary(label) and label != "" and is_list(items)
  end

  defp valid_group?(_entry), do: false

  defp valid_link?(%{"label" => label} = entry) do
    is_binary(label) and label != "" and
      (readonly?(entry) or (is_binary(entry["href"]) and entry["href"] != ""))
  end

  defp valid_link?(_link), do: false

  # A display-only item ("readonly": true) renders as a non-interactive badge
  # (icon + label, no href/click) — e.g. a live status/value indicator.
  defp readonly?(entry), do: Map.get(entry, "readonly") == true

  @doc """
  Whether `entry` should be shown to a viewer with this `current_scope`.

  Same `"auth"` convention the nav uses (`"any"`, `"unauthenticated"`,
  `"authenticated"`, `"admin"`, or `"admin_only": true`), exposed so the footer
  filters identically — a link to a page the viewer cannot open is a link to an
  error page.
  """
  @spec entry_visible?(map(), map() | nil) :: boolean()
  def entry_visible?(entry, current_scope) do
    link_visible?(entry, auth_level(Scope.user(current_scope)), "any")
  end

  defp link_visible?(link, auth_level, default_auth) do
    required = required_auth(link, default_auth)

    case {required, auth_level} do
      {"any", _} -> true
      {"unauthenticated", :unauthenticated} -> true
      {"authenticated", :authenticated} -> true
      {"authenticated", :admin} -> true
      {"admin", :admin} -> true
      _ -> false
    end
  end

  defp required_auth(entry, default_auth) do
    auth = Map.get(entry, "auth") || Map.get(entry, :auth)

    cond do
      Map.get(entry, "admin_only") == true or Map.get(entry, :admin_only) == true -> "admin"
      is_binary(auth) -> auth
      is_atom(auth) and not is_nil(auth) -> Atom.to_string(auth)
      true -> default_auth
    end
  end

  defp auth_level(%{is_admin: true}), do: :admin
  defp auth_level(%{}), do: :authenticated
  defp auth_level(_), do: :unauthenticated

  defp any_entry_active?(entries, current_path) do
    Enum.any?(entries, &entry_active?(&1, current_path))
  end

  defp entry_active?(%{"items" => items}, current_path) when is_list(items) do
    Enum.any?(items, &entry_active?(&1, current_path))
  end

  defp entry_active?(entry, current_path), do: link_active?(entry, current_path)

  defp dropdown_entry?(%{"items" => items}) when is_list(items), do: true
  defp dropdown_entry?(_entry), do: false

  defp link_active?(%{"href" => href} = link, current_path)
       when is_binary(href) and is_binary(current_path) do
    if external_href?(href) do
      false
    else
      # Both sides get stripped: the href now carries the reader's locale
      # prefix, while `current_path` may be the clean path the PageMeta plug
      # stashed. Comparing them raw left the whole nav unhighlighted under /fr.
      known = GamendWeb.GettextSync.known_locales()
      href = GamendWeb.HostLayouts.strip_locale_prefix(href, known)
      current_path = GamendWeb.HostLayouts.strip_locale_prefix(current_path, known)

      case Map.get(link, "match", "prefix") do
        "exact" -> current_path == href
        _ -> String.starts_with?(current_path, href)
      end
    end
  end

  defp link_active?(_link, _current_path), do: false

  # Keeps the reader's locale prefix on the hand-written account links, the
  # same way `localize_hrefs/2` does for every configured nav entry.
  defp lp(href) do
    GamendWeb.HostLayouts.localized_href(href, GamendWeb.HostLayouts.current_locale())
  end

  # `current_path` carries the locale prefix on a prefixed page; these
  # hand-written active checks compare against clean paths.
  defp here?(current_path, prefix) when is_binary(current_path) do
    current_path
    |> GamendWeb.HostLayouts.strip_locale_prefix(GamendWeb.GettextSync.known_locales())
    |> String.starts_with?(prefix)
  end

  defp here?(_current_path, _prefix), do: false

  defp external_href?(href) do
    String.starts_with?(href, "http://") or String.starts_with?(href, "https://")
  end

  defp locale_links(current_path, current_query, known_locales) do
    locale_labels = GamendWeb.HostLayouts.locale_labels()
    base_path = GamendWeb.HostLayouts.strip_locale_prefix(current_path || "/", known_locales)

    query_suffix =
      if is_binary(current_query) and current_query != "", do: "?" <> current_query, else: ""

    # A locale prefix is only served as a real page for the paths in
    # `:localized_paths`; everywhere else it redirects to the clean URL. The
    # switcher still needs those links — following one is how a reader changes
    # language — but a crawler following 30 of them per page just generates
    # redirects. On this site that was 278 URLs reported as "Page with
    # redirect", i.e. most of the crawl budget spent on nothing.
    crawlable? = LocalePath.localized_path?(base_path)
    default_locale = LocalePath.default_locale()

    Enum.map(known_locales, fn locale ->
      # BCP-47 in the URL (`/pt-BR`), not the gettext form (`/pt_BR`): that is
      # what `hreflang` advertises and what the router declares, so emitting
      # the underscore here pointed at routes that do not exist.
      prefix = "/" <> LocalePath.url_locale(locale)

      # The default locale is never served under a prefix — `/en/about`
      # redirects to `/about` — so linking it prefixed publishes a followable
      # link that can only ever redirect. On a localized path `nofollow` does
      # not apply, so every page shipped one of these: 229 URLs reported as
      # "Page with redirect". Point at the clean URL the sitemap and the
      # `hreflang` alternates already use.
      #
      # The clean URL alone is not enough to *switch* to it: the reader's
      # session still holds the language they are leaving, and `LocalePath`
      # redirects them back to it. `?setlang=` is what says otherwise. It is the
      # one switcher link a crawler must not follow — it can only redirect —
      # but nothing is lost by that: `hreflang="en"` and `x-default` in the head
      # already point at the same clean URL.
      href =
        cond do
          locale == default_locale ->
            if(base_path == "/", do: "/", else: base_path) <> switch_suffix(query_suffix, locale)

          base_path == "/" ->
            prefix <> query_suffix

          true ->
            prefix <> base_path <> query_suffix
        end

      %{
        locale: locale,
        label: Map.get(locale_labels, locale, locale),
        href: href,
        rel: unless(crawlable? and locale != default_locale, do: "nofollow"),
        flag_code: locale_flag_code(locale)
      }
    end)
  end

  defp switch_suffix("", locale), do: "?" <> LocalePath.switch_param() <> "=" <> locale

  defp switch_suffix(query, locale),
    do: query <> "&" <> LocalePath.switch_param() <> "=" <> locale

  defp locale_label(locale) do
    locale
    |> then(&Map.get(GamendWeb.HostLayouts.locale_labels(), &1, &1))
  end

  defp locale_flag_code("ar"), do: "sa"
  defp locale_flag_code("bg"), do: "bg"
  defp locale_flag_code("cs"), do: "cz"
  defp locale_flag_code("da"), do: "dk"
  defp locale_flag_code("de"), do: "de"
  defp locale_flag_code("el"), do: "gr"
  defp locale_flag_code("en"), do: "gb"
  defp locale_flag_code("es"), do: "es"
  defp locale_flag_code("fi"), do: "fi"
  defp locale_flag_code("fr"), do: "fr"
  defp locale_flag_code("hu"), do: "hu"
  defp locale_flag_code("id"), do: "id"
  defp locale_flag_code("it"), do: "it"
  defp locale_flag_code("ja"), do: "jp"
  defp locale_flag_code("ko"), do: "kr"
  defp locale_flag_code("nl"), do: "nl"
  defp locale_flag_code("no"), do: "no"
  defp locale_flag_code("pl"), do: "pl"
  defp locale_flag_code("pt"), do: "pt"
  defp locale_flag_code("pt_BR"), do: "br"
  defp locale_flag_code("ro"), do: "ro"
  defp locale_flag_code("ru"), do: "ru"
  defp locale_flag_code("sv"), do: "se"
  defp locale_flag_code("th"), do: "th"
  defp locale_flag_code("tr"), do: "tr"
  defp locale_flag_code("uk"), do: "ua"
  defp locale_flag_code("vi"), do: "vn"
  defp locale_flag_code("zh_CN"), do: "cn"
  defp locale_flag_code("zh_TW"), do: "tw"
  defp locale_flag_code(_locale), do: "xx"

  defp display_name(user) do
    cond do
      is_binary(user.display_name) and user.display_name != "" -> user.display_name
      is_binary(user.email) and user.email != "" -> user.email
      true -> "User"
    end
  end

  defp translate_label(label) when is_binary(label) do
    GamendWeb.HostLayouts.translate(label)
  end

  defp translate_label(label), do: label

  # Base icon size plus an optional per-item color class from config.
  defp icon_class(color) when is_binary(color) and color != "", do: "w-4 h-4 " <> color
  defp icon_class(_color), do: "w-4 h-4"

  defp nav_divider(assigns) do
    ~H"""
    <li class="flex items-center px-0">
      <div class="w-px h-6 bg-base-content/20"></div>
    </li>
    """
  end
end
