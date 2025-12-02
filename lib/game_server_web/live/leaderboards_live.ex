defmodule GameServerWeb.LeaderboardsLive do
  @moduledoc """
  Public-facing leaderboards view.

  Users can browse active and historical leaderboards and see their rank.
  """
  use GameServerWeb, :live_view

  alias GameServer.Leaderboards
  alias GameServer.Leaderboards.Leaderboard

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page, 1)
      |> assign(:page_size, 25)
      |> assign(:selected_leaderboard, nil)
      |> assign(:records_page, 1)
      |> assign(:user_record, nil)
      |> reload_leaderboards()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Leaderboards.get_leaderboard(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Leaderboard not found")
         |> push_navigate(to: ~p"/leaderboards")}

      leaderboard ->
        user_record = get_user_record(socket, leaderboard.id)

        {:noreply,
         socket
         |> assign(:selected_leaderboard, leaderboard)
         |> assign(:user_record, user_record)
         |> assign(:records_page, 1)
         |> reload_records()}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:selected_leaderboard, nil)
     |> assign(:user_record, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <%= if @selected_leaderboard do %>
          <.render_leaderboard_detail
            leaderboard={@selected_leaderboard}
            records={@records}
            records_page={@records_page}
            records_total_pages={@records_total_pages}
            records_count={@records_count}
            user_record={@user_record}
            current_user_id={@current_scope && @current_scope.user && @current_scope.user.id}
          />
        <% else %>
          <.render_leaderboard_list
            leaderboards={@leaderboards}
            page={@page}
            total_pages={@total_pages}
            count={@count}
          />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Render Components
  # ---------------------------------------------------------------------------

  defp render_leaderboard_list(assigns) do
    ~H"""
    <.header>
      Leaderboards
      <:subtitle>Compete and climb the ranks!</:subtitle>
    </.header>

    <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      <.link
        :for={lb <- @leaderboards}
        navigate={~p"/leaderboards/#{lb.id}"}
        class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
      >
        <div class="card-body">
          <div class="flex items-start justify-between">
            <h3 class="card-title text-lg">{lb.title}</h3>
            <%= if Leaderboard.active?(lb) do %>
              <span class="badge badge-success">Active</span>
            <% else %>
              <span class="badge badge-neutral">Ended</span>
            <% end %>
          </div>

          <%= if lb.description do %>
            <p class="text-sm text-base-content/70">{lb.description}</p>
          <% end %>

          <div class="mt-2 flex gap-2 text-xs text-base-content/60">
            <span class="badge badge-ghost badge-sm">{lb.sort_order}</span>
            <span class="badge badge-ghost badge-sm">{lb.operator}</span>
          </div>

          <div class="mt-2 text-xs text-base-content/60">
            <%= cond do %>
              <% lb.ends_at && Leaderboard.ended?(lb) -> %>
                Ended {Calendar.strftime(lb.ends_at, "%b %d, %Y")}
              <% lb.ends_at -> %>
                Ends {Calendar.strftime(lb.ends_at, "%b %d, %Y")}
              <% true -> %>
                Permanent
            <% end %>
          </div>
        </div>
      </.link>
    </div>

    <%= if @leaderboards == [] do %>
      <div class="text-center py-12 text-base-content/60">
        <p>No leaderboards available yet.</p>
      </div>
    <% end %>

    <div class="mt-6 flex gap-2 items-center justify-center">
      <button phx-click="prev_page" class="btn btn-sm" disabled={@page <= 1}>
        ← Previous
      </button>
      <div class="text-sm text-base-content/70">
        Page {@page} of {@total_pages}
      </div>
      <button phx-click="next_page" class="btn btn-sm" disabled={@page >= @total_pages}>
        Next →
      </button>
    </div>
    """
  end

  defp render_leaderboard_detail(assigns) do
    ~H"""
    <div class="flex items-center gap-4 mb-6">
      <.link navigate={~p"/leaderboards"} class="btn btn-outline btn-sm">
        ← Back
      </.link>
      <div>
        <h1 class="text-2xl font-bold">{@leaderboard.title}</h1>
        <div class="flex items-center gap-2 mt-1">
          <%= if Leaderboard.active?(@leaderboard) do %>
            <span class="badge badge-success">Active</span>
          <% else %>
            <span class="badge badge-neutral">Ended</span>
          <% end %>
          <span class="text-sm text-base-content/60">
            <%= cond do %>
              <% @leaderboard.ends_at && Leaderboard.ended?(@leaderboard) -> %>
                Ended {Calendar.strftime(@leaderboard.ends_at, "%b %d, %Y")}
              <% @leaderboard.ends_at -> %>
                Ends {Calendar.strftime(@leaderboard.ends_at, "%b %d, %Y")}
              <% true -> %>
                Permanent
            <% end %>
          </span>
        </div>
      </div>
    </div>

    <%= if @leaderboard.description do %>
      <p class="text-base-content/70 mb-6">{@leaderboard.description}</p>
    <% end %>

    <%= if @user_record do %>
      <div class="card bg-primary/10 border border-primary/30 mb-6">
        <div class="card-body py-4">
          <div class="flex items-center justify-between">
            <div>
              <span class="text-sm text-base-content/70">Your Rank</span>
              <div class="text-2xl font-bold">#{@user_record.rank}</div>
            </div>
            <div class="text-right">
              <span class="text-sm text-base-content/70">Your Score</span>
              <div class="text-2xl font-bold">{format_score(@user_record.score)}</div>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <div class="card bg-base-200">
      <div class="card-body">
        <h2 class="card-title">Rankings</h2>

        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th class="w-16">Rank</th>
                <th>Player</th>
                <th class="text-right">Score</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={record <- @records}
                class={[
                  record.user_id == @current_user_id && "bg-primary/10"
                ]}
              >
                <td class="font-mono">
                  <span class={[
                    "inline-flex items-center justify-center w-8 h-8 rounded-full",
                    record.rank == 1 && "bg-yellow-500/20 text-yellow-600",
                    record.rank == 2 && "bg-gray-400/20 text-gray-600",
                    record.rank == 3 && "bg-orange-500/20 text-orange-600"
                  ]}>
                    {record.rank}
                  </span>
                </td>
                <td>
                  <div class="flex items-center gap-2">
                    <span class={[
                      record.user_id == @current_user_id && "font-bold"
                    ]}>
                      {(record.user && record.user.display_name) || "User #{record.user_id}"}
                    </span>
                    <%= if record.user_id == @current_user_id do %>
                      <span class="badge badge-primary badge-sm">You</span>
                    <% end %>
                  </div>
                </td>
                <td class="text-right font-mono">
                  {format_score(record.score)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%= if @records == [] do %>
          <div class="text-center py-8 text-base-content/60">
            <p>No scores yet. Be the first!</p>
          </div>
        <% end %>

        <div class="mt-4 flex gap-2 items-center justify-center">
          <button phx-click="records_prev" class="btn btn-sm" disabled={@records_page <= 1}>
            ← Previous
          </button>
          <div class="text-sm text-base-content/70">
            Page {@records_page} of {@records_total_pages} ({@records_count} total)
          </div>
          <button
            phx-click="records_next"
            class="btn btn-sm"
            disabled={@records_page >= @records_total_pages}
          >
            Next →
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Event Handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("prev_page", _, socket) do
    {:noreply,
     socket
     |> assign(:page, max(1, socket.assigns.page - 1))
     |> reload_leaderboards()}
  end

  def handle_event("next_page", _, socket) do
    {:noreply,
     socket
     |> assign(:page, socket.assigns.page + 1)
     |> reload_leaderboards()}
  end

  def handle_event("records_prev", _, socket) do
    {:noreply,
     socket
     |> assign(:records_page, max(1, socket.assigns.records_page - 1))
     |> reload_records()}
  end

  def handle_event("records_next", _, socket) do
    {:noreply,
     socket
     |> assign(:records_page, socket.assigns.records_page + 1)
     |> reload_records()}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp reload_leaderboards(socket) do
    page = socket.assigns[:page] || 1
    page_size = socket.assigns[:page_size] || 25

    leaderboards = Leaderboards.list_leaderboards(page: page, page_size: page_size)
    count = Leaderboards.count_leaderboards()
    total_pages = max(1, div(count + page_size - 1, page_size))

    socket
    |> assign(:leaderboards, leaderboards)
    |> assign(:count, count)
    |> assign(:total_pages, total_pages)
  end

  defp reload_records(socket) do
    lb = socket.assigns.selected_leaderboard
    page = socket.assigns[:records_page] || 1
    page_size = 25

    records = Leaderboards.list_records(lb.id, page: page, page_size: page_size)
    count = Leaderboards.count_records(lb.id)
    total_pages = max(1, div(count + page_size - 1, page_size))

    socket
    |> assign(:records, records)
    |> assign(:records_count, count)
    |> assign(:records_total_pages, total_pages)
  end

  defp get_user_record(socket, leaderboard_id) do
    case socket.assigns[:current_scope] do
      %{user: %{id: user_id}} when is_integer(user_id) ->
        case Leaderboards.get_user_record(leaderboard_id, user_id) do
          {:ok, record} -> record
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp format_score(score) when is_integer(score) do
    score
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0,")
    |> String.reverse()
  end

  defp format_score(score), do: to_string(score)
end
