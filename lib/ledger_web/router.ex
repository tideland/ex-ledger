defmodule LedgerWeb.Router do
  use LedgerWeb, :router

  # Print debug message during compile
  require Logger
  Logger.info("Compiling LedgerWeb.Router...")

  # Debug helper
  def debug_path(conn, _opts) do
    Logger.info("Router processing path: #{inspect(conn.request_path)}")
    conn
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LedgerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :debug_path
    plug :always_redirect_root
  end

  # Add default assigns to all LiveViews

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LedgerWeb do
    pipe_through :browser

    # Static page route for testing
    get "/static", PageController, :index

    # Debug route for basic connectivity testing
    get "/debug", PageController, :debug

    # Static dashboard for testing
    get "/static-dashboard", PageController, :dashboard

    # Test LiveView for basic functionality testing
    get "/test-static", PageController, :test_static

    # Troubleshooting page
    get "/troubleshoot", PageController, :troubleshoot

    # Test HTML page for LiveView debugging
    get "/test.html", PageController, :test_html

    # Static dashboard fallback (for when LiveView isn't working)
    get "/dashboard-static", PageController, :static_dashboard_fallback

    live_session :default, on_mount: [{LedgerWeb.InitHooks, :default}, {LedgerWeb.InitHooks, :debug}] do
      # Test LiveView route
      live "/test", TestLive, :index
      # LiveView routes
      live "/", DashboardLive, :index

      # Only include the Entry LiveViews that actually exist
      live "/entries", EntryLive.Index, :index
      live "/entries/new", EntryLive.New, :new
      live "/entries/:id", EntryLive.Show, :show

      # Comment out missing LiveView modules until they are implemented
      # live "/entries/:id/edit", EntryLive.Edit, :edit

      # Commented out missing Account LiveViews
      # live "/accounts", AccountLive.Index, :index
      # live "/accounts/new", AccountLive.New, :new
      # live "/accounts/:id", AccountLive.Show, :show
      # live "/accounts/:id/edit", AccountLive.Edit, :edit

      # Commented out missing Template LiveViews
      # live "/templates", TemplateLive.Index, :index
      # live "/templates/new", TemplateLive.New, :new
      # live "/templates/:id", TemplateLive.Show, :show

      # Commented out missing Report LiveViews
      # live "/reports", ReportLive.Index, :index

      # Commented out missing User LiveViews
      # live "/users", UserLive.Index, :index
      # live "/users/new", UserLive.New, :new
      # live "/users/:id", UserLive.Show, :show
      # live "/users/:id/edit", UserLive.Edit, :edit
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", LedgerWeb do
  #   pipe_through :api
  # end

  # Always redirect root path to static dashboard
  defp always_redirect_root(conn, _opts) do
    # Only apply to GET requests
    if conn.method != "GET" do
      conn
    else
      # Check if we're on the root path
      case conn.request_path do
        "/" ->
          Logger.info("Redirecting root path to static dashboard")
          Phoenix.Controller.redirect(conn, to: "/dashboard-static")

        _ ->
          conn
      end
    end
  end

  # Enable LiveDashboard in development
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: LedgerWeb.Telemetry
    end
  end
end
