defmodule GameServerWeb.UserLive.Settings do
  use GameServerWeb, :live_view

  alias GameServer.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your account email address and password settings</:subtitle>
        </.header>

        <%= if @conflict_user do %>
          <div class="divider" />

          <div class="card bg-warning/10 border-warning p-4 rounded-lg">
            <div class="flex items-start justify-between">
              <div>
                <strong>Conflict detected</strong>
                <div class="text-sm text-base-content/70">
                  The {@conflict_provider} account (ID: {@conflict_user.id}) is already linked to another account.
                  If this is another account you own (matching email), you may delete it below to free the provider so you can link it to this account.
                </div>
              </div>
              <div class="flex items-center gap-2">
                <button
                  phx-click="delete_conflicting_account"
                  phx-value-id={@conflict_user.id}
                  class="btn btn-error btn-sm"
                  onclick="return confirm('Delete the conflicting account? This is irreversible.')"
                >
                  Delete account
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <div class="mt-6 grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="card bg-base-200 p-4 rounded-lg">
          <div class="font-semibold">Account details</div>
          <div class="text-sm mt-2 space-y-1 text-base-content/80">
            <div><strong>ID:</strong> {@user.id}</div>
            <div><strong>Email:</strong> {@current_email}</div>
            <div><strong>Admin:</strong> {@user.is_admin}</div>
          </div>
        </div>

        <div class="card bg-base-200 p-4 rounded-lg">
          <div class="font-semibold">Metadata</div>
          <div class="text-sm mt-2 font-mono text-xs bg-base-300 p-3 rounded-lg overflow-auto text-base-content/80">
            <pre phx-no-curly-interpolation><%= Jason.encode!(@user.metadata || %{}, pretty: true) %></pre>
          </div>
        </div>
      </div>

      <div class="divider" />

      <div class="card bg-base-200 p-4 rounded-lg">
        <div class="font-semibold">Linked Accounts</div>
        <div class="mt-2 space-y-2">
          <% provider_count =
            Enum.count([@user.discord_id, @user.apple_id, @user.google_id, @user.facebook_id], fn v ->
              v && v != ""
            end) %>
          <div class="flex items-center justify-between">
            <div>
              <strong>Discord</strong>
              <div class="text-sm text-base-content/70">
                Sign in with Discord and link to your account
              </div>
            </div>
            <div class="flex items-center gap-2">
              <%= if @user.discord_id do %>
                <%= if provider_count > 1 do %>
                  <button
                    phx-click="unlink_provider"
                    phx-value-provider="discord"
                    class="btn btn-outline btn-sm"
                  >
                    Unlink
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>Unlink</button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/discord"} class="btn btn-primary btn-sm">Link</.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>Google</strong>
              <div class="text-sm text-base-content/70">
                Sign in with Google and link to your account
              </div>
            </div>
            <div class="flex items-center gap-2">
              <%= if @user.google_id do %>
                <%= if provider_count > 1 do %>
                  <button
                    phx-click="unlink_provider"
                    phx-value-provider="google"
                    class="btn btn-outline btn-sm"
                  >
                    Unlink
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>Unlink</button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/google"} class="btn btn-primary btn-sm">Link</.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>Facebook</strong>
              <div class="text-sm text-base-content/70">
                Sign in with Facebook and link to your account
              </div>
            </div>
            <div class="flex items-center gap-2">
              <%= if @user.facebook_id do %>
                <%= if provider_count > 1 do %>
                  <button
                    phx-click="unlink_provider"
                    phx-value-provider="facebook"
                    class="btn btn-outline btn-sm"
                  >
                    Unlink
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>Unlink</button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/facebook"} class="btn btn-primary btn-sm">Link</.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>Apple</strong>
              <div class="text-sm text-base-content/70">
                Sign in with Apple and link to your account
              </div>
            </div>
            <div class="flex items-center gap-2">
              <%= if @user.apple_id do %>
                <%= if provider_count > 1 do %>
                  <button
                    phx-click="unlink_provider"
                    phx-value-provider="apple"
                    class="btn btn-outline btn-sm"
                  >
                    Unlink
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>Unlink</button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/apple"} class="btn btn-primary btn-sm">Link</.link>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/users/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_user_email"
          autocomplete="username"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="New password"
          autocomplete="new-password"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Save Password
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:user, user)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:conflict_user, nil)
      |> assign(:conflict_provider, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  @impl true
  def handle_event("unlink_provider", %{"provider" => provider}, socket) do
    user = socket.assigns.current_scope.user

    provider_atom = String.to_existing_atom(provider)

    case Accounts.unlink_provider(user, provider_atom) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully unlinked #{String.capitalize(provider)}.")
         |> assign(:user, user)}

      {:error, :last_provider} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Cannot unlink the last linked social provider (you must have at least one social login connected)."
         )}

      {:error, _} ->
        {:noreply, socket |> put_flash(:error, "Failed to unlink provider.")}
    end
  end

  ## handle_params is implemented after event handlers to keep handle_event/3
  ## clauses grouped together (avoid compile warnings about grouping clauses).

  @impl true
  def handle_event("delete_conflicting_account", %{"id" => id}, socket) do
    current = socket.assigns.current_scope.user

    case GameServer.Repo.get(GameServer.Accounts.User, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Account not found.")}

      %GameServer.Accounts.User{} = other_user ->
        # Only allow deleting if the email matches the current user's email
        current_email = (current.email || "") |> String.downcase()
        other_email = (other_user.email || "") |> String.downcase()

        cond do
          other_user.id == current.id ->
            {:noreply,
             put_flash(socket, :error, "You cannot delete your currently logged-in account here.")}

          # Allow deletion if the other account has no password (i.e. likely a provider-only account)
          other_email == current_email and other_email != "" ->
            case Accounts.delete_user(other_user) do
              {:ok, _} ->
                {:noreply,
                 socket
                 |> put_flash(
                   :info,
                   "Conflicting account deleted. You can now try linking the provider again."
                 )
                 |> assign(:conflict_user, nil)}

              {:error, _} ->
                {:noreply, put_flash(socket, :error, "Failed to delete the conflicting account.")}
            end

          other_user.hashed_password == nil ->
            case Accounts.delete_user(other_user) do
              {:ok, _} ->
                {:noreply,
                 socket
                 |> put_flash(
                   :info,
                   "Conflicting account deleted. You can now try linking the provider again."
                 )
                 |> assign(:conflict_user, nil)}

              {:error, _} ->
                {:noreply, put_flash(socket, :error, "Failed to delete the conflicting account.")}
            end

          true ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Cannot delete an account you do not own. Log in to the other account directly if you control it."
             )}
        end
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    conflict_user =
      case params do
        %{"conflict_user_id" => id} when is_binary(id) ->
          case GameServer.Repo.get(GameServer.Accounts.User, id) do
            %GameServer.Accounts.User{} = u -> u
            _ -> nil
          end

        _ ->
          nil
      end

    conflict_provider = Map.get(params, "conflict_provider")

    {:noreply, assign(socket, conflict_user: conflict_user, conflict_provider: conflict_provider)}
  end
end
