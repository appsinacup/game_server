defmodule GameServerWeb.UserLive.Confirmation do
  use GameServerWeb, :live_view

  alias GameServer.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>{gettext("Welcome %{email}", email: @user.email)}</.header>
        </div>

        <.form
          :if={!@user.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action={~p"/users/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <.button
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with={gettext("Confirming...")}
            class="btn btn-primary w-full"
          >
            {gettext("Confirm and stay logged in")}
          </.button>
          <.button
            phx-disable-with={gettext("Confirming...")}
            class="btn btn-primary btn-soft w-full mt-2"
          >
            {gettext("Confirm and log in only this time")}
          </.button>
        </.form>

        <.form
          :if={@user.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action={~p"/users/log-in"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <%= if @current_scope do %>
            <.button phx-disable-with={gettext("Logging in...")} class="btn btn-primary w-full">
              {gettext("Log in")}
            </.button>
          <% else %>
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with={gettext("Logging in...")}
              class="btn btn-primary w-full"
            >
              {gettext("Keep me logged in on this device")}
            </.button>
            <.button
              phx-disable-with={gettext("Logging in...")}
              class="btn btn-primary btn-soft w-full mt-2"
            >
              {gettext("Log me in only this time")}
            </.button>
          <% end %>
        </.form>

        <p :if={!@user.confirmed_at} class="alert alert-outline mt-8">
          {gettext("Tip: If you prefer passwords, you can enable them in the user settings.")}
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, gettext("Magic link is invalid or it has expired."))
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
