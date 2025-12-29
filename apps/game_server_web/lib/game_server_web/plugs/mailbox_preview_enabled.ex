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

    # Swoosh mailbox preview only has something to show when local storage is enabled.
    local_storage_enabled? = Application.get_env(:swoosh, :local, false)

    if enabled? and adapter_is_local? and local_storage_enabled? do
      conn
    else
      conn
      |> send_resp(:not_found, "Not found")
      |> halt()
    end
  end
end
