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
                    <td class="font-semibold">Runtime Hooks</td>
                    <td>
                      <%= if @config.hooks_file_path_env do %>
                        <span class="badge badge-success">Configured</span>
                      <% else %>
                        <span class="badge badge-error">Disabled</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      HOOKS_FILE_PATH: {@config.hooks_file_path_env || "<unset>"}<br />
                      <%= if @config.hooks_watch_interval_app || @config.hooks_watch_interval_env do %>
                        Watch interval (app): {@config.hooks_watch_interval_app || "<unset>"} s<br />
                        GAME_SERVER_HOOKS_WATCH_INTERVAL: {@config.hooks_watch_interval_env ||
                          "<unset>"} s<br />
                      <% end %>
                      Registered module:
                      <span class="font-mono">{inspect(@config.hooks_registered_module)}</span>
                      <br /> Last compiled: {@config.hooks_last_compiled_at || "<unset>"}<br />
                      Last compile status:
                      <%= case @config.hooks_last_compile_status do %>
                        <% {:ok, _mod} -> %>
                          <span class="badge badge-success">OK</span>
                        <% {:ok_with_warnings, _mod, warnings} -> %>
                          <span class="badge badge-warning">Warnings</span>
                          <div class="mt-1 text-xs font-mono whitespace-pre-wrap">
                            {String.slice(warnings, 0, 512)}{if String.length(warnings) > 512, do: "…"}
                          </div>
                        <% {:error, reason} -> %>
                          <span class="badge badge-error">Error</span>
                          <div class="mt-1 text-xs font-mono whitespace-pre-wrap">
                            {inspect(reason)}
                          </div>
                        <% _ -> %>
                          &lt;unset&gt;
                      <% end %>
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
                    <td class="font-mono text-sm">
                      DEVICE_AUTH_ENABLED: {@config.device_auth_enabled_env || "<unset>"}
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
                    <td class="font-mono text-sm">
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
                    <td class="font-mono text-sm">
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
                    <td class="font-mono text-sm">
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
                    <td class="font-mono text-sm">
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
                    <td class="font-mono text-sm">
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
                    <td class="text-sm">
                      <div class="font-mono text-sm">
                        SMTP_USERNAME: {mask_secret(@config.smtp_username)}<br />
                        SMTP_PASSWORD: {mask_secret(@config.smtp_password)}<br />
                        SMTP_RELAY: {@config.smtp_relay || "<unset>"}
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
                    <td class="text-sm">
                      LOG_LEVEL: <span class="font-mono">{@config.log_level}</span>
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
                    <td class="font-mono text-sm">
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
                    <td class="text-sm">
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
                          <div class="mt-1">
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
                          <div class="mt-2 grid grid-cols-2 gap-2">
                            <% funcs = GameServer.Hooks.exported_functions() %>
                            <%= if funcs == [] do %>
                              <div class="text-xs text-muted col-span-2">No exported functions</div>
                            <% else %>
                              <%= for f <- funcs do %>
                                <div class="p-2 border rounded bg-base-200">
                                  <div class="font-mono text-sm truncate">
                                    <%= for s <- f.signatures do %>
                                      <div class="truncate">
                                        <span
                                          phx-click="prefill_hook"
                                          phx-value-fn={f.name}
                                          class="cursor-pointer font-semibold"
                                        >
                                          {f.name}/{s.arity}
                                        </span>
                                        <%= if s.signature do %>
                                          <span class="text-muted"> -  {s.signature}</span>
                                        <% end %>
                                        <%!-- example button removed: clicking the function name now auto-prefills the example args --%>
                                        <%= if s.doc do %>
                                          <span class="text-xs block text-muted mt-1">
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
                          <div class="flex gap-2 items-center">
                            <input
                              id="hooks-fn-input"
                              name="fn"
                              value={@hooks_prefill.value || ""}
                              placeholder="function_name"
                              readonly
                              class="input input-sm w-40"
                            />
                            <input
                              id="hooks-args-input"
                              name="args"
                              value={@hooks_args_prefill.value || ""}
                              placeholder="JSON array args (eg [1,2] or [])"
                              class="input input-sm w-96"
                            />
                            <button class="btn btn-primary btn-sm" type="submit">Call</button>
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
      steam_api_key:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Steam)[:api_key] ||
          System.get_env("STEAM_API_KEY"),
      email_configured: System.get_env("SMTP_PASSWORD") != nil,
      smtp_username: System.get_env("SMTP_USERNAME"),
      smtp_password: System.get_env("SMTP_PASSWORD"),
      smtp_relay: System.get_env("SMTP_RELAY"),
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
      # Hooks runtime config diagnostics
      hooks_file_path_app: Application.get_env(:game_server, :hooks_file_path),
      hooks_file_path_env: System.get_env("HOOKS_FILE_PATH"),
      hooks_watch_interval_app: Application.get_env(:game_server, :hooks_file_watch_interval),
      hooks_watch_interval_env: System.get_env("GAME_SERVER_HOOKS_WATCH_INTERVAL"),
      hooks_registered_module: GameServer.Hooks.module(),
      hooks_exported_functions: GameServer.Hooks.exported_functions(),
      hooks_test_result: nil,
      hooks_last_compiled_at: Application.get_env(:game_server, :hooks_last_compiled_at),
      hooks_last_compile_status: Application.get_env(:game_server, :hooks_last_compile_status),
      device_auth_enabled_app: Application.get_env(:game_server, :device_auth_enabled),
      device_auth_enabled_env: System.get_env("DEVICE_AUTH_ENABLED")
    }

    {:ok,
     assign(socket,
       config: config,
       hooks_prefill: %{value: "", seq: 0},
       hooks_args_prefill: %{value: "", seq: 0},
       hooks_full_doc: nil,
       hooks_full_name: nil
     )}
  end

  @impl true
  def handle_event("call_hook", %{"fn" => fn_name, "args" => args_text}, socket) do
    args =
      case args_text do
        v when is_binary(v) and v != "" ->
          case Jason.decode(v) do
            {:ok, parsed} when is_list(parsed) -> parsed
            {:ok, parsed} -> [parsed]
            _ -> []
          end

        _ ->
          []
      end

    result =
      case GameServer.Hooks.call(fn_name, args) do
        {:ok, res} ->
          inspect(res)

        # If function not implemented, and we have a hooks_file_path configured,
        # attempt to register the file and retry the call once so the admin UI
        # can call functions directly when modules are provided as source file.
        {:error, :not_implemented} ->
          src =
            socket.assigns.config.hooks_file_path_app || socket.assigns.config.hooks_file_path_env

          if is_binary(src) and File.exists?(src) do
            case GameServer.Hooks.register_file(src) do
              {:ok, _mod} ->
                case GameServer.Hooks.call(fn_name, args) do
                  {:ok, res2} -> inspect(res2)
                  {:error, r2} -> "error: #{inspect(r2)}"
                end

              {:error, reason} ->
                "error: register_failed: #{inspect(reason)}"
            end
          else
            "error: :not_implemented"
          end

        {:error, reason} ->
          "error: #{inspect(reason)}"
      end

    config = Map.put(socket.assigns.config, :hooks_test_result, result)

    {:noreply, assign(socket, :config, config)}
  end

  @impl true
  def handle_event("prefill_hook", %{"fn" => fn_name}, socket) do
    seq = System.unique_integer([:positive])

    # Try to find example args for the selected function from the mounted
    # hooks_exported_functions (rendered into socket.assigns.config earlier)
    example =
      socket.assigns.config.hooks_exported_functions
      |> Enum.find_value(nil, fn f ->
        if to_string(f.name) == fn_name do
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
        if to_string(f.name) == fn_name do
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
        if to_string(f.name) == fn_name do
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
       hooks_prefill: %{value: fn_name, seq: seq},
       hooks_args_prefill: %{value: example || "", seq: seq},
       hooks_full_doc: doc_text,
       hooks_full_name: full_name
     )}
  end

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

  def handle_event("call_hook", _params, socket), do: {:noreply, socket}

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
