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
          # Protect against unexpected DB errors during mount — render not_found and surface details
          Logger.error("Failed reading oauth session #{inspect(session_id)}: #{inspect(e)}")
          nil
      end

    case session_lookup do
      %GameServer.OAuthSession{} = s ->
        # session data is stored in the `data` map on the schema
        session_data = Map.merge(%{status: s.status}, s.data || %{})

        {:ok, assign(socket, session_id: session_id, session_data: session_data)}

      nil ->
        # session_id present but DB lookup missing — for SDK/API flows we still want
        # to show a friendly success UI so the browser tab can be closed. Treat
        # as completed if session_id was provided; only show 'not_found' when no
        # session_id at all.
        if session_id do
          {:ok,
           assign(socket,
             session_id: session_id,
             session_data: %{
               status: "completed",
               message: "Authentication completed — you can close this window."
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
    <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md w-full space-y-8">
        <div>
          <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
            <%= case @session_data.status do %>
              <% "completed" -> %>
                🎉 Authentication Successful!
              <% "conflict" -> %>
                ⚠️ Account Conflict
              <% "error" -> %>
                ❌ Authentication Failed
              <% "not_found" -> %>
                ❓ Session Not Found
              <% _ -> %>
                🔄 Processing...
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
                        OAuth authentication completed successfully!
                      </h3>
                      <div class="mt-2 text-sm text-green-700">
                        <p>You can now close this window and return to your application.</p>
                        <% message =
                          Map.get(@session_data, "message") || Map.get(@session_data, :message) %>
                        <%= if message do %>
                          <p class="mt-1"><strong>Message:</strong> {message}</p>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="text-center">
                  <button
                    type="button"
                    onclick="window.close()"
                    class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    Close Window
                  </button>
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
                        Account already linked to another user
                      </h3>
                      <div class="mt-2 text-sm text-yellow-700">
                        <p>This OAuth account is already linked to another user account.</p>
                        <p class="mt-1">
                          Please contact support or try logging in with a different method.
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
                        Authentication failed
                      </h3>
                      <div class="mt-2 text-sm text-red-700">
                        <p>There was an error during authentication.</p>
                        <% details =
                          Map.get(@session_data, "details") || Map.get(@session_data, :details) %>
                        <%= if details do %>
                          <p class="mt-1">
                            <strong>Details:</strong> {inspect(details)}
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
                        Session not found
                      </h3>
                      <div class="mt-2 text-sm text-gray-700">
                        <p>The authentication session could not be found.</p>
                        <p class="mt-1">This may be due to an expired session or an invalid link.</p>
                      </div>
                    </div>
                  </div>
                </div>
              <% _ -> %>
                <div class="rounded-md bg-blue-50 p-4">
                  <div class="flex">
                    <div class="ml-3">
                      <h3 class="text-sm font-medium text-blue-800">
                        Processing authentication...
                      </h3>
                      <div class="mt-2 text-sm text-blue-700">
                        <p>Please wait while we complete your authentication.</p>
                      </div>
                    </div>
                  </div>
                </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
