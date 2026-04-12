defmodule GameServerWeb.Plugs.AcmeChallenge do
  @moduledoc """
  Plug to serve ACME HTTP-01 challenge files for Let's Encrypt certificate validation.

  When a Let's Encrypt client (certbot, lego, etc.) requests a certificate, it
  places a token file in a webroot directory and the CA verifies ownership by
  requesting `http://your-domain/.well-known/acme-challenge/<token>`.

  This plug serves those files from a configurable **webroot** directory, allowing
  Phoenix to handle ACME challenges directly without nginx or other reverse proxies.

  The plug reads tokens from `<webroot>/.well-known/acme-challenge/<token>`, which
  matches the directory structure created by certbot's `--webroot` mode.

  ## Configuration

      # Set the webroot (same path you pass to certbot --webroot-path)
      config :game_server_web, :acme_webroot, "/var/www/acme"

  Or via the `ACME_WEBROOT` environment variable (set in runtime.exs).
  When the webroot is not configured or does not exist, this plug is a no-op.
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
    webroot = Application.get_env(:game_server_web, :acme_webroot)

    if webroot && token != "" do
      # Prevent directory traversal — only allow simple token filenames
      if String.contains?(token, "/") or String.contains?(token, "..") do
        conn
        |> send_resp(400, "Invalid token")
        |> halt()
      else
        # Read from <webroot>/.well-known/acme-challenge/<token>
        # This matches the directory structure created by certbot --webroot
        file_path = Path.join([webroot, ".well-known", "acme-challenge", token])

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
