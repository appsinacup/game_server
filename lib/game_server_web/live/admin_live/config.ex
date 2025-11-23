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
                        Private Key: {(@config.apple_private_key && "Set") || "Not set"}
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
        
    <!-- Apple Sign In Setup Guide -->
        <div class="card bg-base-100 shadow-xl collapsed" data-card-key="apple_signin">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4 flex items-center gap-3">
              <svg class="w-8 h-8" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09l.01-.01zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
              </svg>
              Apple Sign In Setup Guide
              <button
                type="button"
                data-action="toggle-card"
                data-card-key="apple_signin"
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

            <div class="alert alert-info mb-6">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                class="stroke-current shrink-0 w-6 h-6"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
              <div>
                <p>
                  <strong>Why Apple Sign In?</strong>
                  Required for iOS apps and provides a privacy-focused authentication method. Users can sign in with their Apple ID.
                </p>
              </div>
            </div>

            <div class="space-y-6">
              <!-- Step 1: Apple Developer Account -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">1</span> Apple Developer Account
                </h3>
                <div class="ml-8 space-y-3">
                  <p>
                    You need an
                    <a
                      href="https://developer.apple.com/programs/"
                      target="_blank"
                      class="link link-primary"
                    >
                      Apple Developer Account
                    </a>
                    ($99/year)
                  </p>
                  <div class="alert alert-warning">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="stroke-current shrink-0 h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                      />
                    </svg>
                    <div>
                      <p>
                        <strong>Note:</strong>
                        Apple Sign In requires a paid Apple Developer account. Free accounts cannot create Service IDs or Keys.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 2: Create App ID -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">2</span> Create App ID
                </h3>
                <div class="ml-8 space-y-3">
                  <p>
                    Go to
                    <a
                      href="https://developer.apple.com/account/resources/identifiers/list"
                      target="_blank"
                      class="link link-primary"
                    >
                      Certificates, Identifiers & Profiles
                    </a>
                  </p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Click the "+" button to create a new identifier</li>
                    <li>Select "App IDs" and click Continue</li>
                    <li>Select "App" type and click Continue</li>
                    <li>Enter a description (e.g., "Game Server")</li>
                    <li>Enter a Bundle ID (e.g., com.yourcompany.gameserver)</li>
                    <li>Scroll down and check "Sign in with Apple"</li>
                    <li>Click Continue and Register</li>
                  </ol>
                </div>
              </div>
              
    <!-- Step 3: Create Service ID -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">3</span> Create Service ID (Client ID)
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Back in Certificates, Identifiers & Profiles:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Click "+" to create new identifier</li>
                    <li>Select "Services IDs" and click Continue</li>
                    <li>Enter description (e.g., "Game Server Web")</li>
                    <li>
                      Enter identifier (e.g., com.yourcompany.gameserver.web) - This is your CLIENT_ID
                    </li>
                    <li>Check "Sign in with Apple"</li>
                    <li>Click "Configure" next to Sign in with Apple</li>
                    <li>Select your App ID as the Primary App ID</li>
                    <li>
                      Add these domains and redirect URLs:<br />
                      <div class="bg-base-200 p-2 rounded mt-2 font-mono text-xs">
                        <div>Domain: {@config.hostname}</div>
                        <div>Return URL: https://{@config.hostname}/auth/apple/callback</div>
                      </div>
                    </li>
                    <li>Click Save, then Continue, then Register</li>
                  </ol>
                  <div class="bg-base-200 p-4 rounded-lg mt-4">
                    <div class="font-semibold mb-2">Your Client ID (Service ID Identifier)</div>
                    <div class="font-mono text-xs bg-base-300 p-2 rounded">
                      com.yourcompany.gameserver.web
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 4: Create Private Key -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">4</span> Create Private Key
                </h3>
                <div class="ml-8 space-y-3">
                  <p>In Certificates, Identifiers & Profiles, go to Keys:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Click "+" to create a new key</li>
                    <li>Enter a name (e.g., "Game Server Sign in with Apple Key")</li>
                    <li>Check "Sign in with Apple"</li>
                    <li>Click "Configure" next to Sign in with Apple</li>
                    <li>Select your App ID as the Primary App ID</li>
                    <li>Click Save, then Continue</li>
                    <li>Click Register</li>
                    <li>
                      <strong>Download the .p8 file</strong> - you can only download this once!
                    </li>
                    <li>
                      Note the Key ID (e.g., ABC123XYZ) shown on the confirmation page
                    </li>
                  </ol>
                  <div class="alert alert-error mt-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="stroke-current shrink-0 h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                      />
                    </svg>
                    <div>
                      <p>
                        <strong>Critical:</strong>
                        You can only download the .p8 file once! Store it securely. If lost, you'll need to create a new key.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 5: Get Team ID -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">5</span> Get Your Team ID
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Find your Team ID:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>
                      Go to
                      <a
                        href="https://developer.apple.com/account/#/membership/"
                        target="_blank"
                        class="link link-primary"
                      >
                        Membership Details
                      </a>
                    </li>
                    <li>Your Team ID is listed there (10 characters, e.g., A1B2C3D4E5)</li>
                  </ol>
                </div>
              </div>
              
    <!-- Step 6: Configure Environment Variables -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">6</span> Configure Environment Variables
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Set these environment variables:</p>
                  <div class="bg-base-200 p-4 rounded-lg font-mono text-sm">
                    <div class="space-y-2">
                      <div>APPLE_CLIENT_ID="com.yourcompany.gameserver.web"</div>
                      <div>APPLE_TEAM_ID="A1B2C3D4E5"</div>
                      <div>APPLE_KEY_ID="ABC123XYZ"</div>
                      <div>APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----</div>
                      <div>MIGTAgEAMBMGByq...your key content...</div>
                      <div>-----END PRIVATE KEY-----"</div>
                    </div>
                  </div>
                  <div class="alert alert-info mt-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      class="stroke-current shrink-0 w-6 h-6"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      >
                      </path>
                    </svg>
                    <div>
                      <p>
                        <strong>Tip:</strong>
                        For APPLE_PRIVATE_KEY, open the .p8 file in a text editor and copy the entire contents including the BEGIN/END lines.
                      </p>
                    </div>
                  </div>
                  <div class="alert alert-warning mt-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="stroke-current shrink-0 h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                      />
                    </svg>
                    <div>
                      <p>
                        <strong>Security:</strong>
                        Never commit the private key to version control. Use your deployment platform's secret management.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 7: Test -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">7</span> Test Apple Sign In
                </h3>
                <div class="ml-8 space-y-3">
                  <p>After deploying with the secrets:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Go to your app's login page</li>
                    <li>Click "Sign in with Apple"</li>
                    <li>Authorize the application with your Apple ID</li>
                    <li>You should be redirected back and logged in</li>
                  </ol>
                  <div class="alert alert-info mt-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      class="stroke-current shrink-0 w-6 h-6"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      >
                      </path>
                    </svg>
                    <div>
                      <p>
                        <strong>Note:</strong>
                        Apple Sign In for web only works on HTTPS in production. For local testing, use ngrok or similar to get HTTPS.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="card-actions justify-end mt-6">
              <a
                href="https://developer.apple.com/account/resources/identifiers/list"
                target="_blank"
                class="btn btn-primary"
              >
                Open Apple Developer Portal
                <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                  />
                </svg>
              </a>
            </div>
          </div>
        </div>
        
    <!-- Discord OAuth Setup Guide -->
        <div class="card bg-base-100 shadow-xl collapsed" data-card-key="discord_oauth">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4 flex items-center gap-3">
              <svg class="w-8 h-8 text-indigo-600" fill="currentColor" viewBox="0 0 24 24">
                <path d="M20.317 4.492c-1.53-.69-3.17-1.2-4.885-1.49a.075.075 0 0 0-.079.036c-.21.369-.444.85-.608 1.23a18.566 18.566 0 0 0-5.487 0 12.36 12.36 0 0 0-.617-1.23A.077.077 0 0 0 8.562 3c-1.714.29-3.354.8-4.885 1.491a.07.07 0 0 0-.032.027C.533 9.093-.32 13.555.099 17.961a.08.08 0 0 0 .031.055 20.03 20.03 0 0 0 5.993 2.98.078.078 0 0 0 .084-.026 13.83 13.83 0 0 0 1.226-1.963.074.074 0 0 0-.041-.104 13.201 13.201 0 0 1-1.872-.878.075.075 0 0 1-.008-.125c.126-.093.252-.19.372-.287a.075.075 0 0 1 .078-.01c3.927 1.764 8.18 1.764 12.061 0a.075.075 0 0 1 .079.009c.12.098.245.195.372.288a.075.075 0 0 1-.006.125c-.598.344-1.22.635-1.873.877a.075.075 0 0 0-.041.105c.36.687.772 1.341 1.225 1.962a.077.077 0 0 0 .084.028 19.963 19.963 0 0 0 6.002-2.981.076.076 0 0 0 .032-.054c.5-5.094-.838-9.52-3.549-13.442a.06.06 0 0 0-.031-.028zM8.02 15.278c-1.182 0-2.157-1.069-2.157-2.38 0-1.312.956-2.38 2.157-2.38 1.21 0 2.176 1.077 2.157 2.38 0 1.312-.956 2.38-2.157 2.38zm7.975 0c-1.183 0-2.157-1.069-2.157-2.38 0-1.312.955-2.38 2.157-2.38 1.21 0 2.176 1.077 2.157 2.38 0 1.312-.946 2.38-2.157 2.38z" />
              </svg>
              Discord OAuth Setup Guide
              <button
                type="button"
                data-action="toggle-card"
                data-card-key="discord_oauth"
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

            <div class="alert alert-info mb-6">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                class="stroke-current shrink-0 w-6 h-6"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
              <div>
                <p>
                  <strong>Why Discord OAuth?</strong>
                  Allows users to sign up and log in using their Discord accounts instead of creating separate credentials.
                </p>
              </div>
            </div>

            <div class="space-y-6">
              <!-- Step 1: Create Discord Application -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">1</span> Create Discord Application
                </h3>
                <div class="ml-8 space-y-3">
                  <p>
                    Go to the
                    <a
                      href="https://discord.com/developers/applications"
                      target="_blank"
                      class="link link-primary"
                    >
                      Discord Developer Portal
                    </a>
                  </p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Click "New Application" in the top right</li>
                    <li>Give your app a name (e.g., "Game Server")</li>
                    <li>Go to the "OAuth2" → "General" tab</li>
                  </ol>
                </div>
              </div>
              
    <!-- Step 2: Configure Redirect URIs -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">2</span> Configure Redirect URIs
                </h3>
                <div class="ml-8 space-y-3">
                  <p>In the OAuth2 General settings, add these redirect URIs:</p>
                  <div class="bg-base-200 p-4 rounded-lg font-mono text-sm">
                    <div class="space-y-1">
                      <div>
                        <strong>Development:</strong> http://localhost:4000/auth/discord/callback
                      </div>
                      <div>
                        <strong>Production:</strong> https://{@config.hostname}/auth/discord/callback
                      </div>
                    </div>
                  </div>
                  <p class="text-sm text-base-content/70">
                    These are the URLs Discord will redirect users back to after authorization.
                  </p>
                </div>
              </div>
              
    <!-- Step 3: Get Application Credentials -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">3</span> Get Application Credentials
                </h3>
                <div class="ml-8 space-y-3">
                  <p>From the OAuth2 General tab, copy these values:</p>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div class="bg-base-200 p-4 rounded-lg">
                      <div class="font-semibold mb-2">Client ID</div>
                      <div class="text-sm text-base-content/70">
                        Found at the top of OAuth2 General
                      </div>
                      <div class="font-mono text-xs mt-2 bg-base-300 p-2 rounded">
                        123456789012345678
                      </div>
                    </div>
                    <div class="bg-base-200 p-4 rounded-lg">
                      <div class="font-semibold mb-2">Client Secret</div>
                      <div class="text-sm text-base-content/70">Click "Reset Secret" to generate</div>
                      <div class="font-mono text-xs mt-2 bg-base-300 p-2 rounded">
                        abcdefghijklmnopqrstuvwx
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 4: Configure Application -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">4</span> Configure Application Secrets
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Set these environment variables:</p>
                  <div class="bg-base-200 p-4 rounded-lg font-mono text-sm">
                    <div class="space-y-2">
                      <div>DISCORD_CLIENT_ID="your_client_id_here"</div>
                      <div>DISCORD_CLIENT_SECRET="your_client_secret_here"</div>
                    </div>
                  </div>
                  <div class="alert alert-warning">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="stroke-current shrink-0 h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                      />
                    </svg>
                    <div>
                      <p>
                        <strong>Security Note:</strong>
                        Never commit secrets to version control. Use your deployment platform's secret management (Fly.io secrets, Heroku config vars, etc.).
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              <!-- Step 5: Test -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">5</span> Test Discord Login
                </h3>
                <div class="ml-8 space-y-3">
                  <p>After deploying with the secrets:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Go to your app's login page</li>
                    <li>Click "Sign in with Discord"</li>
                    <li>Authorize the application on Discord</li>
                    <li>You should be redirected back and logged in</li>
                  </ol>
                </div>
              </div>
            </div>

            <div class="card-actions justify-end mt-6">
              <a
                href="https://discord.com/developers/applications"
                target="_blank"
                class="btn btn-primary"
              >
                Open Discord Developer Portal
                <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                  />
                </svg>
              </a>
            </div>
          </div>
        </div>
        
    <!-- Google OAuth Setup Guide -->
        <div class="card bg-base-100 shadow-xl collapsed" data-card-key="google_oauth">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4 flex items-center gap-3">
              <svg class="w-8 h-8" viewBox="0 0 24 24" fill="currentColor">
                <path
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                  fill="#4285F4"
                />
                <path
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                  fill="#34A853"
                />
                <path
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                  fill="#FBBC05"
                />
                <path
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                  fill="#EA4335"
                />
              </svg>
              Google OAuth Setup Guide
              <button
                type="button"
                data-action="toggle-card"
                data-card-key="google_oauth"
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

            <div class="alert alert-info mb-6">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                class="stroke-current shrink-0 w-6 h-6"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
              <div>
                <p>
                  <strong>Why Google OAuth?</strong>
                  Most widely used OAuth provider. Allows users to sign in with their Google account.
                </p>
              </div>
            </div>

            <div class="space-y-6">
              <!-- Step 1: Create Google Cloud Project -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">1</span> Create Google Cloud Project
                </h3>
                <div class="ml-8 space-y-3">
                  <p>
                    Go to the
                    <a
                      href="https://console.cloud.google.com/"
                      target="_blank"
                      class="link link-primary"
                    >
                      Google Cloud Console
                    </a>
                  </p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Click "Select a project" at the top</li>
                    <li>Click "New Project"</li>
                    <li>Enter a project name (e.g., "Game Server")</li>
                    <li>Click "Create"</li>
                  </ol>
                </div>
              </div>
              
    <!-- Step 2: Enable Google+ API -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">2</span> Enable Google+ API
                </h3>
                <div class="ml-8 space-y-3">
                  <p>In your Google Cloud project:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Go to "APIs & Services" → "Library"</li>
                    <li>Search for "Google+ API"</li>
                    <li>Click on it and click "Enable"</li>
                  </ol>
                </div>
              </div>
              
    <!-- Step 3: Configure OAuth Consent Screen -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">3</span> Configure OAuth Consent Screen
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Go to "APIs & Services" → "OAuth consent screen":</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Select "External" user type</li>
                    <li>Click "Create"</li>
                    <li>Fill in app name (e.g., "Game Server")</li>
                    <li>Add your email as user support email</li>
                    <li>Add authorized domains (e.g., {@config.hostname})</li>
                    <li>Add developer contact email</li>
                    <li>Click "Save and Continue"</li>
                    <li>Add scopes: email, profile</li>
                    <li>Click "Save and Continue"</li>
                    <li>Add test users if needed (optional for development)</li>
                  </ol>
                </div>
              </div>
              
    <!-- Step 4: Create OAuth Credentials -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">4</span> Create OAuth Credentials
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Go to "APIs & Services" → "Credentials":</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Click "Create Credentials" → "OAuth client ID"</li>
                    <li>Select "Web application"</li>
                    <li>Enter a name (e.g., "Game Server Web")</li>
                    <li>
                      Add authorized redirect URIs:<br />
                      <div class="bg-base-200 p-2 rounded mt-2 font-mono text-xs">
                        <div>Development: http://localhost:4000/auth/google/callback</div>
                        <div>Production: https://{@config.hostname}/auth/google/callback</div>
                      </div>
                    </li>
                    <li>Click "Create"</li>
                    <li>Copy the Client ID and Client Secret</li>
                  </ol>
                </div>
              </div>
              
    <!-- Step 5: Configure Environment Variables -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">5</span> Configure Environment Variables
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Set these environment variables:</p>
                  <div class="bg-base-200 p-4 rounded-lg font-mono text-sm">
                    <div class="space-y-2">
                      <div>GOOGLE_CLIENT_ID="your_client_id.apps.googleusercontent.com"</div>
                      <div>GOOGLE_CLIENT_SECRET="your_client_secret"</div>
                    </div>
                  </div>
                  <div class="alert alert-warning mt-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="stroke-current shrink-0 h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                      />
                    </svg>
                    <div>
                      <p>
                        <strong>Security:</strong>
                        Never commit secrets to version control. Use your deployment platform's secret management.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 6: Test -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">6</span> Test Google Login
                </h3>
                <div class="ml-8 space-y-3">
                  <p>After deploying with the secrets:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Go to your app's login page</li>
                    <li>Click "Sign in with Google"</li>
                    <li>Choose your Google account</li>
                    <li>You should be redirected back and logged in</li>
                  </ol>
                </div>
              </div>
            </div>

            <div class="card-actions justify-end mt-6">
              <a
                href="https://console.cloud.google.com/"
                target="_blank"
                class="btn btn-primary"
              >
                Open Google Cloud Console
                <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                  />
                </svg>
              </a>
            </div>
          </div>
        </div>
        
    <!-- Facebook OAuth Setup Guide -->
        <div class="card bg-base-100 shadow-xl collapsed" data-card-key="facebook_oauth">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4 flex items-center gap-3">
              <svg class="w-8 h-8 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
                <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
              </svg>
              Facebook OAuth Setup Guide
              <button
                type="button"
                data-action="toggle-card"
                data-card-key="facebook_oauth"
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

            <div class="alert alert-info mb-6">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                class="stroke-current shrink-0 w-6 h-6"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
              <div>
                <p>
                  <strong>Why Facebook OAuth?</strong>
                  Popular social login option with billions of users worldwide. Easy one-click authentication.
                </p>
              </div>
            </div>

            <div class="space-y-6">
              <!-- Step 1: Create Facebook App -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">1</span> Create Facebook App
                </h3>
                <div class="ml-8 space-y-3">
                  <p>
                    Go to the
                    <a
                      href="https://developers.facebook.com/"
                      target="_blank"
                      class="link link-primary"
                    >
                      Facebook Developers Portal
                    </a>
                  </p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Click "My Apps" in the top right</li>
                    <li>Click "Create App"</li>
                    <li>Select the use case that fits your needs (often "Other" or "Authenticate and request data from users with Facebook Login")</li>
                    <li>Click "Next"</li>
                    <li>Select app type (usually "Business" for most web apps, or "None" if available)</li>
                    <li>Click "Next"</li>
                    <li>Enter app name (e.g., "Game Server")</li>
                    <li>Enter contact email</li>
                    <li>Click "Create App"</li>
                  </ol>
                  <div class="alert alert-info mt-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      class="stroke-current shrink-0 w-6 h-6"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      >
                      </path>
                    </svg>
                    <div>
                      <p>
                        <strong>Note:</strong>
                        Facebook's app creation flow changes frequently. If the options don't match exactly, look for the option related to "Facebook Login" or "Authenticate users".
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 2: Add Facebook Login Product -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">2</span> Add Facebook Login Product
                </h3>
                <div class="ml-8 space-y-3">
                  <p>In your Facebook App dashboard:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Find "Facebook Login" in the product list</li>
                    <li>Click "Set Up"</li>
                    <li>Select "Web" as the platform</li>
                    <li>Enter your site URL (e.g., https://{@config.hostname})</li>
                    <li>Click "Save" and continue</li>
                  </ol>
                </div>
              </div>
              
    <!-- Step 3: Configure OAuth Redirect URIs -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">3</span> Configure OAuth Redirect URIs
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Go to "Facebook Login" → "Settings":</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>
                      Add these Valid OAuth Redirect URIs:<br />
                      <div class="bg-base-200 p-2 rounded mt-2 font-mono text-xs">
                        <div>Development: http://localhost:4000/auth/facebook/callback</div>
                        <div>Production: https://{@config.hostname}/auth/facebook/callback</div>
                      </div>
                    </li>
                    <li>Click "Save Changes"</li>
                  </ol>
                </div>
              </div>
              
    <!-- Step 4: Get App Credentials -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">4</span> Get App Credentials
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Go to "Settings" → "Basic":</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Copy the "App ID" (this is your Client ID)</li>
                    <li>
                      Click "Show" next to "App Secret" and copy it (this is your Client Secret)
                    </li>
                  </ol>
                  <div class="bg-base-200 p-4 rounded-lg mt-4">
                    <div class="font-semibold mb-2">Your Credentials</div>
                    <div class="font-mono text-xs bg-base-300 p-2 rounded space-y-1">
                      <div>App ID: 1234567890123456</div>
                      <div>App Secret: abcdef1234567890abcdef1234567890</div>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 5: Make App Public -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">5</span> Make App Public (Production)
                </h3>
                <div class="ml-8 space-y-3">
                  <p>For production use, switch to live mode:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Complete all required fields in "Settings" → "Basic"</li>
                    <li>Add a Privacy Policy URL</li>
                    <li>Add a Terms of Service URL (optional)</li>
                    <li>Select a category for your app</li>
                    <li>Toggle the switch at the top from "Development" to "Live"</li>
                  </ol>
                  <div class="alert alert-info mt-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      class="stroke-current shrink-0 w-6 h-6"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      >
                      </path>
                    </svg>
                    <div>
                      <p>
                        <strong>Note:</strong>
                        In Development mode, only test users can log in. Switch to Live mode for public access.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 6: Configure Environment Variables -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">6</span> Configure Environment Variables
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Set these environment variables:</p>
                  <div class="bg-base-200 p-4 rounded-lg font-mono text-sm">
                    <div class="space-y-2">
                      <div>FACEBOOK_CLIENT_ID="your_app_id"</div>
                      <div>FACEBOOK_CLIENT_SECRET="your_app_secret"</div>
                    </div>
                  </div>
                  <div class="alert alert-warning mt-3">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="stroke-current shrink-0 h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                      />
                    </svg>
                    <div>
                      <p>
                        <strong>Security:</strong>
                        Never commit the App Secret to version control. Use your deployment platform's secret management.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 7: Test -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">7</span> Test Facebook Login
                </h3>
                <div class="ml-8 space-y-3">
                  <p>After deploying with the secrets:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Go to your app's login page</li>
                    <li>Click "Sign in with Facebook"</li>
                    <li>Authorize the application with your Facebook account</li>
                    <li>You should be redirected back and logged in</li>
                  </ol>
                </div>
              </div>
            </div>

            <div class="card-actions justify-end mt-6">
              <a
                href="https://developers.facebook.com/"
                target="_blank"
                class="btn btn-primary"
              >
                Open Facebook Developers Portal
                <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                  />
                </svg>
              </a>
            </div>
          </div>
        </div>
        
    <!-- Email Configuration -->
        <div class="card bg-base-100 shadow-xl collapsed" data-card-key="email_config">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4 flex items-center gap-3">
              <svg
                class="w-8 h-8 text-green-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                />
              </svg>
              Email Configuration (Optional)
              <button
                type="button"
                data-action="toggle-card"
                data-card-key="email_config"
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

            <div class="alert alert-info mb-6">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                class="stroke-current shrink-0 w-6 h-6"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
              <div>
                <p>
                  <strong>Email is always required for registration.</strong>
                  Configure SMTP settings to enable email delivery.
                </p>
              </div>
            </div>

            <div class="space-y-6">
              <div class="step">
                <h3 class="text-lg font-semibold mb-3">Choose an Email Provider</h3>
                <div class="ml-8 space-y-3">
                  <p>Recommended providers:</p>
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div class="bg-base-200 p-4 rounded-lg text-center">
                      <div class="font-semibold">Resend</div>
                      <div class="text-sm text-base-content/70">3,000 free emails/month</div>
                      <a href="https://resend.com" target="_blank" class="btn btn-sm btn-primary mt-2">
                        Get Started
                      </a>
                    </div>
                    <div class="bg-base-200 p-4 rounded-lg text-center">
                      <div class="font-semibold">SendGrid</div>
                      <div class="text-sm text-base-content/70">100 free emails/day</div>
                      <a
                        href="https://sendgrid.com"
                        target="_blank"
                        class="btn btn-sm btn-primary mt-2"
                      >
                        Get Started
                      </a>
                    </div>
                    <div class="bg-base-200 p-4 rounded-lg text-center">
                      <div class="font-semibold">Mailgun</div>
                      <div class="text-sm text-base-content/70">5,000 free emails/month</div>
                      <a
                        href="https://mailgun.com"
                        target="_blank"
                        class="btn btn-sm btn-primary mt-2"
                      >
                        Get Started
                      </a>
                    </div>
                  </div>
                </div>
              </div>

              <div class="step">
                <h3 class="text-lg font-semibold mb-3">Configure Email Secrets</h3>
                <div class="ml-8 space-y-3">
                  <p>Set these environment variables based on your provider:</p>
                  <div class="bg-base-200 p-4 rounded-lg font-mono text-sm">
                    <div class="space-y-2">
                      <div># For Resend:</div>
                      <div>SMTP_USERNAME="resend"</div>
                      <div>SMTP_PASSWORD="your_resend_api_key"</div>
                      <div>SMTP_RELAY="smtp.resend.com"</div>
                    </div>
                  </div>
                  <p class="text-sm text-base-content/70 mt-2">
                    For other providers, adjust the SMTP settings accordingly. The app will automatically detect when email is configured.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Sentry Error Monitoring Setup -->
        <div class="card bg-base-100 shadow-xl collapsed" data-card-key="sentry_setup">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4 flex items-center gap-3">
              <svg class="w-8 h-8 text-red-600" fill="currentColor" viewBox="0 0 24 24">
                <path d="M13.632 2.286c.176.08.293.245.293.438v1.34c1.725.447 3.013 1.816 3.013 3.482 0 1.946-1.58 3.527-3.526 3.527-.948 0-1.814-.386-2.446-1.01-.632.624-1.498 1.01-2.446 1.01C6.58 11.073 5 9.492 5 7.546c0-1.666 1.288-3.035 3.013-3.482V2.724c0-.193.117-.358.293-.438L9.6 1.2c.176-.08.39-.08.566 0l1.466.666z" />
                <path d="M12 14.5c-1.38 0-2.5 1.12-2.5 2.5v7c0 1.38 1.12 2.5 2.5 2.5s2.5-1.12 2.5-2.5v-7c0-1.38-1.12-2.5-2.5-2.5z" />
              </svg>
              Sentry Error Monitoring Setup
              <button
                type="button"
                data-action="toggle-card"
                data-card-key="sentry_setup"
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

            <div class="alert alert-info mb-6">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                class="stroke-current shrink-0 w-6 h-6"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
              <div>
                <p>
                  <strong>Why Sentry?</strong>
                  Automatically captures and reports errors, exceptions, and performance issues in production. Get notified about crashes and monitor application health.
                </p>
              </div>
            </div>

            <div class="space-y-6">
              <!-- Step 1: Create Sentry Project -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">1</span> Create Sentry Project
                </h3>
                <div class="ml-8 space-y-3">
                  <p>
                    Go to the
                    <a
                      href="https://sentry.io"
                      target="_blank"
                      class="link link-primary"
                    >
                      Sentry Dashboard
                    </a>
                  </p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Sign up or log in to Sentry</li>
                    <li>Create a new project</li>
                    <li>Select "Phoenix" or "Elixir" as the platform</li>
                    <li>Name your project (e.g., "Game Server")</li>
                  </ol>
                </div>
              </div>
              
    <!-- Step 2: Get DSN -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">2</span> Get Your DSN
                </h3>
                <div class="ml-8 space-y-3">
                  <p>After creating the project, copy the DSN from the settings:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Go to Project Settings → Client Keys (DSN)</li>
                    <li>Copy the DSN value</li>
                  </ol>
                  <div class="bg-base-200 p-4 rounded-lg">
                    <div class="font-semibold mb-2">DSN Format</div>
                    <div class="font-mono text-xs bg-base-300 p-2 rounded">
                      https://your-dsn@sentry.io/project-id
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 3: Configure Environment Variable -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">3</span> Set Environment Variable
                </h3>
                <div class="ml-8 space-y-3">
                  <p>Set the SENTRY_DSN environment variable:</p>
                  <div class="bg-base-200 p-4 rounded-lg font-mono text-sm">
                    <div class="space-y-2">
                      <div>SENTRY_DSN="https://your-dsn@sentry.io/project-id"</div>
                    </div>
                  </div>
                  <div class="alert alert-warning">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="stroke-current shrink-0 h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                      />
                    </svg>
                    <div>
                      <p>
                        <strong>Security Note:</strong>
                        Never commit the DSN to version control. Use your deployment platform's secret management (Fly.io secrets, etc.).
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Step 4: Deploy and Test -->
              <div class="step">
                <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
                  <span class="badge badge-primary">4</span> Deploy and Test
                </h3>
                <div class="ml-8 space-y-3">
                  <p>After deploying with the DSN:</p>
                  <ol class="list-decimal list-inside space-y-2 text-sm">
                    <li>Deploy your application</li>
                    <li>Check the admin config page - Sentry should show as "Configured"</li>
                    <li>Test error reporting by running: <code>mix sentry.send_test_event</code></li>
                    <li>Check your Sentry dashboard for the test event</li>
                  </ol>
                  <div class="alert alert-info">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      class="stroke-current shrink-0 w-6 h-6"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      >
                      </path>
                    </svg>
                    <div>
                      <p>
                        <strong>Note:</strong>
                        Sentry only reports errors in production. Development and test environments are disabled by default.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="card-actions justify-end mt-6">
              <a
                href="https://sentry.io"
                target="_blank"
                class="btn btn-primary"
              >
                Open Sentry Dashboard
                <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                  />
                </svg>
              </a>
            </div>
          </div>
        </div>
        
    <!-- PostgreSQL Configuration -->
        <div class="card bg-base-100 shadow-xl collapsed" data-card-key="postgres_config">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4 flex items-center gap-3">
              <svg
                class="w-8 h-8 text-blue-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"
                />
              </svg>
              PostgreSQL Configuration (Alternative to SQLite)
              <button
                type="button"
                data-action="toggle-card"
                data-card-key="postgres_config"
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

            <div class="alert alert-info mb-6">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                class="stroke-current shrink-0 w-6 h-6"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
              <div>
                <p>
                  <strong>Why PostgreSQL?</strong>
                  Better for production deployments, concurrent access, and advanced features. SQLite is used by default for simplicity.
                </p>
              </div>
            </div>

            <div class="space-y-6">
              <div class="step">
                <h3 class="text-lg font-semibold mb-3">Database URL Configuration</h3>
                <div class="ml-8 space-y-3">
                  <p>Set the DATABASE_URL environment variable:</p>
                  <div class="bg-base-200 p-4 rounded-lg font-mono text-sm">
                    <div class="space-y-2">
                      <div>DATABASE_URL="postgresql://username:password@host:port/database"</div>
                      <div># Example:</div>
                      <div>
                        DATABASE_URL="postgresql://myuser:mypass@localhost:5432/game_server_prod"
                      </div>
                    </div>
                  </div>
                  <p class="text-sm text-base-content/70">
                    The app will automatically detect PostgreSQL when DATABASE_URL is set and contains "postgresql://".
                  </p>
                </div>
              </div>

              <div class="step">
                <h3 class="text-lg font-semibold mb-3">
                  Individual Environment Variables (Alternative)
                </h3>
                <div class="ml-8 space-y-3">
                  <p>You can also set individual database connection variables:</p>
                  <div class="bg-base-200 p-4 rounded-lg font-mono text-sm">
                    <div class="space-y-2">
                      <div>DB_HOST="your-postgres-host"</div>
                      <div>DB_PORT="5432"</div>
                      <div>DB_NAME="your-database-name"</div>
                      <div>DB_USER="your-username"</div>
                      <div>DB_PASS="your-password"</div>
                      <div>DB_SSL="true"  # or "false"</div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="step">
                <h3 class="text-lg font-semibold mb-3">Deployment Considerations</h3>
                <div class="ml-8 space-y-3">
                  <div class="alert alert-warning">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="stroke-current shrink-0 h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                      />
                    </svg>
                    <div>
                      <p>
                        <strong>Important:</strong>
                        When switching from SQLite to PostgreSQL, you'll need to migrate your data or start fresh.
                        The database schema is compatible between both adapters.
                      </p>
                    </div>
                  </div>
                  <p class="text-sm">
                    Popular PostgreSQL hosting options:
                  </p>
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-3">
                    <div class="bg-base-200 p-4 rounded-lg text-center">
                      <div class="font-semibold">Supabase</div>
                      <div class="text-sm text-base-content/70">Free tier available</div>
                      <a
                        href="https://supabase.com"
                        target="_blank"
                        class="btn btn-sm btn-primary mt-2"
                      >
                        Get Started
                      </a>
                    </div>
                    <div class="bg-base-200 p-4 rounded-lg text-center">
                      <div class="font-semibold">Neon</div>
                      <div class="text-sm text-base-content/70">Serverless PostgreSQL</div>
                      <a href="https://neon.tech" target="_blank" class="btn btn-sm btn-primary mt-2">
                        Get Started
                      </a>
                    </div>
                    <div class="bg-base-200 p-4 rounded-lg text-center">
                      <div class="font-semibold">Fly.io Postgres</div>
                      <div class="text-sm text-base-content/70">Managed PostgreSQL</div>
                      <a
                        href="https://fly.io/docs/postgres/"
                        target="_blank"
                        class="btn btn-sm btn-primary mt-2"
                      >
                        Learn More
                      </a>
                    </div>
                  </div>
                </div>
              </div>
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
        Application.get_env(:ueberauth, Ueberauth.Strategy.Discord.OAuth)[:client_id],
      discord_client_secret:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Discord.OAuth)[:client_secret],
      apple_client_id: System.get_env("APPLE_CLIENT_ID"),
      apple_team_id: System.get_env("APPLE_TEAM_ID"),
      apple_key_id: System.get_env("APPLE_KEY_ID"),
      apple_private_key: System.get_env("APPLE_PRIVATE_KEY"),
      google_client_id:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id],
      google_client_secret:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret],
      facebook_client_id:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Facebook.OAuth)[:client_id],
      facebook_client_secret:
        Application.get_env(:ueberauth, Ueberauth.Strategy.Facebook.OAuth)[:client_secret],
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
