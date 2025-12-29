defmodule GameServerWeb.Plugs.MailboxPreviewEnabled do
  @moduledoc false

  import Plug.Conn

  alias GameServer.Env

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    enabled? = Mix.env() == :dev or Env.bool("MAILBOX_PREVIEW_ENABLED", false)

    adapter_is_local? =
      Application.get_env(:game_server_core, GameServer.Mailer, [])[:adapter] ==
        Swoosh.Adapters.Local

    # The preview is only meaningful with the Local adapter. We don't require
    # `config :swoosh, local: true` here because in development it may be unset
    # (defaults to false) but we still want the page to load.
    if enabled? and adapter_is_local? do
      conn
    else
      conn
      |> send_resp(:not_found, "Not found")
      |> halt()
    end
  end
end
