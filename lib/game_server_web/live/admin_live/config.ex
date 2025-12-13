defmodule GameServerWeb.AdminLive.Config do
  use GameServerWeb, :live_view

  alias GameServer.Accounts.UserNotifier
  alias GameServer.Hooks
  alias GameServer.Hooks.PluginBuilder
  alias GameServer.Hooks.PluginManager
  alias GameServer.Schedule
  alias GameServer.Theme.JSONConfig

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.link navigate={~p"/admin"} class="btn btn-outline mb-4">
          ← Back to Admin
        </.link>

    <!-- Current Configuration Status -->
        <div class="card bg-base-100 shadow-xl" data-card-key="config_status">
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
                <.icon name="hero-chevron-down" class="w-4 h-4" />
              </button>
            </h2>
            <div class="overflow-x-auto lg:overflow-x-hidden">
              <table class="table table-zebra table-fixed w-full min-w-[48rem] lg:min-w-0">
                <colgroup>
                  <col class="w-44" />
                  <col class="w-32" />
                  <col class="w-auto" />
                </colgroup>
                <thead>
                  <tr>
                    <th>Service</th>
                    <th>Status</th>
                    <th>Details</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td class="font-semibold">Hooks Plugins</td>
                    <td>
                      <%= if @plugins_counts.total == 0 do %>
                        <span class="badge badge-ghost">None</span>
                      <% else %>
                        <span class="badge badge-success">OK {@plugins_counts.ok}</span>
                        <%= if @plugins_counts.error > 0 do %>
                          <span class="badge badge-error">ERR {@plugins_counts.error}</span>
                        <% end %>
                      <% end %>
                    </td>
                    <td class="text-sm break-words whitespace-normal">
                      <div class="flex flex-wrap items-center gap-3 min-w-0">
                        <div class="font-mono break-all min-w-0">
                          DIR: {PluginManager.plugins_dir()}
                        </div>
                        <button
                          id="plugins-reload-btn"
                          type="button"
                          phx-click="reload_plugins"
                          class="btn btn-outline btn-sm"
                        >
                          Reload plugins
                        </button>
                      </div>

                      <div class="mt-2 flex flex-wrap items-center gap-3">
                        <.form
                          for={@plugin_build_form}
                          id="plugins-build-form"
                          phx-submit="build_plugin_bundle"
                          class="flex flex-wrap items-center gap-2"
                        >
                          <.input
                            field={@plugin_build_form[:name]}
                            type="select"
                            options={@plugin_build_options}
                            class="select select-bordered select-sm w-52"
                          />

                          <button
                            id="plugins-build-btn"
                            type="submit"
                            class="btn btn-outline btn-sm"
                            disabled={@plugin_build_running? or @plugin_build_options == []}
                          >
                            {if @plugin_build_running?, do: "Building…", else: "Build bundle"}
                          </button>

                          <div class="text-xs font-mono opacity-70 break-all">
                            SRC: {PluginBuilder.sources_dir()} — MIX_ENV: {System.get_env("MIX_ENV") || "<unset>"}
                          </div>
                        </.form>
                      </div>

                      <div class="mt-1 text-xs font-mono break-all">
                        Last reload: {@plugins_last_reloaded_at || "<never>"}
                      </div>

                      <%= if @plugins_reload_result do %>
                        <div class="mt-2 text-xs font-mono whitespace-pre-wrap break-words">
                          {inspect(@plugins_reload_result) |> String.slice(0, 1024)}
                          {if String.length(inspect(@plugins_reload_result)) > 1024, do: "…"}
                        </div>
                      <% end %>

                      <%= if @plugin_build_result do %>
                        <div class="mt-3">
                          <div class="flex flex-wrap items-center gap-2">
                            <span class={[
                              "badge badge-sm",
                              if(@plugin_build_result.ok?, do: "badge-success", else: "badge-error")
                            ]}>
                              {if @plugin_build_result.ok?, do: "BUILD OK", else: "BUILD ERR"}
                            </span>

                            <div class="text-xs font-mono opacity-70 break-all">
                              {@plugin_build_result.plugin} — {DateTime.to_iso8601(
                                @plugin_build_result.started_at
                              )} → {DateTime.to_iso8601(@plugin_build_result.finished_at)}
                            </div>
                          </div>

                          <pre class="mt-2 text-xs font-mono whitespace-pre-wrap break-words max-h-64 overflow-auto bg-base-200/60 rounded-lg p-3">{plugin_build_output(@plugin_build_result) |> String.slice(0, 8192)}{if String.length(plugin_build_output(@plugin_build_result)) > 8192, do: "\n…", else: ""}</pre>
                        </div>
                      <% end %>

                      <div class="mt-2 space-y-1">
                        <%= for p <- @plugins do %>
                          <div class="font-mono break-all">
                            {p.name} ({p.vsn || "<no_vsn>"}) —
                            <%= case p.status do %>
                              <% :ok -> %>
                                OK — {inspect(p.hooks_module)}
                              <% {:error, reason} -> %>
                                ERROR — {inspect(reason)}
                            <% end %>
                            <span class="text-xs opacity-70">
                              (loaded_at: {if p.loaded_at,
                                do: DateTime.to_iso8601(p.loaded_at),
                                else: "<unknown>"})
                            </span>
                          </div>
                        <% end %>
                      </div>
                    </td>
                  </tr>
                  <!-- Hooks Test RPC moved to the end of the card -->
                  <tr>
                    <td class="font-semibold">Device auth</td>
                    <td>
                      <%= if @config.device_auth_enabled_app || @config.device_auth_enabled_env do %>
                        <span class="badge badge-success">Enabled</span>
                      <% else %>
                        <span class="badge badge-error">Disabled</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm break-all whitespace-normal">
                      DEVICE_AUTH_ENABLED: {@config.device_auth_enabled_env || "<unset>"}
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Theme</td>
                    <td>
                      <%= if @config.theme_config do %>
                        <span class="badge badge-success">Configured</span>
                      <% else %>
                        <span class="badge badge-error">Default</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm break-all whitespace-normal">
                      THEME_CONFIG: {@config.theme_config || "<unset>"}<br />

                      <div class="mt-2 flex items-center gap-3">
                        <%= if @config.theme_map && Map.get(@config.theme_map, "logo") do %>
                          <img src={Map.get(@config.theme_map, "logo")} alt="logo" class="h-8 w-auto" />
                        <% end %>

                        <%= if @config.theme_map && Map.get(@config.theme_map, "banner") do %>
                          <img
                            src={Map.get(@config.theme_map, "banner")}
                            alt="banner"
                            class="h-8 w-auto"
                          />
                        <% end %>
                      </div>

                      <div class="mt-2">
                        <div class="text-xs font-semibold">Raw JSON</div>
                        <pre class="mt-1 text-xs font-mono whitespace-pre-wrap max-h-48 overflow-auto">{Jason.encode!(@config.theme_map)}</pre>
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Discord OAuth</td>
                    <td>
                      <%= if @config.discord_client_id && @config.discord_client_secret do %>
                        <span class="badge badge-success">Configured</span>
                      <% else %>
                        <span class="badge badge-error">Disabled</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm break-all whitespace-normal">
                      <%= if @config.discord_client_id do %>
                        DISCORD_CLIENT_ID: {mask_secret(@config.discord_client_id)}<br />
                        DISCORD_CLIENT_SECRET: {mask_secret(@config.discord_client_secret)}
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
                        <span class="badge badge-error">Disabled</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm break-all whitespace-normal">
                      <%= if @config.apple_client_id do %>
                        APPLE_CLIENT_ID: {mask_secret(@config.apple_client_id)}<br />
                        APPLE_TEAM_ID: {mask_secret(@config.apple_team_id || "")}<br />
                        APPLE_KEY_ID: {mask_secret(@config.apple_key_id || "")}<br />
                        APPLE_PRIVATE_KEY: {mask_secret(@config.apple_private_key)}
                      <% else %>
                        <span class="text-error">Disabled</span>
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Google OAuth</td>
                    <td>
                      <%= if @config.google_client_id && @config.google_client_secret do %>
                        <span class="badge badge-success">Configured</span>
                      <% else %>
                        <span class="badge badge-error">Disabled</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm break-all whitespace-normal">
                      <%= if @config.google_client_id do %>
                        GOOGLE_CLIENT_ID: {mask_secret(@config.google_client_id)}<br />
                        GOOGLE_CLIENT_SECRET: {mask_secret(@config.google_client_secret)}
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
                        <span class="badge badge-error">Disabled</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm break-all whitespace-normal">
                      <%= if @config.facebook_client_id do %>
                        FACEBOOK_CLIENT_ID: {mask_secret(@config.facebook_client_id)}<br />
                        FACEBOOK_CLIENT_SECRET: {mask_secret(@config.facebook_client_secret)}
                      <% else %>
                        <span class="text-error">Client ID missing</span>
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Steam OpenID</td>
                    <td>
                      <%= if @config.steam_api_key do %>
                        <span class="badge badge-success">Configured</span>
                      <% else %>
                        <span class="badge badge-error">Disabled</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm break-all whitespace-normal">
                      <%= if @config.steam_api_key do %>
                        STEAM_API_KEY: {mask_secret(@config.steam_api_key)}
                      <% else %>
                        <span class="text-error">STEAM_API_KEY: unset</span>
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
                    <td class="text-sm break-words whitespace-normal">
                      <div class="font-mono text-sm">
                        SMTP_USERNAME: {mask_secret(@config.smtp_username)}<br />
                        SMTP_PASSWORD: {mask_secret(@config.smtp_password)}<br />
                        SMTP_RELAY: {@config.smtp_relay || "<unset>"}<br />
                        SMTP_PORT: {@config.smtp_port || "<unset>"}<br />
                        SMTP_SSL: {@config.smtp_ssl || "<unset>"} SMTP_TLS: {@config.smtp_tls ||
                          "<unset>"}<br /> SMTP_SNI: {mask_secret(@config.smtp_sni)}<br />
                        SMTP_FROM_NAME: {mask_secret(@config.smtp_from_name || "")}<br />
                        SMTP_FROM_EMAIL: {mask_secret(@config.smtp_from_email || "")}
                      </div>

                      <div class="mt-2 text-xs text-muted">
                        <p class="mb-1">Notes on TLS modes:</p>
                        <ul class="list-disc ml-4">
                          <li>
                            <strong>SMTPS (implicit SSL)</strong>
                            — set <code>SMTP_SSL=true</code>
                            and use an
                            implicit SSL port (eg. <code>2465</code>
                            or <code>465</code>). When using implicit SSL
                            it's recommended to set <code>SMTP_TLS=never</code>
                            and provide an <code>SMTP_SNI</code>
                            (Server Name Indication) when your provider requires it (example: <code>mail.resend.com</code>).
                          </li>
                          <li>
                            <strong>STARTTLS</strong>
                            — use <code>SMTP_SSL=false</code>
                            with <code>SMTP_PORT=587</code>
                            and <code>SMTP_TLS=always</code>
                            (preferred for most providers).
                          </li>
                        </ul>

                        <div class="mt-2">
                          <a
                            href="https://resend.com/docs/smtp"
                            target="_blank"
                            rel="noopener"
                            class="link link-primary text-xs"
                          >
                            Provider docs: Resend SMTP guide
                          </a>
                          <span class="text-xs text-muted ml-2">· see repo docs for examples</span>
                        </div>

                        <div class="mt-3 text-xs text-muted">
                          <p class="mb-1 font-semibold">From address & domain verification</p>
                          <p>
                            Ensure the <code>SMTP_FROM_EMAIL</code> you configure is a
                            verified sender/domain in your SMTP provider — many providers
                            require verification before relaying mail and may return errors
                            like <code>450 domain not verified</code> otherwise.
                          </p>
                          <p class="mt-2">
                            You can set a friendly sender name via <code>SMTP_FROM_NAME</code>.
                            If you need to test delivery, use the <em>Send test email</em>
                            button above to verify runtime delivery and messages.
                          </p>
                        </div>
                      </div>
                      <%= if @config.email_configured do %>
                        SMTP configured - emails are sent via {@config.smtp_relay ||
                          "configured relay"}
                      <% else %>
                        <%= if @config.env == "dev" do %>
                          Using local delivery - emails are not sent (<a
                            href="/dev/mailbox"
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
                    <td class="font-mono text-sm break-all whitespace-normal">{@config.env}</td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Log Level</td>
                    <td>
                      <span class={[
                        "badge",
                        case @config.log_level do
                          :debug -> "badge-info"
                          :info -> "badge-success"
                          :warning -> "badge-warning"
                          :error -> "badge-error"
                          _ -> "badge-neutral"
                        end
                      ]}>
                        {String.upcase(to_string(@config.log_level))}
                      </span>
                    </td>
                    <td class="text-sm break-words whitespace-normal">
                      LOG_LEVEL: <span class="font-mono break-all">{@config.log_level}</span>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Database</td>
                    <td>
                      <%= case @config.database_adapter do %>
                        <% :postgres -> %>
                          <span class="badge badge-success">Postgres</span>
                        <% :sqlite -> %>
                          <span class="badge badge-info">SQLite</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm break-all whitespace-normal">
                      <div class="mt-2 text-sm">
                        <div>
                          DATABASE_URL:
                          <span class="font-mono">
                            {if @config.pg_database_url, do: "set", else: "<unset>"}
                          </span>
                        </div>
                        <div>
                          POSTGRES_HOST: <span class="font-mono">{@config.pg_host || "<unset>"}</span>
                        </div>
                        <div>
                          POSTGRES_USER: <span class="font-mono">{@config.pg_user || "<unset>"}</span>
                        </div>
                        <div>
                          POSTGRES_DB: <span class="font-mono">{@config.pg_db || "<unset>"}</span>
                        </div>
                        <div>
                          POSTGRES_PASSWORD:
                          <span class="font-mono">{mask_secret(@config.pg_password)}</span>
                        </div>
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Hostname</td>
                    <td><span class="badge badge-info">System</span></td>
                    <td class="font-mono text-sm break-all whitespace-normal">
                      {@config.hostname || "Not set"}
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Port</td>
                    <td><span class="badge badge-info">Server</span></td>
                    <td class="font-mono text-sm break-all whitespace-normal">
                      {@config.port || "4000"}
                    </td>
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
                    <td class="font-mono text-sm break-all whitespace-normal">
                      <%= if @config.secret_key_base do %>
                        SECRET_KEY_BASE: {mask_secret(@config.secret_key_base)}
                      <% else %>
                        Disabled
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
                    <td class="text-sm break-words whitespace-normal">
                      <%= if @config.sentry_dsn do %>
                        <span class="font-mono text-sm">
                          SENTRY_LOG_LEVEL:
                          <span class={[
                            "font-semibold",
                            case @config.sentry_log_level do
                              "info" -> "text-info"
                              "warning" -> "text-warning"
                              _ -> "text-error"
                            end
                          ]}>
                            {@config.sentry_log_level || "error"}
                          </span>
                          <div class="mt-1 break-all">
                            SENTRY_DSN:
                            <span class="font-mono">{mask_secret(@config.sentry_dsn)}</span>
                          </div>
                        </span>
                      <% else %>
                        <span class="text-error">SENTRY_DSN not set - errors won't be monitored</span>
                      <% end %>
                    </td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Hooks - Test RPC</td>
                    <td colspan="2">
                      <div class="space-y-2">
                        <div class="text-sm">
                          <p class="text-xs font-semibold">Available functions</p>
                          <div class="mt-2 grid grid-cols-1 lg:grid-cols-2 gap-2">
                            <% funcs = @config.hooks_exported_functions %>
                            <%= if funcs == [] do %>
                              <div class="text-xs text-muted col-span-2">No exported functions</div>
                            <% else %>
                              <%= for f <- funcs do %>
                                <div class="p-2 border rounded bg-base-200 min-w-0">
                                  <div class="font-mono text-sm min-w-0">
                                    <%= for s <- f.signatures do %>
                                      <div class="min-w-0">
                                        <div class="break-all">
                                          <span
                                            phx-click="prefill_hook"
                                            phx-value-fn={f.name}
                                            phx-value-plugin={f.plugin}
                                            class="cursor-pointer font-semibold"
                                          >
                                            {f.plugin}:{f.name}/{s.arity}
                                          </span>
                                          <%= if s.signature do %>
                                            <span class="text-muted">
                                              - {s.signature}
                                            </span>
                                          <% end %>
                                        </div>
                                        <%= if s.doc do %>
                                          <span class="text-xs block text-muted mt-1 break-words whitespace-normal">
                                            {String.slice(s.doc, 0, 200)}{if String.length(s.doc) >
                                                                               200,
                                                                             do: "…"}
                                          </span>
                                        <% end %>
                                      </div>
                                    <% end %>
                                  </div>
                                </div>
                              <% end %>
                            <% end %>
                          </div>
                        </div>

                        <.form for={%{}} phx-submit="call_hook" id="hooks-call-form">
                          <div class="flex flex-col md:flex-row gap-2 md:items-center min-w-0">
                            <input
                              id="hooks-plugin-input"
                              name="plugin"
                              value={@hooks_plugin_prefill.value || ""}
                              placeholder="plugin_name"
                              readonly
                              class="input input-sm w-full md:w-40 min-w-0"
                            />
                            <input
                              id="hooks-fn-input"
                              name="fn"
                              value={@hooks_prefill.value || ""}
                              placeholder="function_name"
                              readonly
                              class="input input-sm w-full md:w-40 min-w-0"
                            />
                            <input
                              id="hooks-args-input"
                              name="args"
                              value={@hooks_args_prefill.value || ""}
                              placeholder="JSON array args (eg [1,2] or [])"
                              class="input input-sm w-full md:flex-1 min-w-0"
                            />
                            <button class="btn btn-primary btn-sm w-full md:w-auto" type="submit">
                              Call
                            </button>
                          </div>
                        </.form>

                        <div class="font-mono text-sm">
                          <%= if @config.hooks_test_result do %>
                            <div>Result: {@config.hooks_test_result}</div>
                          <% else %>
                            <div class="text-xs text-muted">No test yet</div>
                          <% end %>
                        </div>

    <!-- Full docs modal / pane -->
                        <%= if @hooks_full_doc do %>
                          <div class="mt-2 p-3 border rounded bg-base-100">
                            <div class="flex items-center justify-between">
                              <div class="font-semibold">Full docs: {@hooks_full_name}</div>
                              <div>
                                <button
                                  type="button"
                                  phx-click="close_docs"
                                  class="btn btn-outline btn-sm"
                                >
                                  Close
                                </button>
                              </div>
                            </div>
                            <pre class="whitespace-pre-wrap text-sm mt-2 font-mono">{@hooks_full_doc}</pre>
                          </div>
                        <% end %>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

    <!-- Admin Tools -->
        <div class="card bg-base-100 shadow-xl" data-card-key="admin_tools">
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
                <a href="/dev/mailbox" class="btn btn-outline btn-secondary">
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
              <%= if @current_scope && @current_scope.user && @current_scope.user.email do %>
                <button phx-click="send_test_email" class="btn btn-outline btn-accent">
                  Send test email
                </button>
              <% end %>
            </div>
          </div>
        </div>

    <!-- Scheduled Jobs -->
        <div class="card bg-base-100 shadow-xl" data-card-key="scheduled_jobs">
          <div class="card-body">
            <h2 class="card-title text-xl mb-4 flex items-center gap-3">
              <.icon name="hero-clock" class="w-5 h-5" /> Scheduled Jobs
              <button
                type="button"
                data-action="toggle-card"
                data-card-key="scheduled_jobs"
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
            <%= if @scheduled_jobs == [] do %>
              <div class="text-sm text-base-content/60">
                No scheduled jobs registered. Use <code class="font-mono">Schedule.hourly/2</code>, <code class="font-mono">Schedule.daily/2</code>, etc. in your hook's
                <code class="font-mono">after_startup/0</code>
                callback.
              </div>
            <% else %>
              <div class="overflow-x-auto lg:overflow-x-hidden">
                <table class="table table-zebra table-sm table-fixed w-full min-w-[32rem] lg:min-w-0">
                  <thead>
                    <tr>
                      <th>Job Name</th>
                      <th>Schedule</th>
                      <th>State</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for job <- @scheduled_jobs do %>
                      <tr>
                        <td class="font-mono text-sm break-all whitespace-normal">{job.name}</td>
                        <td class="font-mono text-sm break-all whitespace-normal">{job.schedule}</td>
                        <td>
                          <span class={[
                            "badge badge-sm",
                            if(job.state == :active, do: "badge-success", else: "badge-warning")
                          ]}>
                            {job.state}
                          </span>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
              <div class="text-xs text-base-content/60 mt-2">
                {length(@scheduled_jobs)} job(s) registered. Jobs are distributed-safe via database locks.
              </div>
            <% end %>
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
      steam_api_key:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Steam)[:api_key] ||
          System.get_env("STEAM_API_KEY"),
      email_configured: System.get_env("SMTP_PASSWORD") != nil,
      smtp_username: System.get_env("SMTP_USERNAME"),
      smtp_password: System.get_env("SMTP_PASSWORD"),
      smtp_relay: System.get_env("SMTP_RELAY"),
      smtp_port: System.get_env("SMTP_PORT"),
      smtp_ssl: System.get_env("SMTP_SSL"),
      smtp_from_name: System.get_env("SMTP_FROM_NAME"),
      smtp_from_email: System.get_env("SMTP_FROM_EMAIL"),
      smtp_sni: System.get_env("SMTP_SNI"),
      smtp_tls: System.get_env("SMTP_TLS"),
      sentry_dsn: System.get_env("SENTRY_DSN"),
      sentry_log_level: System.get_env("SENTRY_LOG_LEVEL"),
      env: to_string(Application.get_env(:game_server, :environment, Mix.env())),
      repo_conf: Application.get_env(:game_server, GameServer.Repo) || %{},
      database: Application.get_env(:game_server, GameServer.Repo)[:database] || "N/A",
      # Database environment diagnostics (don't show raw passwords)
      database_adapter: detect_db_adapter(),
      pg_database_url: System.get_env("DATABASE_URL"),
      pg_host: System.get_env("POSTGRES_HOST"),
      pg_user: System.get_env("POSTGRES_USER"),
      pg_db: System.get_env("POSTGRES_DB"),
      pg_password: System.get_env("POSTGRES_PASSWORD"),
      # DB source detection and masked effective value for admin UI
      db_source: detect_db_source(),
      db_effective_value: detect_effective_db_value(),
      hostname:
        Application.get_env(:game_server, GameServerWeb.Endpoint)[:url][:host] ||
          System.get_env("HOSTNAME") || System.get_env("PHX_HOST") || "localhost",
      port: System.get_env("PORT") || "4000",
      secret_key_base:
        System.get_env("SECRET_KEY_BASE") ||
          Application.get_env(:game_server, GameServerWeb.Endpoint)[:secret_key_base],
      live_reload: Application.get_env(:game_server, GameServerWeb.Endpoint)[:live_reload] != nil,
      log_level: Logger.level(),
      log_level_env: System.get_env("LOG_LEVEL"),
      # Hooks plugin diagnostics
      hooks_exported_functions: exported_plugin_functions(),
      hooks_test_result: nil,
      # Theme configuration diagnostics: reuse the existing Theme provider
      # implementation so behavior is consistent across the app. We expose three
      # keys used by the template:
      #  - :theme_config -> the runtime THEME_CONFIG env value (path) or nil
      #  - :theme_map -> resolved theme map (merged default + runtime file)
      #  - :theme_json -> raw JSON shown in the UI (runtime file contents or packaged default)
      theme_map: JSONConfig.get_theme(),
      # Only rely on JSONConfig for decisions about runtime vs default and raw
      # content. Keep logic inside the provider instead of duplicating parsing
      # here.
      theme_config: JSONConfig.runtime_path(),
      device_auth_enabled_app: Application.get_env(:game_server, :device_auth_enabled),
      device_auth_enabled_env: System.get_env("DEVICE_AUTH_ENABLED")
    }

    {:ok,
     assign(socket,
       config: config,
       scheduled_jobs: Schedule.list(),
       hooks_plugin_prefill: %{value: "", seq: 0},
       hooks_prefill: %{value: "", seq: 0},
       hooks_args_prefill: %{value: "", seq: 0},
       hooks_full_doc: nil,
       hooks_full_name: nil,
       plugins: PluginManager.list(),
       plugins_counts: plugin_counts(PluginManager.list()),
       plugins_last_reloaded_at: nil,
       plugins_reload_result: nil,
       plugin_build_options: plugin_build_options(),
       plugin_build_running?: false,
       plugin_build_result: nil,
       plugin_build_form:
         to_form(%{"name" => default_plugin_build_selection()}, as: :plugin_build)
     )}
  end

  @impl true
  def handle_event("reload_plugins", _params, socket) do
    res = PluginManager.reload_and_after_startup()

    plugins = PluginManager.list()
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    {:noreply,
     assign(socket,
       plugins: plugins,
       plugins_counts: plugin_counts(plugins),
       plugins_last_reloaded_at: now,
       plugins_reload_result: res
     )}
  end

  @impl true
  def handle_event("build_plugin_bundle", %{"plugin_build" => %{"name" => name}}, socket)
      when is_binary(name) do
    cond do
      socket.assigns.plugin_build_running? ->
        {:noreply, socket}

      socket.assigns.plugin_build_options == [] ->
        {:noreply, put_flash(socket, :error, "No buildable plugins found under #{PluginBuilder.sources_dir()}")}

      true ->
        parent = self()

        Task.start(fn ->
          result = PluginBuilder.build(name)
          send(parent, {:plugin_build_finished, name, result})
        end)

        {:noreply,
         socket
         |> assign(:plugin_build_running?, true)
         |> assign(:plugin_build_result, nil)
         |> put_flash(:info, "Building plugin bundle for #{name}…")}
    end
  end

  @impl true
  def handle_event(
        "call_hook",
        %{"plugin" => plugin, "fn" => fn_name, "args" => args_text},
        socket
      )
      when is_binary(plugin) and is_binary(fn_name) do
    args = parse_hook_args(args_text)

    caller = socket.assigns.current_scope && socket.assigns.current_scope.user

    result =
      case PluginManager.call_rpc(plugin, fn_name, args, caller: caller) do
        {:ok, res} ->
          inspect(res)

        {:error, reason} ->
          "error: #{inspect(reason)}"
      end

    config = Map.put(socket.assigns.config, :hooks_test_result, result)

    {:noreply, assign(socket, :config, config)}
  end

  def handle_event("send_test_email", _params, socket) do
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    case user && user.email do
      nil ->
        {:noreply, put_flash(socket, :error, "No email address available for current admin")}

      email when is_binary(email) ->
        case UserNotifier.deliver_test_email(email) do
          {:ok, _} ->
            {:noreply, put_flash(socket, :info, "Test email sent to #{email}")}

          other ->
            # Log full details for diagnostic purposes
            require Logger
            Logger.error("send_test_email failed: #{inspect(other)}")

            # Surface useful error detail in development so admins can debug
            debug_msg =
              if socket.assigns.config && socket.assigns.config.env == "dev" do
                " (details: #{inspect(other) |> to_string() |> String.slice(0, 512)})"
              else
                ""
              end

            {:noreply,
             put_flash(
               socket,
               :error,
               "Failed to send test email — check mailer logs and configuration" <> debug_msg
             )}
        end
    end
  end

  def handle_event("call_hook", _params, socket), do: {:noreply, socket}
  @impl true
  def handle_event("prefill_hook", %{"plugin" => plugin, "fn" => fn_name}, socket)
      when is_binary(plugin) and is_binary(fn_name) do
    seq = System.unique_integer([:positive])

    # Try to find example args for the selected function from the mounted
    # hooks_exported_functions (rendered into socket.assigns.config earlier)
    example =
      socket.assigns.config.hooks_exported_functions
      |> Enum.find_value(nil, fn f ->
        if to_string(f.name) == fn_name and to_string(f.plugin) == plugin do
          case f.signatures do
            [first | _] -> Map.get(first, :example_args) || ""
            _ -> nil
          end
        else
          nil
        end
      end)

    # Also set full docs panel when doc text is available
    doc_text =
      socket.assigns.config.hooks_exported_functions
      |> Enum.find_value(nil, fn f ->
        if to_string(f.name) == fn_name and to_string(f.plugin) == plugin do
          case f.signatures do
            [first | _] -> Map.get(first, :doc)
            _ -> nil
          end
        else
          nil
        end
      end)

    full_name =
      socket.assigns.config.hooks_exported_functions
      |> Enum.find_value(nil, fn f ->
        if to_string(f.name) == fn_name and to_string(f.plugin) == plugin do
          case f.signatures do
            [first | _] -> "#{fn_name}/#{first.arity}"
            _ -> nil
          end
        else
          nil
        end
      end)

    {:noreply,
     assign(socket,
       hooks_plugin_prefill: %{value: plugin, seq: seq},
       hooks_prefill: %{value: fn_name, seq: seq},
       hooks_args_prefill: %{value: example || "", seq: seq},
       hooks_full_doc: doc_text,
       hooks_full_name: if(full_name, do: "#{plugin}:#{full_name}", else: nil)
     )}
  end

  def handle_event("prefill_hook", _params, socket), do: {:noreply, socket}

  def handle_event("prefill_args", %{"args" => args_text}, socket) do
    seq = System.unique_integer([:positive])
    {:noreply, assign(socket, :hooks_args_prefill, %{value: args_text, seq: seq})}
  end

  def handle_event("show_docs", %{"doc" => doc, "name" => name, "arity" => arity}, socket) do
    # arity may arrive as string; keep it as-is for display
    full_name = "#{name}/#{arity}"
    {:noreply, assign(socket, hooks_full_doc: doc, hooks_full_name: full_name)}
  end

  def handle_event("close_docs", _params, socket),
    do: {:noreply, assign(socket, hooks_full_doc: nil, hooks_full_name: nil)}

  @impl true
  def handle_info({:plugin_build_finished, _name, {:ok, build_result}}, socket) do
    {:noreply,
     socket
     |> assign(:plugin_build_running?, false)
     |> assign(:plugin_build_result, build_result)
     |> put_flash(:info, "Plugin build finished")}
  end

  @impl true
  def handle_info({:plugin_build_finished, _name, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:plugin_build_running?, false)
     |> put_flash(:error, "Plugin build failed: #{inspect(reason)}")}
  end

  defp plugin_build_options do
    PluginBuilder.list_buildable_plugins()
    |> Enum.map(fn name -> {name, name} end)
  end

  defp default_plugin_build_selection do
    plugin_build_options()
    |> Enum.at(0)
    |> case do
      {name, _} -> name
      _ -> ""
    end
  end

  defp plugin_build_output(%{steps: steps}) when is_list(steps) do
    steps
    |> Enum.map_join("\n\n", fn s ->
      "$ #{s.cmd} (exit=#{s.status})\n" <> (s.output || "")
    end)
    |> String.trim()
  end

  defp parse_hook_args(v) when is_binary(v) and v != "" do
    case Jason.decode(v) do
      {:ok, parsed} when is_list(parsed) -> parsed
      {:ok, parsed} -> [parsed]
      _ -> []
    end
  end

  defp parse_hook_args(_), do: []

  defp exported_plugin_functions do
    PluginManager.hook_modules()
    |> Enum.flat_map(fn {plugin, mod} ->
      Hooks.exported_functions(mod)
      |> Enum.map(&Map.put(&1, :plugin, plugin))
    end)
    |> Enum.sort_by(fn f -> {f.plugin, f.name} end)
  end

  defp detect_db_adapter do
    repo_conf = Application.get_env(:game_server, GameServer.Repo) || %{}

    cond do
      System.get_env("DATABASE_URL") -> :postgres
      System.get_env("POSTGRES_HOST") && System.get_env("POSTGRES_USER") -> :postgres
      repo_conf[:adapter] in [Ecto.Adapters.Postgres, Ecto.Adapters.Postgres] -> :postgres
      true -> :sqlite
    end
  end

  defp detect_db_source do
    repo_conf = Application.get_env(:game_server, GameServer.Repo) || %{}

    cond do
      System.get_env("DATABASE_URL") -> :database_url
      System.get_env("POSTGRES_HOST") && System.get_env("POSTGRES_USER") -> :env_vars
      repo_conf[:adapter] in [Ecto.Adapters.Postgres] -> :repo_config
      true -> :sqlite
    end
  end

  defp detect_effective_db_value do
    case System.get_env("DATABASE_URL") do
      v when is_binary(v) and v != "" ->
        v

      _ ->
        host = System.get_env("POSTGRES_HOST")
        user = System.get_env("POSTGRES_USER")
        db = System.get_env("POSTGRES_DB")
        pw = System.get_env("POSTGRES_PASSWORD")

        if host || user || db do
          "postgres://#{user || "<unset>"}@#{host || "<unset>"}/#{db || "<unset>"}#{if pw, do: ":(pwd)", else: ""}"
        else
          repo_conf = Application.get_env(:game_server, GameServer.Repo) || %{}
          to_string(repo_conf[:database] || "N/A")
        end
    end
  end

  defp plugin_counts(plugins) when is_list(plugins) do
    Enum.reduce(plugins, %{total: 0, ok: 0, error: 0}, fn plugin, acc ->
      acc = %{acc | total: acc.total + 1}

      case plugin.status do
        :ok -> %{acc | ok: acc.ok + 1}
        {:error, _} -> %{acc | error: acc.error + 1}
        _ -> acc
      end
    end)
  end

  # Helpers for masking secrets shown in the admin UI.
  # We show the first 2 and last 2 characters for secrets longer than 6
  # (e.g. ab...yz). For very short values we show them with a small mask.
  defp mask_secret(nil), do: "<unset>"
  defp mask_secret(""), do: "<unset>"

  defp mask_secret(s) when is_binary(s) do
    len = byte_size(s)

    if len <= 4 do
      String.duplicate("*", len)
    else
      # Reveal a roughly half-window by showing the first and last ceil(len/4)
      # characters. This is a balance between usefulness and not leaking
      # full secrets in the admin UI.
      visible = max(1, div(len + 3, 4))
      first = String.slice(s, 0, visible)
      last = String.slice(s, -visible, visible)
      "#{first}...#{last}"
    end
  end
end
