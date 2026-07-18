defmodule GameServerWeb.UserLive.Settings.AccountTab do
  @moduledoc """
  Account tab of the user settings page: template, events, and helpers for
  email/password/display-name management, provider linking, and account
  deletion.
  """

  use GameServerWeb, :html
  import Phoenix.LiveView

  alias GameServer.Accounts
  alias GameServerWeb.UserLive.Settings.Shared

  def assign_defaults(socket, user) do
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket
    |> assign(:current_email, user.email)
    |> assign(:email_form, to_form(email_changeset))
    |> assign(:display_form, to_form(Accounts.change_user_display_name(user)))
    |> assign(:username_form, to_form(Accounts.change_username(user)))
    |> assign(:password_form, to_form(password_changeset))
    |> assign(:trigger_submit, false)
  end

  def tab(assigns) do
    ~H"""
    <%!-- Account tab --%>
    <div :if={@settings_tab == "account"}>
      <div class="mt-6 grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="card bg-base-200 p-4 rounded-lg">
          <div class="font-semibold">{gettext("Account")}</div>
          <div class="text-sm mt-2 space-y-1 text-base-content/80">
            <div><strong>{gettext("ID")}:</strong> {@user.id}</div>
            <div><strong>{gettext("Email")}:</strong> {@current_email}</div>

            <.form
              for={@username_form}
              id="username_form"
              phx-change="validate_username"
              phx-submit="update_username"
            >
              <.input
                field={@username_form[:username]}
                type="text"
                label={gettext("Username")}
                required
              />
              <.button variant="primary" phx-disable-with={gettext("Saving...")}>
                {gettext("Save")}
              </.button>
            </.form>

            <.form
              for={@display_form}
              id="display_form"
              phx-change="validate_display_name"
              phx-submit="update_display_name"
            >
              <.input
                field={@display_form[:display_name]}
                type="text"
                label={gettext("Name")}
                required
              />
              <.button variant="primary" phx-disable-with={gettext("Saving...")}>
                {gettext("Save")}
              </.button>
            </.form>

            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
            >
              <.input
                field={@email_form[:email]}
                type="email"
                label={gettext("Email")}
                autocomplete="username"
                required
              />
              <.button variant="primary" phx-disable-with={gettext("Loading...")}>
                {gettext("Save")}
              </.button>
            </.form>
          </div>
        </div>

        <div class="card bg-base-200 p-4 rounded-lg">
          <div class="font-semibold">{gettext("Password")}</div>

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
              label={gettext("Password")}
              autocomplete="new-password"
              required
            />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label={gettext("Confirm")}
              autocomplete="new-password"
            />
            <.button variant="primary" phx-disable-with={gettext("Saving...")}>
              {gettext("Save")}
            </.button>
          </.form>
        </div>
      </div>

      <div class="card bg-base-200 p-4 rounded-lg mt-6">
        <div class="font-semibold">{gettext("Account")}</div>
        <div class="mt-2 grid grid-cols-1 md:grid-cols-2 gap-4">
          <% provider_count =
            Enum.count(
              [
                @user.discord_id,
                @user.apple_id,
                @user.google_id,
                @user.facebook_id,
                @user.steam_id
              ],
              fn v ->
                v && v != ""
              end
            ) %>

          <div class="flex items-center justify-between">
            <div>
              <strong>{"Discord"}</strong>
              <div class="text-sm text-base-content/70">
                {gettext("Log in")}
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
                    {gettext("Remove")}
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>
                    {gettext("Remove")}
                  </button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/discord"} class="btn btn-primary btn-sm">
                  {gettext("Link")}
                </.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>{"Google"}</strong>
              <div class="text-sm text-base-content/70">
                {gettext("Log in")}
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
                    {gettext("Remove")}
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>
                    {gettext("Remove")}
                  </button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/google"} class="btn btn-primary btn-sm">
                  {gettext("Link")}
                </.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>{"Facebook"}</strong>
              <div class="text-sm text-base-content/70">
                {gettext("Log in")}
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
                    {gettext("Remove")}
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>
                    {gettext("Remove")}
                  </button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/facebook"} class="btn btn-primary btn-sm">
                  {gettext("Link")}
                </.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>Apple</strong>
              <div class="text-sm text-base-content/70">
                {gettext("Log in")}
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
                    {gettext("Remove")}
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>
                    {gettext("Remove")}
                  </button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/apple"} class="btn btn-primary btn-sm">
                  {gettext("Link")}
                </.link>
              <% end %>
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <strong>{"Steam"}</strong>
              <div class="text-sm text-base-content/70">
                {gettext("Log in")}
              </div>
            </div>
            <div class="flex items-center gap-2">
              <%= if @user.steam_id do %>
                <%= if provider_count > 1 do %>
                  <button
                    phx-click="unlink_provider"
                    phx-value-provider="steam"
                    class="btn btn-outline btn-sm"
                  >
                    {gettext("Remove")}
                  </button>
                <% else %>
                  <button class="btn btn-disabled btn-sm" disabled aria-disabled>
                    {gettext("Remove")}
                  </button>
                <% end %>
              <% else %>
                <.link href={~p"/auth/steam"} class="btn btn-primary btn-sm">
                  {gettext("Link")}
                </.link>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <div class="card bg-base-200 p-4 rounded-lg mt-6">
        <div class="font-semibold">{gettext("Metadata")}</div>
        <div class="text-sm mt-2 font-mono text-xs bg-base-300 p-3 rounded-lg overflow-auto text-base-content/80">
          <pre phx-no-curly-interpolation><%= Jason.encode!(@user.metadata || %{}, pretty: true) %></pre>
        </div>
      </div>

      <div class="card bg-error/10 border-error p-4 rounded-lg mt-6">
        <div class="font-semibold text-error">{gettext("Danger zone")}</div>
        <div class="text-sm mt-2 text-base-content/80">
          <.link
            href={~p"/data-deletion"}
            class="link link-primary"
          >
            {gettext("Read data deletion instructions")}
          </.link>
        </div>
        <div class="mt-4">
          <button
            phx-click="delete_user"
            class="btn btn-error"
            data-confirm={gettext("Delete?")}
          >
            {gettext("Delete account")}
          </button>
        </div>
      </div>
    </div>

    <%!-- Friends tab --%>
    """
  end

  def handle_event("validate_email", %{"user" => user_params}, socket) do
    user = Shared.current_user(socket)

    email_form =
      user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", %{"user" => user_params}, socket) do
    user = Shared.current_user(socket)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        {:noreply, put_flash(socket, :info, gettext("Success."))}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_display_name", %{"user" => user_params}, socket) do
    user = Shared.current_user(socket)

    display_form =
      user
      |> Accounts.change_user_display_name(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, display_form: display_form)}
  end

  def handle_event("update_display_name", %{"user" => user_params}, socket) do
    user = Shared.current_user(socket)

    case Accounts.update_user_display_name(user, user_params) do
      {:ok, updated_user} ->
        updated_scope = %{socket.assigns.current_scope | user: updated_user}

        {:noreply,
         socket
         |> put_flash(:info, gettext("Success."))
         |> assign(:user, updated_user)
         |> assign(:current_scope, updated_scope)}

      {:error, changeset} ->
        {:noreply, assign(socket, display_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_username", %{"user" => user_params}, socket) do
    user = Shared.current_user(socket)

    username_form =
      user
      |> Accounts.change_username(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, username_form: username_form)}
  end

  def handle_event("update_username", %{"user" => user_params}, socket) do
    user = Shared.current_user(socket)

    case Accounts.update_username(user, user_params) do
      {:ok, updated_user} ->
        updated_scope = %{socket.assigns.current_scope | user: updated_user}

        {:noreply,
         socket
         |> put_flash(:info, gettext("Success."))
         |> assign(:user, updated_user)
         |> assign(:current_scope, updated_scope)
         |> assign(:username_form, to_form(Accounts.change_username(updated_user)))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, username_form: to_form(changeset, action: :insert))}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, gettext("Not allowed: %{reason}", reason: inspect(reason)))}
    end
  end

  def handle_event("validate_password", %{"user" => user_params}, socket) do
    user = Shared.current_user(socket)

    password_form =
      user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", %{"user" => user_params}, socket) do
    user = Shared.current_user(socket)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("unlink_provider", %{"provider" => provider}, socket) do
    user = Shared.current_user(socket)
    provider_atom = String.to_existing_atom(provider)

    case Accounts.unlink_provider(user, provider_atom) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Success."))
         |> assign(:user, user)}

      {:error, :last_provider} ->
        {:noreply, put_flash(socket, :error, gettext("Failed"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed"))}
    end
  end

  def handle_event("delete_user", _params, socket) do
    user = Shared.current_user(socket)

    case Accounts.delete_user(user) do
      {:ok, _deleted_user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Success."))
         |> redirect(external: ~p"/")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed"))}
    end
  end

  def handle_event("delete_conflicting_account", %{"id" => id}, socket) do
    current = Shared.current_user(socket)

    other_user = Accounts.get_user(id)

    case other_user do
      %GameServer.Accounts.User{} = other_user ->
        handle_delete_conflicting_account(socket, current, other_user)

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Not found"))}
    end
  end

  defp handle_delete_conflicting_account(socket, current, other_user) do
    current_email = (current.email || "") |> String.downcase()
    other_email = (other_user.email || "") |> String.downcase()

    cond do
      other_user.id == current.id ->
        {:noreply, put_flash(socket, :error, gettext("Failed"))}

      other_email == current_email and other_email != "" ->
        perform_conflicting_account_deletion(socket, other_user)

      other_user.hashed_password == nil ->
        perform_conflicting_account_deletion(socket, other_user)

      true ->
        {:noreply, put_flash(socket, :error, gettext("Failed"))}
    end
  end

  defp perform_conflicting_account_deletion(socket, user) do
    case Accounts.delete_user(user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Success."))
         |> assign(:conflict_user, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed"))}
    end
  end
end
