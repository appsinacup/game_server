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
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-xl mb-4">Current Configuration Status</h2>
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
                        SMTP configured - emails are sent<br />
                      <% else %>
                        Using local mailbox - emails stored locally
                      <% end %>
                      <br />
                      <a href="/admin/mailbox" class="link link-primary">view mailbox</a>
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
        
    <!-- Discord OAuth Setup Guide -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4 flex items-center gap-3">
              <svg class="w-8 h-8 text-indigo-600" fill="currentColor" viewBox="0 0 24 24">
                <path d="M20.317 4.492c-1.53-.69-3.17-1.2-4.885-1.49a.075.075 0 0 0-.079.036c-.21.369-.444.85-.608 1.23a18.566 18.566 0 0 0-5.487 0 12.36 12.36 0 0 0-.617-1.23A.077.077 0 0 0 8.562 3c-1.714.29-3.354.8-4.885 1.491a.07.07 0 0 0-.032.027C.533 9.093-.32 13.555.099 17.961a.08.08 0 0 0 .031.055 20.03 20.03 0 0 0 5.993 2.98.078.078 0 0 0 .084-.026 13.83 13.83 0 0 0 1.226-1.963.074.074 0 0 0-.041-.104 13.201 13.201 0 0 1-1.872-.878.075.075 0 0 1-.008-.125c.126-.093.252-.19.372-.287a.075.075 0 0 1 .078-.01c3.927 1.764 8.18 1.764 12.061 0a.075.075 0 0 1 .079.009c.12.098.245.195.372.288a.075.075 0 0 1-.006.125c-.598.344-1.22.635-1.873.877a.075.075 0 0 0-.041.105c.36.687.772 1.341 1.225 1.962a.077.077 0 0 0 .084.028 19.963 19.963 0 0 0 6.002-2.981.076.076 0 0 0 .032-.054c.5-5.094-.838-9.52-3.549-13.442a.06.06 0 0 0-.031-.028zM8.02 15.278c-1.182 0-2.157-1.069-2.157-2.38 0-1.312.956-2.38 2.157-2.38 1.21 0 2.176 1.077 2.157 2.38 0 1.312-.956 2.38-2.157 2.38zm7.975 0c-1.183 0-2.157-1.069-2.157-2.38 0-1.312.955-2.38 2.157-2.38 1.21 0 2.176 1.077 2.157 2.38 0 1.312-.946 2.38-2.157 2.38z" />
              </svg>
              Discord OAuth Setup Guide
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
        
    <!-- Email Configuration -->
        <div class="card bg-base-100 shadow-xl">
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
                  Admins can view all emails (sent or stored locally) at <code>/admin/mailbox</code>.
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
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4 flex items-center gap-3">
              <svg class="w-8 h-8 text-red-600" fill="currentColor" viewBox="0 0 24 24">
                <path d="M13.632 2.286c.176.08.293.245.293.438v1.34c1.725.447 3.013 1.816 3.013 3.482 0 1.946-1.58 3.527-3.526 3.527-.948 0-1.814-.386-2.446-1.01-.632.624-1.498 1.01-2.446 1.01C6.58 11.073 5 9.492 5 7.546c0-1.666 1.288-3.035 3.013-3.482V2.724c0-.193.117-.358.293-.438L9.6 1.2c.176-.08.39-.08.566 0l1.466.666z" />
                <path d="M12 14.5c-1.38 0-2.5 1.12-2.5 2.5v7c0 1.38 1.12 2.5 2.5 2.5s2.5-1.12 2.5-2.5v-7c0-1.38-1.12-2.5-2.5-2.5z" />
              </svg>
              Sentry Error Monitoring Setup
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
        <div class="card bg-base-100 shadow-xl">
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
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-xl mb-4">Admin Tools</h2>
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
              <a href="/admin/mailbox" class="btn btn-outline btn-secondary">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                  />
                </svg>
                Mailbox
              </a>
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
