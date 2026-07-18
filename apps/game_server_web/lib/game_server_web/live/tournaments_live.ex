defmodule GameServerWeb.TournamentsLive do
  @moduledoc """
  Public-facing tournaments view, laid out like the leaderboards page.

  Three levels, each paginated so a large field never loads at once:

    * index — one card per tournament *type* (slug), not per occurrence
    * detail — one edition, with Older/Newer navigation across editions of the
      same slug (the equivalent of leaderboard seasons); before the draw it
      lists registrants, after the draw it lists brackets
    * bracket — one bracket drawn as an elimination tree (rounds as columns)
  """
  use GameServerWeb, :live_view

  alias GameServer.Accounts
  alias GameServer.Tournaments
  alias GameServer.Tournaments.Tournament

  @page_size 25
  @brackets_page_size 12

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Tournaments"))
     |> assign(:page, 1)
     |> assign(:page_size, @page_size)
     |> assign(:tournament, nil)
     |> assign(:bracket, nil)}
  end

  @impl true
  def handle_params(%{"id" => id, "index" => index}, _uri, socket) do
    with %Tournament{} = tournament <- fetch(id),
         {index, _} <- Integer.parse(index),
         %{} = bracket <- Tournaments.get_bracket(tournament.id, index) do
      {:noreply, load_bracket(socket, tournament, bracket)}
    else
      _ -> {:noreply, not_found(socket)}
    end
  end

  def handle_params(%{"id" => id} = params, _uri, socket) do
    case fetch(id) do
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

  # Editions are ordered newest-first, so "older" moves down the list.
  def handle_event("older_edition", _params, socket), do: move_edition(socket, +1)
  def handle_event("newer_edition", _params, socket), do: move_edition(socket, -1)

  defp move_edition(socket, delta) do
    case Enum.at(socket.assigns.editions, socket.assigns.edition_index + delta) do
      nil -> {:noreply, socket}
      tournament -> {:noreply, push_patch(socket, to: ~p"/tournaments/#{tournament.id}")}
    end
  end

  # ── Data loading ──────────────────────────────────────────────────────────

  defp fetch(id_or_slug) do
    case Ecto.UUID.cast(id_or_slug) do
      {:ok, _} -> Tournaments.get_tournament(id_or_slug)
      :error -> Tournaments.get_tournament_by_slug(id_or_slug)
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
    drawn? = Tournaments.count_brackets(tournament.id) > 0
    editions = Tournaments.list_occurrences(tournament.slug)

    socket =
      socket
      |> assign(:page_title, tournament.title)
      |> assign(:tournament, tournament)
      |> assign(:bracket, nil)
      |> assign(:page, page)
      |> assign(:drawn?, drawn?)
      |> assign(:entry_count, Tournaments.count_entries(tournament.id))
      |> assign(:bracket_count, Tournaments.count_brackets(tournament.id))
      |> assign(:editions, editions)
      |> assign(:edition_index, Enum.find_index(editions, &(&1.id == tournament.id)) || 0)

    if drawn?,
      do: load_brackets(socket, tournament, page),
      else: load_entries(socket, tournament, page)
  end

  defp load_entries(socket, tournament, page) do
    entries = Tournaments.list_entries(tournament.id, page: page, page_size: @page_size)

    socket
    |> assign(:entries, entries)
    |> assign(:brackets, [])
    |> assign(:names, names_for(Enum.map(entries, & &1.leader_id)))
    |> assign(:total_pages, ceil_div(socket.assigns.entry_count, @page_size))
  end

  defp load_brackets(socket, tournament, page) do
    brackets =
      Tournaments.list_brackets(tournament.id, page: page, page_size: @brackets_page_size)

    indexes = Enum.map(brackets, & &1.index)
    matches = Tournaments.list_matches(tournament.id, bracket_indexes: indexes)

    socket
    |> assign(:brackets, brackets)
    |> assign(:entries, [])
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

  defp load_bracket(socket, tournament, bracket) do
    matches = Tournaments.list_matches(tournament.id, bracket_index: bracket.index)

    entry_ids =
      matches
      |> Enum.flat_map(&[&1.a_entry_id, &1.b_entry_id])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    entries = Tournaments.entries_by_id(tournament.id, entry_ids)

    socket
    |> assign(:page_title, "#{tournament.title} — #{gettext("Bracket")} #{bracket.index + 1}")
    |> assign(:tournament, tournament)
    |> assign(:bracket, bracket)
    |> assign(:rounds, matches |> Enum.group_by(& &1.round) |> Enum.sort_by(&elem(&1, 0)))
    |> assign(:entries, entries)
    |> assign(:names, names_for(Enum.map(Map.values(entries), & &1.leader_id)))
  end

  defp names_for([]), do: %{}

  defp names_for(user_ids) do
    user_ids
    |> Enum.uniq()
    |> Enum.map(&{&1, Accounts.get_user(&1)})
    |> Map.new(fn
      {id, %{display_name: name}} when is_binary(name) and name != "" -> {id, name}
      {id, %{username: username}} when is_binary(username) and username != "" -> {id, username}
      {id, _} -> {id, gettext("Player")}
    end)
  end

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
              names={@names}
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
        navigate={~p"/tournaments/#{group.current_id}"}
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

    <div class="card bg-base-200">
      <div class="card-body">
        <%= if @drawn? do %>
          <h2 class="card-title">{gettext("Brackets")}</h2>

          <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <.link
              :for={b <- @brackets}
              navigate={~p"/tournaments/#{@tournament.id}/brackets/#{b.index}"}
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
        <% else %>
          <h2 class="card-title">{gettext("Registered players")}</h2>

          <div :if={@entries == []} class="text-center py-8 text-base-content/60">
            {gettext("No players registered yet.")}
          </div>

          <ul :if={@entries != []} class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            <li :for={e <- @entries} class="rounded-lg bg-base-100 px-3 py-2 text-sm">
              {@names[e.leader_id]}
            </li>
          </ul>
        <% end %>

        <div :if={@total_pages > 1} class="mt-4 flex justify-center">
          <.pagination
            page={@page}
            total_pages={@total_pages}
            page_size={@page_size}
            on_prev="prev_page"
            on_next="next_page"
          />
        </div>
      </div>
    </div>
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
  attr :names, :map, required: true

  defp bracket_view(assigns) do
    ~H"""
    <div class="flex items-center gap-4 mb-6">
      <.link navigate={~p"/tournaments/#{@tournament.id}"} class="btn btn-outline btn-sm">
        {gettext("Back")}
      </.link>
      <div>
        <h1 class="text-2xl font-bold">
          {@tournament.title} — {gettext("Bracket")} {@bracket.index + 1}
        </h1>
        <div class="text-sm text-base-content/60 mt-1">
          {gettext("Slots")}: {@bracket.size}
        </div>
      </div>
    </div>

    <div class="card bg-base-200">
      <div class="card-body">
        <%!-- Rounds are columns; each match box grows to keep winners centered
              between the two matches that feed it, giving the tree its shape. --%>
        <div class="overflow-x-auto pb-2">
          <div class="flex gap-6 min-w-max items-stretch">
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
                    names={@names}
                  />
                  <div class="h-px bg-base-300"></div>
                  <.slot_row
                    entry_id={m.b_entry_id}
                    winner_id={m.winner_entry_id}
                    resolved={m.resolved_at != nil}
                    round={round}
                    entries={@entries}
                    names={@names}
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
  attr :names, :map, required: true

  defp slot_row(assigns) do
    assigns =
      assign(assigns, :won?, assigns.entry_id != nil and assigns.entry_id == assigns.winner_id)

    ~H"""
    <div class={[
      "flex items-center justify-between gap-2 px-3 py-2 text-sm",
      @won? && "bg-success/10 font-semibold",
      @resolved && not @won? && @entry_id != nil && "opacity-50 line-through"
    ]}>
      <span class="truncate">
        <%= cond do %>
          <% @entry_id -> %>
            {@names[entry_leader(@entries, @entry_id)] || gettext("Player")}
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

  defp entry_leader(entries, entry_id) do
    case Map.get(entries, entry_id) do
      nil -> nil
      entry -> entry.leader_id
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

  defp state_label("scheduled"), do: gettext("Scheduled")
  defp state_label("registration"), do: gettext("Registration open")
  defp state_label("running"), do: gettext("Running")
  defp state_label("finished"), do: gettext("Finished")
  defp state_label("cancelled"), do: gettext("Cancelled")
  defp state_label(other), do: other
end
