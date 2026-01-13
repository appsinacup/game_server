defmodule GameServerWeb.AuthSuccessLive do
  use GameServerWeb, :live_view
  require Logger

  @impl true
  def mount(params, _session, socket) do
    # Support mounting with or without a session_id query param.
    # Read the OAuth session from the DB-backed store (GameServer.OAuthSessions)
    session_id = params["session_id"]

    session_lookup =
      try do
        session_id && GameServer.OAuthSessions.get_session(session_id)
      rescue
        e ->
          # Protect against unexpected DB errors during mount - render not_found and surface details
          Logger.error("Failed reading oauth session #{inspect(session_id)}: #{inspect(e)}")
          nil
      end

    case session_lookup do
      %GameServer.OAuthSession{} = s ->
        # session data is stored in the `data` map on the schema
        session_data = Map.merge(%{status: s.status}, s.data || %{})

        {:ok, assign(socket, session_id: session_id, session_data: session_data)}

      nil ->
        # session_id present but DB lookup missing - for SDK/API flows we still want
        # to show a friendly success UI so the browser tab can be closed. Treat
        # as completed if session_id was provided; only show 'not_found' when no
        # session_id at all.
        if session_id do
          {:ok,
           assign(socket,
             session_id: session_id,
             session_data: %{
               status: "completed",
               message: gettext("Authentication completed - you can close this window.")
             }
           )}
        else
          {:ok, assign(socket, session_id: session_id, session_data: %{status: "not_found"})}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
        <div class="max-w-md w-full">
          <div class="rounded-box bg-base-100 border border-base-200 p-8 shadow-md space-y-8">
            <div>
              <h2 class="mt-6 text-center text-3xl font-extrabold">
                <%= case @session_data.status do %>
                  <% "completed" -> %>
                    {"🎉 " <> gettext("Authentication Successful!")}
                  <% "conflict" -> %>
                    {"⚠️ " <> gettext("Account Conflict")}
                  <% "error" -> %>
                    {"❌ " <> gettext("Authentication Failed")}
                  <% "not_found" -> %>
                    {"❓ " <> gettext("Session Not Found")}
                  <% _ -> %>
                    {"🔄 " <> gettext("Processing...")}
                <% end %>
              </h2>

              <div class="mt-8 space-y-6">
                <%= case @session_data.status do %>
                  <% "completed" -> %>
                    <div class="rounded-md bg-green-50 p-4">
                      <div class="flex">
                        <div class="flex-shrink-0">
                          <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                            <path
                              fill-rule="evenodd"
                              d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                              clip-rule="evenodd"
                            />
                          </svg>
                        </div>
                        <div class="ml-3">
                          <h3 class="text-sm font-medium text-green-800">
                            {gettext("OAuth authentication completed successfully!")}
                          </h3>
                          <div class="mt-2 text-sm text-green-700">
                            <p>
                              {gettext(
                                "You can now close this window and return to your application."
                              )}
                            </p>
                            <p
                              id="auto-close"
                              phx-hook="AutoClose"
                              phx-update="ignore"
                              class="mt-1 text-xs text-green-600"
                            >
                              {gettext("This window will close in 3s...")}
                            </p>
                            <% message =
                              Map.get(@session_data, "message") || Map.get(@session_data, :message) %>
                            <%= if message do %>
                              <p class="mt-1"><strong>{gettext("Message:")}</strong> {message}</p>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% "conflict" -> %>
                    <div class="rounded-md bg-yellow-50 p-4">
                      <div class="flex">
                        <div class="flex-shrink-0">
                          <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                            <path
                              fill-rule="evenodd"
                              d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                              clip-rule="evenodd"
                            />
                          </svg>
                        </div>
                        <div class="ml-3">
                          <h3 class="text-sm font-medium text-yellow-800">
                            {gettext("Account already linked to another user")}
                          </h3>
                          <div class="mt-2 text-sm text-yellow-700">
                            <p>
                              {gettext(
                                "This OAuth account is already linked to another user account."
                              )}
                            </p>
                            <p class="mt-1">
                              {gettext(
                                "Please contact support or try logging in with a different method."
                              )}
                            </p>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% "error" -> %>
                    <div class="rounded-md bg-red-50 p-4">
                      <div class="flex">
                        <div class="flex-shrink-0">
                          <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                            <path
                              fill-rule="evenodd"
                              d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                              clip-rule="evenodd"
                            />
                          </svg>
                        </div>
                        <div class="ml-3">
                          <h3 class="text-sm font-medium text-red-800">
                            {gettext("Authentication failed")}
                          </h3>
                          <div class="mt-2 text-sm text-red-700">
                            <p>{gettext("There was an error during authentication.")}</p>
                            <% details =
                              Map.get(@session_data, "details") || Map.get(@session_data, :details) %>
                            <%= if details do %>
                              <p class="mt-1">
                                <strong>{gettext("Details:")}</strong> {inspect(details)}
                              </p>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% "not_found" -> %>
                    <div class="rounded-md bg-gray-50 p-4">
                      <div class="flex">
                        <div class="flex-shrink-0">
                          <svg class="h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor">
                            <path
                              fill-rule="evenodd"
                              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
                              clip-rule="evenodd"
                            />
                          </svg>
                        </div>
                        <div class="ml-3">
                          <h3 class="text-sm font-medium text-gray-800">
                            {gettext("Session not found")}
                          </h3>
                          <div class="mt-2 text-sm text-gray-700">
                            <p>{gettext("The authentication session could not be found.")}</p>
                            <p class="mt-1">
                              {gettext("This may be due to an expired session or an invalid link.")}
                            </p>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% _ -> %>
                    <div class="rounded-md bg-blue-50 p-4">
                      <div class="flex">
                        <div class="ml-3">
                          <h3 class="text-sm font-medium text-blue-800">
                            {gettext("Processing authentication...")}
                          </h3>
                          <div class="mt-2 text-sm text-blue-700">
                            <p>{gettext("Please wait while we complete your authentication.")}</p>
                          </div>
                        </div>
                      </div>
                    </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
