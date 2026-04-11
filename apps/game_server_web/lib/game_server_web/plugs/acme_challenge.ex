defmodule GameServerWeb.Plugs.AcmeChallenge do
  @moduledoc """
  Plug to serve ACME HTTP-01 challenge files for Let's Encrypt certificate validation.

  When a Let's Encrypt client (certbot, lego, etc.) requests a certificate, it
  places a token file in a directory and the CA verifies ownership by requesting
  `http://your-domain/.well-known/acme-challenge/<token>`.

  This plug serves those files from a configurable directory, allowing Phoenix
  to handle ACME challenges directly without nginx or other reverse proxies.

  ## Configuration

      config :game_server_web, :acme_challenge_dir, "/var/www/acme-challenge"

  Or via the `ACME_CHALLENGE_DIR` environment variable (set in runtime.exs).
  When the directory is not configured or does not exist, this plug is a no-op.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(
        %Plug.Conn{request_path: "/.well-known/acme-challenge/" <> token} = conn,
        _opts
      ) do
    challenge_dir = Application.get_env(:game_server_web, :acme_challenge_dir)

    if challenge_dir && token != "" do
      # Prevent directory traversal — only allow simple token filenames
      if String.contains?(token, "/") or String.contains?(token, "..") do
        conn
        |> send_resp(400, "Invalid token")
        |> halt()
      else
        file_path = Path.join(challenge_dir, token)

        case File.read(file_path) do
          {:ok, content} ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(200, content)
            |> halt()

          {:error, _} ->
            conn
            |> send_resp(404, "Challenge not found")
            |> halt()
        end
      end
    else
      conn
    end
  end

  def call(conn, _opts), do: conn
end
