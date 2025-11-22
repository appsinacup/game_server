defmodule GameServerWeb.AuthController do
  use GameServerWeb, :controller
  plug Ueberauth

  alias GameServer.Accounts
  alias GameServerWeb.UserAuth

  def request(conn, _params) do
    # This is handled by Ueberauth
    conn
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate with Discord.")
    |> redirect(to: ~p"/users/log-in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      discord_id: auth.uid,
      discord_username: auth.info.nickname || auth.info.name,
      discord_avatar: auth.info.image
    }

    require Logger
    Logger.info("Discord OAuth user params: #{inspect(user_params)}")

    case Accounts.find_or_create_from_discord(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully authenticated with Discord.")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        Logger.error("Failed to create user from Discord: #{inspect(changeset.errors)}")

        conn
        |> put_flash(:error, "Failed to create or update user account.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out!")
    |> UserAuth.log_out_user()
  end
end
