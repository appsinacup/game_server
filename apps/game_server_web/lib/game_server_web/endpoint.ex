defmodule GameServerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :game_server_web

  @session_options [
    store: :cookie,
    key: "_game_server_key",
    signing_salt: "G8u1px36",
    same_site: "Lax",
    secure: Application.compile_env(:game_server_web, :session_secure, false)
  ]

  socket "/socket", GameServerWeb.UserSocket,
    websocket: [log: false, compress: true, max_frame_size: 131_072],
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, session: @session_options], log: false, compress: true],
    longpoll: [connect_info: [session: @session_options], log: false]

  plug GameServerWeb.Plugs.AcmeChallenge
  plug GameServerWeb.Plugs.SecurityHeaders
  plug GameServerWeb.Plugs.WellKnown
  plug GameServerWeb.Plugs.GameHeaders
  plug :serve_host_static
  plug :serve_asset_static
  plug :serve_web_font_static
  plug GameServerWeb.HostContentStatic

  if code_reloading? and Code.ensure_loaded?(Phoenix.LiveReloader) and
       Code.ensure_loaded?(Phoenix.LiveReloader.Socket) do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :game_server_web
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug GameServerWeb.Plugs.RealIp
  plug GameServerWeb.Plugs.GeoCountry
  plug GameServerWeb.Plugs.IpBan
  plug GameServerWeb.Plugs.RequestTimer

  plug Plug.Telemetry,
    event_prefix: [:phoenix, :endpoint],
    log: {__MODULE__, :access_log_level, []}

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    length: 1_048_576,
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  @compiled_session_opts Plug.Session.init(@session_options)
  plug :maybe_session

  defp maybe_session(%{path_info: ["api", "v1" | _]} = conn, _opts), do: conn
  defp maybe_session(conn, _opts), do: Plug.Session.call(conn, @compiled_session_opts)

  plug GameServerWeb.Plugs.LocalePath
  plug GameServerWeb.Plugs.DynamicCors
  plug GameServerWeb.Plugs.RateLimiter
  plug :dispatch_router

  @access_log_pt_key {__MODULE__, :access_log_level}

  def access_log_level(_conn) do
    case :persistent_term.get(@access_log_pt_key, :not_set) do
      :not_set ->
        level =
          case Application.get_env(:game_server_web, __MODULE__)[:access_log] do
            level when level in [:debug, :info, :warning, :error] -> level
            false -> false
            _ -> :debug
          end

        :persistent_term.put(@access_log_pt_key, level)
        level

      cached ->
        cached
    end
  end

  defp serve_host_static(conn, _opts) do
    Plug.Static.call(
      conn,
      configurable_static_opts(:host_static_opts, host_static_app(), host_static_paths())
    )
  end

  defp serve_asset_static(conn, _opts) do
    Plug.Static.call(
      conn,
      configurable_static_opts(:asset_static_opts, asset_static_app(), ~w(assets))
    )
  end

  defp serve_web_font_static(conn, _opts) do
    Plug.Static.call(
      conn,
      configurable_static_opts(:web_font_static_opts, :game_server_web, ~w(fonts))
    )
  end

  defp dispatch_router(conn, _opts) do
    router = Application.get_env(:game_server_web, :router, GameServerWeb.Router)
    router.call(conn, router.init([]))
  end

  defp configurable_static_opts(kind, from, only) do
    key = {__MODULE__, kind, from, only, gzip_static?()}

    case :persistent_term.get(key, :not_set) do
      :not_set ->
        opts =
          Plug.Static.init(
            at: "/",
            from: from,
            gzip: gzip_static?(),
            only: only,
            cache_control_for_etags: "public, max-age=604800",
            cache_control_for_vsn_requests: "public, max-age=31536000, immutable"
          )

        :persistent_term.put(key, opts)
        opts

      opts ->
        opts
    end
  end

  defp host_static_app do
    Application.get_env(:game_server_web, :host_static_app, :game_server_web)
  end

  defp asset_static_app do
    Application.get_env(:game_server_web, :asset_static_app, host_static_app())
  end

  defp host_static_paths do
    Application.get_env(
      :game_server_web,
      :host_static_paths,
      ~w(images game favicon.ico robots.txt .well-known theme.css)
    )
  end

  defp gzip_static? do
    Application.get_env(:game_server_web, :gzip_static, false)
  end
end
