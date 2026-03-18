defmodule GameServerWeb.AchievementsLive do
  @moduledoc """
  Public-facing achievements page.

  Anonymous users see all non-hidden achievements.
  Logged-in users see their progress and unlock status.
  """
  use GameServerWeb, :live_view

  alias GameServer.Achievements

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
      |> assign(:page_title, dgettext("achievements", "Achievements"))
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

    opts = [page: page, page_size: page_size]
    opts = if user, do: Keyword.put(opts, :user_id, user.id), else: opts

    all_items = Achievements.list_achievements(opts)

    # Apply client-side filter for logged-in users
    items =
      case filter do
        "unlocked" -> Enum.filter(all_items, & &1.unlocked_at)
        "locked" -> Enum.reject(all_items, & &1.unlocked_at)
        "in_progress" -> Enum.filter(all_items, &(&1.progress > 0 and is_nil(&1.unlocked_at)))
        _ -> all_items
      end

    total_count = Achievements.count_achievements(if(user, do: [user_id: user.id], else: []))
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
            <h1 class="text-3xl font-bold">{dgettext("achievements", "Achievements")}</h1>
            <p class="text-base-content/60 mt-1">
              <%= if @current_scope && @current_scope.user do %>
                {dgettext("achievements", "%{unlocked} of %{total} unlocked",
                  unlocked: @unlocked_count,
                  total: @total_count
                )}
              <% else %>
                {dgettext("achievements", "%{total} achievements available", total: @total_count)}
              <% end %>
            </p>
          </div>

          <%!-- Filter buttons (only for logged-in users) --%>
          <%= if @current_scope && @current_scope.user do %>
            <div class="flex flex-wrap gap-2">
              <button
                :for={
                  {label, value} <- [
                    {dgettext("achievements", "All"), "all"},
                    {dgettext("achievements", "Unlocked"), "unlocked"},
                    {dgettext("achievements", "Locked"), "locked"},
                    {dgettext("achievements", "In Progress"), "in_progress"}
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
                {dgettext("achievements", "Overall Progress")}
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
              <%= if @filter != "all" do %>
                {dgettext("achievements", "No achievements match this filter.")}
              <% else %>
                {dgettext("achievements", "No achievements yet.")}
              <% end %>
            </p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <.achievement_card
              :for={item <- @achievements}
              item={item}
              logged_in={@current_scope != nil && @current_scope.user != nil}
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
    target = achievement.progress_target || 1
    unlocked? = unlocked_at != nil
    pct = if target > 0, do: min(trunc(progress / target * 100), 100), else: 0

    assigns =
      assigns
      |> assign(:achievement, achievement)
      |> assign(:progress, progress)
      |> assign(:unlocked_at, unlocked_at)
      |> assign(:target, target)
      |> assign(:unlocked?, unlocked?)
      |> assign(:pct, pct)
      |> assign(:logged_in, logged_in)

    ~H"""
    <div class={[
      "card bg-base-200 shadow-sm hover:shadow-md transition-all duration-200 border",
      if(@unlocked?,
        do: "border-success/30 bg-success/5",
        else: "border-base-300"
      )
    ]}>
      <div class="card-body p-4">
        <%!-- Top row: icon + title --%>
        <div class="flex items-start gap-3">
          <%!-- Icon or placeholder --%>
          <div class={[
            "flex-shrink-0 w-12 h-12 rounded-lg flex items-center justify-center text-2xl",
            if(@unlocked?,
              do: "bg-success/20 text-success",
              else: "bg-base-300 text-base-content/30"
            )
          ]}>
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
          </div>

          <div class="flex-1 min-w-0">
            <h3 class={[
              "font-semibold text-sm leading-tight truncate",
              if(!@unlocked?, do: "text-base-content/60")
            ]}>
              {@achievement.title}
            </h3>

            <p class={[
              "text-xs mt-1 line-clamp-2",
              if(@unlocked?, do: "text-base-content/70", else: "text-base-content/50")
            ]}>
              {@achievement.description}
            </p>
          </div>
        </div>

        <%!-- Progress section (logged-in users only) --%>
        <%= if @logged_in do %>
          <div class="mt-3">
            <%= if @unlocked? do %>
              <div class="flex items-center gap-1.5 text-success">
                <.icon name="hero-check-circle-solid" class="w-4 h-4" />
                <span class="text-xs font-medium">
                  {dgettext("achievements", "Unlocked")}
                  <span class="text-base-content/40 ml-1">
                    {Calendar.strftime(@unlocked_at, "%b %d, %Y")}
                  </span>
                </span>
              </div>
            <% else %>
              <%!-- Progress bar --%>
              <div class="flex items-center justify-between mb-1">
                <span class="text-xs text-base-content/50">
                  {dgettext("achievements", "Progress")}
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
