defmodule GameServerWeb.AchievementsLive do
  @moduledoc """
  Public-facing achievements page.

  Anonymous users see all non-hidden achievements.
  Logged-in users see their progress and unlock status.
  """
  use GameServerWeb, :live_view

  alias GameServer.Achievements
  alias GameServer.Achievements.Achievement

  @page_size 100

  @impl true
  def mount(_params, _session, socket) do
    user = get_user(socket)

    if connected?(socket) do
      Achievements.subscribe_achievements()
      if user, do: Phoenix.PubSub.subscribe(GameServer.PubSub, "user:#{user.id}")
    end

    socket =
      socket
      |> assign(:locale, Gettext.get_locale(GameServerWeb.Gettext))
      |> assign(:page_title, gettext("Achievements"))
      |> assign(:page, 1)
      |> assign(:page_size, @page_size)
      |> assign(:filter, "all")
      |> load_achievements()

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:page, 1)
     |> load_achievements()}
  end

  def handle_event("prev_page", _params, socket) do
    {:noreply,
     socket
     |> assign(:page, max(1, socket.assigns.page - 1))
     |> load_achievements()}
  end

  def handle_event("next_page", _params, socket) do
    {:noreply,
     socket
     |> assign(:page, socket.assigns.page + 1)
     |> load_achievements()}
  end

  def handle_event("page_size", %{"size" => size}, socket) do
    size = size |> String.to_integer() |> min(200) |> max(24)

    {:noreply,
     socket
     |> assign(:page_size, size)
     |> assign(:page, 1)
     |> load_achievements()}
  end

  @impl true
  def handle_info({:achievement_unlocked, _ua}, socket) do
    {:noreply, load_achievements(socket)}
  end

  def handle_info({:achievement_unlocked, _user_id, _ua}, socket) do
    {:noreply, load_achievements(socket)}
  end

  def handle_info({:achievement_progress, _ua}, socket) do
    {:noreply, load_achievements(socket)}
  end

  def handle_info({:achievements_changed}, socket) do
    {:noreply, load_achievements(socket)}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp get_user(socket) do
    case socket.assigns do
      %{current_scope: %{user: u}} when u != nil -> u
      _ -> nil
    end
  end

  defp load_achievements(socket) do
    user = get_user(socket)
    page = socket.assigns.page
    page_size = socket.assigns.page_size
    filter = socket.assigns.filter

    opts = [page: page, page_size: page_size, include_hidden: true, filter: filter]
    opts = if user, do: Keyword.put(opts, :user_id, user.id), else: opts

    items = Achievements.list_achievements(opts)

    count_opts = [include_hidden: true, filter: filter]
    count_opts = if user, do: Keyword.put(count_opts, :user_id, user.id), else: count_opts

    total_count = Achievements.count_achievements(count_opts)
    total_pages = max(ceil(total_count / page_size), 1)

    user_unlocked_count = if user, do: Achievements.count_user_achievements(user.id), else: 0

    socket
    |> assign(:achievements, items)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
    |> assign(:unlocked_count, user_unlocked_count)
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 class="text-3xl font-bold">{gettext("Achievements")}</h1>
            <p class="text-base-content/60 mt-1">
              <%= if @current_scope && @current_scope.user do %>
                {gettext("Unlocked")}: {@unlocked_count} / {@total_count}
              <% else %>
                {gettext("Achievements")}: {@total_count}
              <% end %>
            </p>
          </div>

          <%!-- Filter buttons (only for logged-in users) --%>
          <%= if @current_scope && @current_scope.user do %>
            <div class="flex flex-wrap gap-2">
              <button
                :for={
                  {label, value} <- [
                    {gettext("All"), "all"},
                    {gettext("Unlocked"), "unlocked"},
                    {gettext("Locked"), "locked"},
                    {gettext("In Progress"), "in_progress"}
                  ]
                }
                phx-click="filter"
                phx-value-filter={value}
                class={[
                  "btn btn-sm",
                  if(@filter == value, do: "btn-primary", else: "btn-outline")
                ]}
              >
                {label}
              </button>
            </div>
          <% end %>
        </div>

        <%!-- Overall progress bar (logged-in users) --%>
        <%= if @current_scope && @current_scope.user && @total_count > 0 do %>
          <div class="bg-base-200 rounded-xl p-4">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium">
                {gettext("Status")}
              </span>
              <span class="text-sm font-bold text-primary">
                {trunc(@unlocked_count / @total_count * 100)}%
              </span>
            </div>
            <div class="w-full bg-base-300 rounded-full h-3 overflow-hidden">
              <div
                class="bg-gradient-to-r from-primary to-secondary h-3 rounded-full transition-all duration-500"
                style={"width: #{trunc(@unlocked_count / @total_count * 100)}%"}
              >
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Achievement grid --%>
        <%= if @achievements == [] do %>
          <div class="text-center py-16 text-base-content/50">
            <.icon name="hero-trophy" class="w-16 h-16 mx-auto mb-4 opacity-30" />
            <p class="text-lg">
              {gettext("No results.")}
            </p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <.achievement_card
              :for={item <- @achievements}
              item={item}
              logged_in={@current_scope != nil && @current_scope.user != nil}
              locale={@locale}
            />
          </div>
        <% end %>

        <%!-- Pagination --%>
        <div class="flex justify-center items-center pt-4">
          <.pagination
            page={@page}
            total_pages={@total_pages}
            total_count={@total_count}
            page_size={@page_size}
            on_prev="prev_page"
            on_next="next_page"
            on_page_size="page_size"
            page_sizes={[24, 50, 100, 200]}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  defp achievement_card(assigns) do
    achievement = assigns.item.achievement
    progress = assigns.item.progress
    unlocked_at = assigns.item.unlocked_at
    logged_in = assigns.logged_in
    locale = assigns.locale
    target = achievement.progress_target || 1
    unlocked? = unlocked_at != nil
    hidden? = achievement.hidden && !unlocked?
    pct = if target > 0, do: min(trunc(progress / target * 100), 100), else: 0

    localized_title = Achievement.localized_title(achievement, locale)
    localized_desc = Achievement.localized_description(achievement, locale)

    assigns =
      assigns
      |> assign(:achievement, achievement)
      |> assign(:progress, progress)
      |> assign(:unlocked_at, unlocked_at)
      |> assign(:target, target)
      |> assign(:unlocked?, unlocked?)
      |> assign(:hidden?, hidden?)
      |> assign(:pct, pct)
      |> assign(:logged_in, logged_in)
      |> assign(:localized_title, localized_title)
      |> assign(:localized_desc, localized_desc)

    ~H"""
    <div class={[
      "card bg-base-100 shadow-sm hover:shadow-md transition-all duration-200 border",
      cond do
        @unlocked? -> "border-success/30"
        @hidden? -> "border-base-content/10 opacity-60"
        true -> "border-base-300"
      end
    ]}>
      <div class="card-body p-4">
        <%!-- Top row: icon + title --%>
        <div class="flex items-start gap-3">
          <%!-- Icon or placeholder --%>
          <div class={[
            "flex-shrink-0 w-12 h-12 rounded-lg flex items-center justify-center text-2xl",
            cond do
              @unlocked? -> "bg-success/20 text-success"
              @hidden? -> "bg-base-300/50 text-base-content/20"
              true -> "bg-base-300 text-base-content/30"
            end
          ]}>
            <%= if @hidden? do %>
              <.icon name="hero-question-mark-circle" class="w-7 h-7" />
            <% else %>
              <%= if @achievement.icon_url && @achievement.icon_url != "" do %>
                <img
                  src={@achievement.icon_url}
                  alt={@achievement.title}
                  class={["w-8 h-8 object-contain", if(!@unlocked?, do: "opacity-40 grayscale")]}
                />
              <% else %>
                <.icon
                  name={if @unlocked?, do: "hero-trophy", else: "hero-lock-closed"}
                  class="w-7 h-7"
                />
              <% end %>
            <% end %>
          </div>

          <div class="flex-1 min-w-0">
            <h3 class={[
              "font-semibold text-sm leading-tight truncate",
              if(@hidden? || !@unlocked?, do: "text-base-content/60")
            ]}>
              {if @hidden?, do: "???", else: @localized_title}
            </h3>

            <p class={[
              "text-xs mt-1 line-clamp-2",
              cond do
                @hidden? -> "text-base-content/30 italic"
                @unlocked? -> "text-base-content/70"
                true -> "text-base-content/50"
              end
            ]}>
              {if @hidden?,
                do: gettext("Hidden"),
                else: @localized_desc}
            </p>
          </div>
        </div>

        <%!-- Progress section (logged-in users only) --%>
        <%= if @logged_in do %>
          <div class="mt-3">
            <%= cond do %>
              <% @unlocked? -> %>
                <div class="flex items-center gap-1.5 text-success">
                  <.icon name="hero-check-circle-solid" class="w-4 h-4" />
                  <span class="text-xs font-medium">
                    {gettext("Unlocked")}
                    <span class="text-base-content/40 ml-1">
                      {Calendar.strftime(@unlocked_at, "%b %d, %Y")}
                    </span>
                  </span>
                </div>
              <% @hidden? -> %>
                <div class="flex items-center gap-1.5 text-base-content/30">
                  <.icon name="hero-eye-slash" class="w-4 h-4" />
                  <span class="text-xs font-medium italic">
                    {gettext("Hidden")}
                  </span>
                </div>
              <% true -> %>
                <%!-- Progress bar --%>
                <div class="flex items-center justify-between mb-1">
                  <span class="text-xs text-base-content/50">
                    {gettext("Status")}
                  </span>
                  <span class="text-xs font-medium text-base-content/70">
                    {@progress} / {@target}
                  </span>
                </div>
                <div class="w-full bg-base-300 rounded-full h-2 overflow-hidden">
                  <div
                    class={[
                      "h-2 rounded-full transition-all duration-500",
                      if(@pct > 0, do: "bg-primary", else: "bg-base-300")
                    ]}
                    style={"width: #{@pct}%"}
                  >
                  </div>
                </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
