defmodule LedgerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :tideland_ledger

  # Print debug message during startup
  require Logger
  Logger.info("Starting LedgerWeb.Endpoint on port 4002...")

  # Add initialization callback
  def init(_key, config) do
    Logger.info("Initializing LedgerWeb.Endpoint with config: #{inspect(config)}")
    {:ok, config}
  end

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_ledger_key",
    signing_salt: "Pn9+5iIp",
    same_site: "Lax"
  ]

  # Add debugging for socket connections
  require Logger

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [session: @session_options],
      timeout: 45_000,
      check_origin: false,
      error_handler: {__MODULE__, :handle_websocket_error}
    ]

  # Serve at "/" the static files from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :tideland_ledger,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt),
    cache_control_for_etags: "public, max-age=86400"

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :ledger
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug LedgerWeb.Router

  # WebSocket error handler
  def handle_websocket_error(conn, %{reason: reason}) do
    Logger.error("LiveView WebSocket error: #{inspect(reason)}")
    Plug.Conn.send_resp(conn, 500, "WebSocket error: #{inspect(reason)}")
  end

  # Log when a LiveView socket connects
  def __sockets__(:connect, :phoenix_live_reload, socket) do
    socket
  end

  def __sockets__(:connect, :live, socket) do
    Logger.info("LiveView socket connected: #{inspect(socket.id)}")
    socket
  end
end
