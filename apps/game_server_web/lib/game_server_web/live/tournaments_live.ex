defmodule GameServerWeb.TournamentsLive do
  @moduledoc """
  Public-facing tournaments view, laid out like the leaderboards page.

  Three levels, each paginated so a large field never loads at once:

    * index — one card per tournament *type* (slug), not per occurrence
    * detail — one edition, with Older/Newer navigation across editions of the
      same slug (the equivalent of leaderboard seasons); it always lists the
      players, with the brackets above them once the draw has happened
    * bracket — one bracket drawn as an elimination tree (rounds as columns),
      optionally with one player highlighted (`?entry=`, linked from the
      player list)
  """
  use GameServerWeb, :live_view

  alias GameServer.Accounts.User
  alias GameServer.Tournaments
  alias GameServer.Tournaments.Tournament
  alias GameServerWeb.LiveHelpers

  @page_size 25
  @brackets_page_size 12

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Tournaments"))
     |> assign(:page, 1)
     |> assign(:page_size, @page_size)
     |> assign(:brackets_page_size, @brackets_page_size)
     |> assign(:players_page, 1)
     |> assign(:search, "")
     |> assign(:tournament, nil)
     |> assign(:bracket, nil)
     |> assign(:own?, false)
     |> assign(:current_user_id, current_user_id(socket))}
  end

  defp current_user_id(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{id: id}} -> id
      _ -> nil
    end
  end

  @impl true
  def handle_params(%{"slug" => slug, "index" => index} = params, _uri, socket) do
    with %Tournament{} = tournament <- resolve(slug, params["edition"]),
         {index, _} <- Integer.parse(index),
         %{} = bracket <- Tournaments.get_bracket(tournament.id, index) do
      {:noreply, load_bracket(socket, tournament, bracket, params["entry"])}
    else
      _ -> {:noreply, not_found(socket)}
    end
  end

  def handle_params(%{"slug" => slug} = params, _uri, socket) do
    case resolve(slug, params["edition"]) do
      nil -> {:noreply, not_found(socket)}
      tournament -> {:noreply, load_detail(socket, tournament, page_param(params))}
    end
  end

  def handle_params(params, _uri, socket) do
    {:noreply, load_index(socket, page_param(params))}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    {:noreply, load_index(socket, max(socket.assigns.page - 1, 1))}
  end

  def handle_event("next_page", _params, socket) do
    {:noreply, load_index(socket, min(socket.assigns.page + 1, socket.assigns.total_pages))}
  end

  def handle_event("brackets_prev", _params, socket) do
    {:noreply, socket |> assign(:page, max(socket.assigns.page - 1, 1)) |> load_brackets()}
  end

  def handle_event("brackets_next", _params, socket) do
    page = min(socket.assigns.page + 1, socket.assigns.total_pages)
    {:noreply, socket |> assign(:page, page) |> load_brackets()}
  end

  def handle_event("players_prev", _params, socket) do
    page = max(socket.assigns.players_page - 1, 1)
    {:noreply, socket |> assign(:players_page, page) |> load_players()}
  end

  def handle_event("players_next", _params, socket) do
    page = min(socket.assigns.players_page + 1, socket.assigns.players_pages)
    {:noreply, socket |> assign(:players_page, page) |> load_players()}
  end

  def handle_event("search", %{"search" => term}, socket) do
    {:noreply, socket |> assign(:search, term) |> assign(:players_page, 1) |> load_players()}
  end

  # Registration is server-authoritative: the button only offers the action, and
  # `before_tournament_register` may still refuse it (entry fee, rank gate, ...).
  def handle_event("join_tournament", _params, socket) do
    with_current_user(socket, fn user, tournament ->
      case Tournaments.join_tournament(user, tournament) do
        {:ok, _entry} -> {:ok, gettext("Joined")}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def handle_event("leave_tournament", _params, socket) do
    with_current_user(socket, fn user, tournament ->
      case Tournaments.leave_tournament(user, tournament) do
        {:ok, _tournament} -> {:ok, gettext("Left")}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  # Editions are ordered newest-first, so "older" moves down the list.
  def handle_event("older_edition", _params, socket), do: move_edition(socket, +1)
  def handle_event("newer_edition", _params, socket), do: move_edition(socket, -1)

  defp with_current_user(socket, fun) do
    case socket.assigns[:current_scope] do
      %{user: %User{} = user} ->
        socket =
          case fun.(user, socket.assigns.tournament) do
            {:ok, message} ->
              LiveHelpers.put_success(socket, message)

            {:error, reason} ->
              LiveHelpers.put_failure(socket, entry_error_message(reason))
          end

        # Re-read: counts, the player list and the button all move together.
        {:noreply, load_detail(socket, refresh(socket.assigns.tournament), socket.assigns.page)}

      _ ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}
    end
  end

  defp refresh(tournament), do: Tournaments.get_tournament(tournament.id) || tournament

  defp entry_error_message(:registration_closed), do: gettext("Registration is closed.")
  defp entry_error_message(:already_registered), do: gettext("You are already registered.")
  defp entry_error_message(:tournament_full), do: gettext("This tournament is full.")
  defp entry_error_message(:not_registered), do: gettext("You are not registered.")
  defp entry_error_message(:already_drawn), do: gettext("The bracket has already been drawn.")

  # Anything else comes from a game's own hook, so show the reason verbatim.
  defp entry_error_message(reason),
    do: LiveHelpers.failure_message(gettext("Failed"), reason)

  defp move_edition(socket, delta) do
    index = socket.assigns.edition_index + delta
    editions = socket.assigns.editions

    case index >= 0 && Enum.at(editions, index) do
      %Tournament{} = tournament ->
        {:noreply, push_patch(socket, to: base_path(tournament, editions))}

      _ ->
        {:noreply, socket}
    end
  end

  # ── Data loading ──────────────────────────────────────────────────────────

  defp fetch(id_or_slug) do
    case Ecto.UUID.cast(id_or_slug) do
      {:ok, _} -> Tournaments.get_tournament(id_or_slug)
      :error -> Tournaments.get_tournament_by_slug(id_or_slug)
    end
  end

  # No edition in the URL means the live one; that is the canonical landing page.
  defp resolve(slug, nil), do: fetch(slug)

  defp resolve(slug, edition) do
    with {number, _} <- Integer.parse(edition),
         occurrences = Tournaments.list_occurrences(slug),
         true <- number >= 1 and number <= length(occurrences) do
      # Editions are numbered oldest-first, so publishing a new one never
      # renumbers (and never breaks) the links to older editions.
      Enum.at(occurrences, length(occurrences) - number)
    else
      _ -> nil
    end
  end

  defp edition_number(tournament, editions) do
    case Enum.find_index(editions, &(&1.id == tournament.id)) do
      nil -> 1
      index -> length(editions) - index
    end
  end

  # The live edition sits at /tournaments/:slug; every other edition carries its
  # number, so each page has exactly one canonical URL.
  defp base_path(tournament, editions) do
    case Tournaments.get_tournament_by_slug(tournament.slug) do
      %{id: id} when id == tournament.id ->
        ~p"/tournaments/#{tournament.slug}"

      _ ->
        ~p"/tournaments/#{tournament.slug}/#{edition_number(tournament, editions)}"
    end
  end

  defp load_index(socket, page) do
    groups = Tournaments.list_tournament_groups(page: page, page_size: @page_size)
    total = Tournaments.count_tournament_groups()

    socket
    |> assign(:page_title, gettext("Tournaments"))
    |> assign(:tournament, nil)
    |> assign(:bracket, nil)
    |> assign(:page, page)
    |> assign(:groups, groups)
    |> assign(:count, total)
    |> assign(:total_pages, ceil_div(total, @page_size))
  end

  defp load_detail(socket, tournament, page) do
    tournament = Tournaments.advance_lifecycle(tournament)
    bracket_count = Tournaments.count_brackets(tournament.id)
    editions = Tournaments.list_occurrences(tournament.slug)

    socket
    |> assign(:page_title, tournament.title)
    |> assign(:tournament, tournament)
    |> assign(:base_path, base_path(tournament, editions))
    |> assign(:bracket, nil)
    |> assign(:page, page)
    |> assign(:players_page, 1)
    |> assign(:search, "")
    |> assign(:drawn?, bracket_count > 0)
    |> assign(:joined?, joined?(socket, tournament))
    |> assign(:entry_count, Tournaments.count_entries(tournament.id))
    |> assign(:bracket_count, bracket_count)
    |> assign(:editions, editions)
    |> assign(:edition_index, Enum.find_index(editions, &(&1.id == tournament.id)) || 0)
    |> load_brackets()
    |> load_players()
  end

  # The player list stays up after the draw, so a finished tournament still
  # shows who took part and where each of them ended up.
  defp load_players(socket) do
    tournament = socket.assigns.tournament
    search = socket.assigns.search

    entries =
      Tournaments.list_entries(tournament.id,
        page: socket.assigns.players_page,
        page_size: @page_size,
        preload_leader: true,
        order: :bracket,
        search: search
      )

    total = Tournaments.count_entries(tournament.id, search: search)

    socket
    |> assign(:entries, entries)
    |> assign(:players_count, total)
    |> assign(:players_pages, ceil_div(total, @page_size))
  end

  defp load_brackets(%{assigns: %{drawn?: false}} = socket) do
    socket
    |> assign(:brackets, [])
    |> assign(:bracket_progress, %{})
    |> assign(:total_pages, 0)
  end

  defp load_brackets(socket) do
    tournament = socket.assigns.tournament

    brackets =
      Tournaments.list_brackets(tournament.id,
        page: socket.assigns.page,
        page_size: @brackets_page_size
      )

    indexes = Enum.map(brackets, & &1.index)
    matches = Tournaments.list_matches(tournament.id, bracket_indexes: indexes)

    socket
    |> assign(:brackets, brackets)
    |> assign(:bracket_progress, bracket_progress(brackets, matches))
    |> assign(:total_pages, ceil_div(socket.assigns.bracket_count, @brackets_page_size))
  end

  defp bracket_progress(brackets, matches) do
    by_bracket = Enum.group_by(matches, & &1.bracket_index)

    Map.new(brackets, fn b ->
      ms = Map.get(by_bracket, b.index, [])
      {b.index, {Enum.count(ms, &(&1.resolved_at != nil)), length(ms)}}
    end)
  end

  defp load_bracket(socket, tournament, bracket, highlight_entry_id) do
    matches = Tournaments.list_matches(tournament.id, bracket_index: bracket.index)
    editions = Tournaments.list_occurrences(tournament.slug)

    entry_ids =
      matches
      |> Enum.flat_map(&[&1.a_entry_id, &1.b_entry_id])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    entries = Tournaments.entries_by_id(tournament.id, entry_ids)
    own = own_entry(socket, tournament, bracket, entries)
    highlight = Map.get(entries, highlight_entry_id) || own

    socket
    |> assign(:page_title, "#{tournament.title} — #{gettext("Bracket")} #{bracket.index + 1}")
    |> assign(:tournament, tournament)
    |> assign(:base_path, base_path(tournament, editions))
    |> assign(:bracket, bracket)
    |> assign(:rounds, matches |> Enum.group_by(& &1.round) |> Enum.sort_by(&elem(&1, 0)))
    |> assign(:entries, entries)
    |> assign(:highlight, highlight)
    |> assign(:own?, own != nil and highlight != nil and own.id == highlight.id)
  end

  defp joined?(socket, tournament) do
    case current_user_id(socket) do
      nil -> false
      user_id -> Tournaments.get_entry(tournament.id, user_id) != nil
    end
  end

  # Landing on a bracket you are in shows you by default. A shared `?entry=`
  # link names someone specific, so it wins over this.
  defp own_entry(socket, tournament, bracket, entries) do
    with %{user: %{id: user_id}} when is_binary(user_id) <- socket.assigns[:current_scope],
         %{bracket_index: index} = entry when index == bracket.index <-
           Tournaments.get_entry(tournament.id, user_id) do
      Map.get(entries, entry.id)
    else
      _ -> nil
    end
  end

  defp player_name(%{display_name: name}) when is_binary(name) and name != "", do: name
  defp player_name(%{username: name}) when is_binary(name) and name != "", do: name
  defp player_name(_leader), do: gettext("Player")

  defp not_found(socket) do
    socket
    |> put_flash(:error, gettext("Not found"))
    |> push_navigate(to: ~p"/tournaments")
  end

  defp page_param(params), do: max(parse_int(params["page"], 1), 1)

  defp parse_int(nil, default), do: default

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp ceil_div(_num, 0), do: 0
  defp ceil_div(num, den), do: div(num + den - 1, den)

  # ── Render ────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="space-y-6">
        <div>
          <h1 class="text-3xl font-bold">
            {gettext("Tournaments")}
            <span :if={is_nil(@tournament)} class="text-base-content/50 font-normal">
              ({@count})
            </span>
          </h1>
        </div>

        <%= cond do %>
          <% @bracket -> %>
            <.bracket_view
              tournament={@tournament}
              bracket={@bracket}
              rounds={@rounds}
              entries={@entries}
              base_path={@base_path}
              highlight={@highlight}
              own?={@own?}
            />
          <% @tournament -> %>
            <.detail_view {assigns} />
          <% true -> %>
            <.group_list
              groups={@groups}
              page={@page}
              page_size={@page_size}
              total_pages={@total_pages}
              count={@count}
            />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ── Index: one card per tournament type ───────────────────────────────────

  attr :groups, :list, required: true
  attr :page, :integer, required: true
  attr :page_size, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :count, :integer, required: true

  defp group_list(assigns) do
    ~H"""
    <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      <.link
        :for={group <- @groups}
        navigate={~p"/tournaments/#{group.slug}"}
        class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
      >
        <div class="card-body">
          <div class="flex items-start justify-between">
            <h3 class="card-title text-lg">{group.title}</h3>
            <div class="flex flex-col items-end gap-1">
              <.state_badge state={group.state} />
              <span :if={group.edition_count > 1} class="badge badge-ghost badge-sm text-nowrap">
                {group.edition_count}
              </span>
            </div>
          </div>

          <p
            :if={group.description not in [nil, ""]}
            class="text-sm text-base-content/70 line-clamp-2"
          >
            {group.description}
          </p>

          <div class="text-sm text-base-content/60">
            {gettext("Players")}: {group.entry_count}
          </div>
        </div>
      </.link>
    </div>

    <div :if={@groups == []} class="text-center py-12 text-base-content/60">
      <p>{gettext("No tournaments yet.")}</p>
    </div>

    <div class="mt-6 flex justify-center">
      <.pagination
        page={@page}
        total_pages={@total_pages}
        page_size={@page_size}
        total_count={@count}
        on_prev="prev_page"
        on_next="next_page"
      />
    </div>
    """
  end

  # ── Detail: one edition ───────────────────────────────────────────────────

  defp detail_view(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 mb-6">
      <div class="flex items-center gap-4">
        <.link navigate={~p"/tournaments"} class="btn btn-outline btn-sm">
          {gettext("Back")}
        </.link>
        <div>
          <h1 class="text-2xl font-bold">{@tournament.title}</h1>
          <div class="flex items-center gap-2 mt-1">
            <.state_badge state={@tournament.state} />
            <span :if={@tournament.starts_at} class="text-sm text-base-content/60">
              {Calendar.strftime(@tournament.starts_at, "%b %d, %Y")}
            </span>
            <span :if={is_nil(@tournament.starts_at)} class="text-sm text-base-content/60">
              {gettext("Starts manually")}
            </span>
          </div>
        </div>

        <div class="ml-auto">
          <.join_action
            tournament={@tournament}
            joined?={@joined?}
            signed_in?={not is_nil(@current_user_id)}
          />
        </div>
      </div>

      <%!-- Edition navigation, mirroring leaderboard seasons --%>
      <div
        :if={length(@editions) > 1}
        class="flex items-center gap-3 bg-base-200 rounded-lg px-4 py-2 w-fit"
      >
        <button
          phx-click="older_edition"
          class="btn btn-sm btn-ghost"
          disabled={@edition_index >= length(@editions) - 1}
        >
          {gettext("Older")}
        </button>
        <div class="text-sm">
          <span class="font-medium">{"##{length(@editions) - @edition_index}"}</span>
          <span class="text-base-content/60">{"/ #{length(@editions)}"}</span>
        </div>
        <button
          phx-click="newer_edition"
          class="btn btn-sm btn-ghost"
          disabled={@edition_index <= 0}
        >
          {gettext("Newer")}
        </button>
      </div>
    </div>

    <p :if={@tournament.description not in [nil, ""]} class="text-base-content/70 mb-6">
      {@tournament.description}
    </p>

    <div class="grid gap-4 sm:grid-cols-3 mb-6">
      <.stat label={gettext("Players")} value={@entry_count} />
      <.stat label={gettext("Bracket size")} value={@tournament.bracket_size} />
      <.stat label={gettext("Brackets")} value={@bracket_count} />
    </div>

    <div :if={@drawn?} class="card bg-base-200 mb-6">
      <div class="card-body">
        <h2 class="card-title">{gettext("Brackets")}</h2>

        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <.link
            :for={b <- @brackets}
            navigate={"#{@base_path}/brackets/#{b.index}"}
            class="card bg-base-100 hover:bg-base-300 transition-colors"
          >
            <div class="card-body p-4 gap-1">
              <div class="font-semibold">{gettext("Bracket")} {b.index + 1}</div>
              <div class="text-xs text-base-content/60">
                {gettext("Slots")}: {b.size} · {elem(@bracket_progress[b.index] || {0, 0}, 0)}/{elem(
                  @bracket_progress[b.index] || {0, 0},
                  1
                )} {gettext("matches decided")}
              </div>
            </div>
          </.link>
        </div>

        <div :if={@total_pages > 1} class="mt-4 flex justify-center">
          <.pagination
            page={@page}
            total_pages={@total_pages}
            page_size={@brackets_page_size}
            total_count={@bracket_count}
            on_prev="brackets_prev"
            on_next="brackets_next"
          />
        </div>
      </div>
    </div>

    <div class="card bg-base-200">
      <div class="card-body">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <h2 class="card-title">
            {gettext("Players")}
            <span class="text-base-content/50 font-normal text-base">({@players_count})</span>
          </h2>

          <form phx-change="search" phx-submit="search" id="players-search-form" class="sm:w-64">
            <.input
              name="search"
              value={@search}
              placeholder={gettext("Search players...")}
              phx-debounce="300"
              type="text"
            />
          </form>
        </div>

        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>{gettext("Name")}</th>
                <th :if={@drawn?}>{gettext("Bracket")}</th>
                <th :if={@drawn?} class="text-right">{gettext("Wins")}</th>
                <th class="text-right">{gettext("Result")}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={e <- @entries}
                id={"entry-#{e.id}"}
                class={[e.leader_id == @current_user_id && "bg-primary/10"]}
              >
                <td>
                  <div class="flex items-center gap-2">
                    <div class="w-8 h-8 rounded-full bg-base-300 flex items-center justify-center text-sm font-semibold">
                      {String.upcase(String.first(player_name(e.leader)) || "?")}
                    </div>
                    <span class={[e.leader_id == @current_user_id && "font-bold"]}>
                      {player_name(e.leader)}
                    </span>
                    <span :if={e.leader_id == @current_user_id} class="badge badge-primary badge-sm">
                      {gettext("You")}
                    </span>
                  </div>
                </td>
                <td :if={@drawn?}>
                  <%= if e.bracket_index do %>
                    <.link
                      navigate={"#{@base_path}/brackets/#{e.bracket_index}?entry=#{e.id}"}
                      class="link link-primary whitespace-nowrap"
                    >
                      {gettext("Bracket")} {e.bracket_index + 1}
                    </.link>
                  <% else %>
                    <span class="text-base-content/40">—</span>
                  <% end %>
                </td>
                <td :if={@drawn?} class="text-right font-mono">{e.wins}</td>
                <td class="text-right">
                  <span class={["badge badge-sm", entry_state_class(e.state)]}>
                    {entry_state_label(e.state)}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div :if={@entries == []} class="text-center py-8 text-base-content/60">
          <p :if={@search == ""}>{gettext("No players registered yet.")}</p>
          <p :if={@search != ""}>{gettext("No results.")}</p>
        </div>

        <div :if={@players_pages > 1} class="mt-4 flex justify-center">
          <.pagination
            page={@players_page}
            total_pages={@players_pages}
            page_size={@page_size}
            total_count={@players_count}
            on_prev="players_prev"
            on_next="players_next"
          />
        </div>
      </div>
    </div>
    """
  end

  attr :tournament, :map, required: true
  attr :joined?, :boolean, required: true
  attr :signed_in?, :boolean, required: true

  defp join_action(assigns) do
    ~H"""
    <%= cond do %>
      <% not @signed_in? and @tournament.state == "registration" -> %>
        <.link navigate={~p"/users/log-in"} class="btn btn-outline btn-sm">
          {gettext("Log in")}
        </.link>
      <% not @signed_in? -> %>
        <%!-- Withdrawing is only possible until the bracket is drawn. --%>
      <% @joined? and @tournament.state in ["scheduled", "registration"] -> %>
        <button phx-click="leave_tournament" class="btn btn-outline btn-error btn-sm" id="leave-btn">
          {gettext("Leave")}
        </button>
      <% @joined? -> %>
        <span class="badge badge-primary">{gettext("You")}</span>
      <% @tournament.state == "registration" -> %>
        <button phx-click="join_tournament" class="btn btn-primary btn-sm" id="join-btn">
          {gettext("Join")}
        </button>
      <% true -> %>
    <% end %>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp stat(assigns) do
    ~H"""
    <div class="card bg-base-200">
      <div class="card-body py-4">
        <span class="text-sm text-base-content/70">{@label}</span>
        <div class="text-2xl font-bold">{@value}</div>
      </div>
    </div>
    """
  end

  # ── Bracket tree ──────────────────────────────────────────────────────────

  attr :tournament, :map, required: true
  attr :bracket, :map, required: true
  attr :rounds, :list, required: true
  attr :entries, :map, required: true
  attr :base_path, :string, required: true
  attr :highlight, :map, default: nil
  attr :own?, :boolean, default: false

  defp bracket_view(assigns) do
    ~H"""
    <div class="flex items-center gap-4 mb-6">
      <.link navigate={@base_path} class="btn btn-outline btn-sm">
        {gettext("Back")}
      </.link>
      <div>
        <h1 class="text-2xl font-bold">
          {@tournament.title} — {gettext("Bracket")} {@bracket.index + 1}
        </h1>
        <div class="flex items-center gap-2 mt-1">
          <.state_badge state={@tournament.state} />
          <span class="text-sm text-base-content/60">
            {gettext("Slots")}: {@bracket.size}
          </span>
          <span :if={@tournament.starts_at} class="text-sm text-base-content/60">
            {Calendar.strftime(@tournament.starts_at, "%b %d, %Y")}
          </span>
          <span :if={is_nil(@tournament.starts_at)} class="text-sm text-base-content/60">
            {gettext("Starts manually")}
          </span>
        </div>
      </div>
    </div>

    <div
      :if={@highlight}
      class="card bg-primary/10 border border-primary/30 mb-6"
    >
      <div class="card-body py-4 flex-row items-center justify-between gap-4">
        <div>
          <span class="text-sm text-base-content/70">{gettext("Showing")}</span>
          <div class="text-xl font-bold flex items-center gap-2">
            {player_name(@highlight.leader)}
            <span :if={@own?} class="badge badge-primary badge-sm">{gettext("You")}</span>
          </div>
        </div>
        <div class="flex items-center gap-4 text-right">
          <div>
            <span class="text-sm text-base-content/70">{gettext("Wins")}</span>
            <div class="text-xl font-bold font-mono">{@highlight.wins}</div>
          </div>
          <span class={["badge", entry_state_class(@highlight.state)]}>
            {entry_state_label(@highlight.state)}
          </span>
        </div>
      </div>
    </div>

    <div class="card bg-base-200">
      <div class="card-body">
        <%!-- Rounds are columns; each match box grows to keep winners centered
              between the two matches that feed it, giving the tree its shape. --%>
        <%!-- w-fit + mx-auto centres a narrow tree; a wide one still scrolls. --%>
        <div class="overflow-x-auto pb-2">
          <div class="flex gap-6 min-w-max w-fit mx-auto items-stretch">
            <div :for={{round, matches} <- @rounds} class="flex flex-col gap-3 min-w-56">
              <div class="text-xs font-semibold uppercase tracking-wider text-base-content/50 text-center">
                {round_label(round, length(@rounds))}
              </div>
              <div class="flex flex-col justify-around flex-1 gap-3">
                <div
                  :for={m <- Enum.sort_by(matches, & &1.slot)}
                  class="rounded-lg border border-base-300 bg-base-100 overflow-hidden"
                >
                  <.slot_row
                    entry_id={m.a_entry_id}
                    winner_id={m.winner_entry_id}
                    resolved={m.resolved_at != nil}
                    round={round}
                    entries={@entries}
                    highlight_id={@highlight && @highlight.id}
                  />
                  <div class="h-px bg-base-300"></div>
                  <.slot_row
                    entry_id={m.b_entry_id}
                    winner_id={m.winner_entry_id}
                    resolved={m.resolved_at != nil}
                    round={round}
                    entries={@entries}
                    highlight_id={@highlight && @highlight.id}
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :entry_id, :string, default: nil
  attr :winner_id, :string, default: nil
  attr :resolved, :boolean, default: false
  attr :round, :integer, required: true
  attr :entries, :map, required: true
  attr :highlight_id, :string, default: nil

  defp slot_row(assigns) do
    assigns =
      assigns
      |> assign(:won?, assigns.entry_id != nil and assigns.entry_id == assigns.winner_id)
      |> assign(
        :highlighted?,
        assigns.entry_id != nil and assigns.entry_id == assigns.highlight_id
      )

    ~H"""
    <div class={[
      "flex items-center justify-between gap-2 px-3 py-2 text-sm",
      @won? && "bg-success/10 font-semibold",
      @resolved && not @won? && @entry_id != nil && "opacity-50 line-through",
      @highlighted? && "bg-primary/20 ring-2 ring-primary ring-inset font-semibold"
    ]}>
      <span class="truncate">
        <%= cond do %>
          <% @entry_id -> %>
            {slot_name(@entries, @entry_id)}
          <% @round == 1 -> %>
            <span class="text-base-content/40">{gettext("bye")}</span>
          <% true -> %>
            <span class="text-base-content/40">—</span>
        <% end %>
      </span>
      <span :if={@won?} class="text-success text-xs">✓</span>
    </div>
    """
  end

  defp slot_name(entries, entry_id) do
    case Map.get(entries, entry_id) do
      nil -> gettext("Player")
      entry -> player_name(entry.leader)
    end
  end

  defp round_label(round, total) do
    case total - round do
      0 -> gettext("Final")
      1 -> gettext("Semifinal")
      2 -> gettext("Quarterfinal")
      _ -> gettext("Round %{n}", n: round)
    end
  end

  # ── Shared bits ───────────────────────────────────────────────────────────

  attr :state, :string, required: true

  defp state_badge(assigns) do
    ~H"""
    <span class={["badge", state_class(@state)]}>{state_label(@state)}</span>
    """
  end

  defp state_class("running"), do: "badge-success"
  defp state_class("registration"), do: "badge-info"
  defp state_class("finished"), do: "badge-neutral"
  defp state_class("cancelled"), do: "badge-error"
  defp state_class(_state), do: "badge-ghost"

  defp entry_state_class("winner"), do: "badge-success"
  defp entry_state_class("active"), do: "badge-info"
  defp entry_state_class("eliminated"), do: "badge-ghost opacity-60"
  defp entry_state_class(_state), do: "badge-ghost"

  defp entry_state_label("winner"), do: gettext("Champion")
  defp entry_state_label("active"), do: gettext("Playing")
  defp entry_state_label("eliminated"), do: gettext("Eliminated")
  defp entry_state_label("registered"), do: gettext("Registered")
  defp entry_state_label(other), do: other

  defp state_label("scheduled"), do: gettext("Scheduled")
  defp state_label("registration"), do: gettext("Registration open")
  defp state_label("running"), do: gettext("Running")
  defp state_label("finished"), do: gettext("Finished")
  defp state_label("cancelled"), do: gettext("Cancelled")
  defp state_label(other), do: other
end
