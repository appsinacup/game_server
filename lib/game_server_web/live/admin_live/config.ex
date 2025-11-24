defmodule GameServerWeb.AdminLive.Config do
  use GameServerWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto space-y-8">
        <.link navigate={~p"/admin"} class="btn btn-outline mb-4">
          ← Back to Admin
        </.link>

        <.header>
          Configuration
          <:subtitle>System configuration settings and setup guides</:subtitle>
        </.header>
        
    <!-- Current Configuration Status -->
        <div class="card bg-base-100 shadow-xl collapsed" data-card-key="config_status">
          <div class="card-body">
            <h2 class="card-title text-xl mb-4 flex items-center gap-3">
              Current Configuration Status
              <button
                type="button"
                data-action="toggle-card"
                data-card-key="config_status"
                aria-expanded="false"
                class="btn btn-ghost btn-sm ml-auto"
                title="Collapse/Expand"
              >
                <svg class="w-4 h-4" viewBox="0 0 20 20" fill="none" stroke="currentColor">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 8l4 4 4-4"
                  />
                </svg>
              </button>
            </h2>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>Service</th>
                    <th>Status</th>
                    <th>Details</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td class="font-semibold">Discord OAuth</td>
                    <td>
                      <%= if @config.discord_client_id && @config.discord_client_secret do %>
                        <span class="badge badge-success">Configured</span>
                      <% else %>
                        <span class="badge badge-error">Not Configured</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if @config.discord_client_id do %>
                        Client ID: {@config.discord_client_id}<br />
                        Client Secret: {@config.discord_client_secret || "Not set"}
                      <% else %>
                        <span class="text-error">Client ID missing</span>
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Apple Sign In</td>
                    <td>
                      <%= if @config.apple_client_id && @config.apple_team_id && @config.apple_key_id && @config.apple_private_key do %>
                        <span class="badge badge-success">Configured</span>
                      <% else %>
                        <span class="badge badge-error">Not Configured</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if @config.apple_client_id do %>
                        Client ID: {@config.apple_client_id}<br />
                        Team ID: {@config.apple_team_id || "Not set"}<br />
                        Key ID: {@config.apple_key_id || "Not set"}<br />
                        Private Key: {@config.apple_private_key || "Not set"}
                      <% else %>
                        <span class="text-error">Not configured</span>
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Google OAuth</td>
                    <td>
                      <%= if @config.google_client_id && @config.google_client_secret do %>
                        <span class="badge badge-success">Configured</span>
                      <% else %>
                        <span class="badge badge-error">Not Configured</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if @config.google_client_id do %>
                        Client ID: {@config.google_client_id}<br />
                        Client Secret: {@config.google_client_secret || "Not set"}
                      <% else %>
                        <span class="text-error">Client ID missing</span>
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Facebook OAuth</td>
                    <td>
                      <%= if @config.facebook_client_id && @config.facebook_client_secret do %>
                        <span class="badge badge-success">Configured</span>
                      <% else %>
                        <span class="badge badge-error">Not Configured</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if @config.facebook_client_id do %>
                        Client ID: {@config.facebook_client_id}<br />
                        Client Secret: {@config.facebook_client_secret || "Not set"}
                      <% else %>
                        <span class="text-error">Client ID missing</span>
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Email Service</td>
                    <td>
                      <%= if @config.email_configured do %>
                        <span class="badge badge-success">SMTP</span>
                      <% else %>
                        <span class="badge badge-info">Local</span>
                      <% end %>
                    </td>
                    <td class="text-sm">
                      <div class="font-mono text-xs mt-1">
                        Username: {@config.smtp_username || "Not set"}<br />
                        Password: {@config.smtp_password || "Not set"}<br />
                        Relay: {@config.smtp_relay || "Not set"}
                      </div>
                      <%= if @config.email_configured do %>
                        SMTP configured - emails are sent via {@config.smtp_relay ||
                          "configured relay"}
                      <% else %>
                        <%= if @config.env == "dev" do %>
                          Using local delivery - emails are not sent (<a
                            href="/admin/mailbox"
                            class="link link-primary"
                          >view mailbox</a>)
                        <% else %>
                          Using local delivery - emails are not sent
                        <% end %>
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Environment</td>
                    <td><span class="badge badge-info">{@config.env}</span></td>
                    <td class="font-mono text-sm">{@config.env}</td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Database</td>
                    <td><span class="badge badge-info">SQLite</span></td>
                    <td class="font-mono text-sm">{@config.database}</td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Hostname</td>
                    <td><span class="badge badge-info">System</span></td>
                    <td class="font-mono text-sm">{@config.hostname || "Not set"}</td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Port</td>
                    <td><span class="badge badge-info">Server</span></td>
                    <td class="font-mono text-sm">{@config.port || "4000"}</td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Secret Key Base</td>
                    <td>
                      <%= if @config.secret_key_base do %>
                        <span class="badge badge-success">Set</span>
                      <% else %>
                        <span class="badge badge-error">Not Set</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if @config.secret_key_base do %>
                        {String.slice(@config.secret_key_base, 0..15)}...
                      <% else %>
                        Not configured
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Sentry Error Monitoring</td>
                    <td>
                      <%= if @config.sentry_dsn do %>
                        <span class="badge badge-success">Configured</span>
                      <% else %>
                        <span class="badge badge-error">Not Configured</span>
                      <% end %>
                    </td>
                    <td class="text-sm">
                      <%= if @config.sentry_dsn do %>
                        Error monitoring enabled - production errors will be tracked
                      <% else %>
                        <span class="text-error">SENTRY_DSN not set - errors won't be monitored</span>
                      <% end %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
        
    <!-- Admin Tools -->
        <div class="card bg-base-100 shadow-xl collapsed" data-card-key="admin_tools">
          <div class="card-body">
            <h2 class="card-title text-xl mb-4 flex items-center gap-3">
              Admin Tools
              <button
                type="button"
                data-action="toggle-card"
                data-card-key="admin_tools"
                aria-expanded="false"
                class="btn btn-ghost btn-sm ml-auto"
                title="Collapse/Expand"
              >
                <svg class="w-4 h-4" viewBox="0 0 20 20" fill="none" stroke="currentColor">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 8l4 4 4-4"
                  />
                </svg>
              </button>
            </h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <a href="/admin/dashboard" class="btn btn-outline btn-primary">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                  />
                </svg>
                Live Dashboard
              </a>
              <%= if @config.env == "dev" do %>
                <a href="/admin/mailbox" class="btn btn-outline btn-secondary">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                    />
                  </svg>
                  Mailbox Preview
                </a>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    config = %{
      discord_client_id:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Discord.OAuth)[:client_id] ||
          System.get_env("DISCORD_CLIENT_ID"),
      discord_client_secret:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Discord.OAuth)[:client_secret] ||
          System.get_env("DISCORD_CLIENT_SECRET"),
      apple_client_id: System.get_env("APPLE_CLIENT_ID"),
      apple_team_id: System.get_env("APPLE_TEAM_ID"),
      apple_key_id: System.get_env("APPLE_KEY_ID"),
      apple_private_key: System.get_env("APPLE_PRIVATE_KEY"),
      google_client_id:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id] ||
          System.get_env("GOOGLE_CLIENT_ID"),
      google_client_secret:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret] ||
          System.get_env("GOOGLE_CLIENT_SECRET"),
      facebook_client_id:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Facebook.OAuth)[:client_id] ||
          System.get_env("FACEBOOK_CLIENT_ID"),
      facebook_client_secret:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Facebook.OAuth)[:client_secret] ||
          System.get_env("FACEBOOK_CLIENT_SECRET"),
      email_configured: System.get_env("SMTP_PASSWORD") != nil,
      smtp_username: System.get_env("SMTP_USERNAME"),
      smtp_password: System.get_env("SMTP_PASSWORD"),
      smtp_relay: System.get_env("SMTP_RELAY"),
      sentry_dsn: System.get_env("SENTRY_DSN"),
      env: to_string(Application.get_env(:game_server, :environment, Mix.env())),
      database: Application.get_env(:game_server, GameServer.Repo)[:database] || "N/A",
      hostname:
        Application.get_env(:game_server, GameServerWeb.Endpoint)[:url][:host] ||
          System.get_env("HOSTNAME") || System.get_env("PHX_HOST") || "localhost",
      port: System.get_env("PORT") || "4000",
      secret_key_base:
        System.get_env("SECRET_KEY_BASE") ||
          Application.get_env(:game_server, GameServerWeb.Endpoint)[:secret_key_base],
      live_reload: Application.get_env(:game_server, GameServerWeb.Endpoint)[:live_reload] != nil
    }

    {:ok, assign(socket, :config, config)}
  end
end
