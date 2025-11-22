defmodule GameServerWeb.AdminLive.Index do
  use GameServerWeb, :live_view

  alias GameServer.Repo
  alias GameServer.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <.header>
          Admin Dashboard
          <:subtitle>System configuration and user management</:subtitle>
        </.header>

        <%!-- Configuration Section --%>
        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Configuration</h2>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>Key</th>
                    <th>Value</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td class="font-semibold">Discord Client ID</td>
                    <td class="font-mono text-sm">
                      <%= if @config.discord_client_id do %>
                        <%= mask_secret(@config.discord_client_id) %>
                      <% else %>
                        <span class="text-error">Not configured</span>
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Discord Client Secret</td>
                    <td class="font-mono text-sm">
                      <%= if @config.discord_client_secret do %>
                        <%= mask_secret(@config.discord_client_secret) %>
                      <% else %>
                        <span class="text-error">Not configured</span>
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Environment</td>
                    <td class="font-mono text-sm"><%= @config.env %></td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Database</td>
                    <td class="font-mono text-sm"><%= @config.database %></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <%!-- Users Section --%>
        <div class="card bg-base-200">
          <div class="card-body">
            <div class="flex justify-between items-center mb-4">
              <h2 class="card-title">Users (<%= @users_count %>)</h2>
              <.link navigate={~p"/admin/users"} class="btn btn-primary btn-sm">
                Manage Users
              </.link>
            </div>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Email</th>
                    <th>Discord</th>
                    <th>Confirmed</th>
                    <th>Created</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={user <- @recent_users} id={"user-#{user.id}"}>
                    <td><%= user.id %></td>
                    <td class="font-mono text-sm"><%= user.email %></td>
                    <td>
                      <%= if user.discord_id do %>
                        <span class="badge badge-success badge-sm">Connected</span>
                      <% else %>
                        <span class="badge badge-ghost badge-sm">Not connected</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if user.confirmed_at do %>
                        <span class="badge badge-success badge-sm">Yes</span>
                      <% else %>
                        <span class="badge badge-warning badge-sm">No</span>
                      <% end %>
                    </td>
                    <td class="text-sm">
                      <%= Calendar.strftime(user.inserted_at, "%Y-%m-%d %H:%M") %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    import Ecto.Query

    config = %{
      discord_client_id: Application.get_env(:ueberauth, Ueberauth.Strategy.Discord.OAuth)[:client_id],
      discord_client_secret: Application.get_env(:ueberauth, Ueberauth.Strategy.Discord.OAuth)[:client_secret],
      env: to_string(Application.get_env(:game_server, :environment, Mix.env())),
      database: Application.get_env(:game_server, GameServer.Repo)[:database] || "N/A"
    }

    users_count = Repo.aggregate(User, :count)
    recent_users = Repo.all(from u in User, order_by: [desc: u.inserted_at], limit: 10)

    {:ok,
     socket
     |> assign(:config, config)
     |> assign(:users_count, users_count)
     |> assign(:recent_users, recent_users)}
  end

  defp mask_secret(nil), do: "Not set"
  defp mask_secret(""), do: "Not set"
  defp mask_secret(secret) when is_binary(secret) do
    visible = String.slice(secret, 0..7)
    visible <> "..." <> String.slice(secret, -4..-1//1)
  end
end
