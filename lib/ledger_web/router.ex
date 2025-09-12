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

  @doc """
  Helper function to ensure LiveView assigns have the required default values.
  """
  def on_mount(:default, _params, _session, socket) do
    # Simply assign "/" as the current path; the real path will be set in the controller
    socket = Phoenix.Component.assign(socket, :current_path, "/")
    {:cont, socket}
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LedgerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :debug_path
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

    live_session :default, on_mount: [{LedgerWeb.Router, :default}] do
      # LiveView routes
      live "/", DashboardLive, :index
      live "/entries", EntryLive.Index, :index
      live "/entries/new", EntryLive.New, :new
      live "/entries/:id", EntryLive.Show, :show
      live "/entries/:id/edit", EntryLive.Edit, :edit

      live "/accounts", AccountLive.Index, :index
      live "/accounts/new", AccountLive.New, :new
      live "/accounts/:id", AccountLive.Show, :show
      live "/accounts/:id/edit", AccountLive.Edit, :edit

      live "/templates", TemplateLive.Index, :index
      live "/templates/new", TemplateLive.New, :new
      live "/templates/:id", TemplateLive.Show, :show

      live "/reports", ReportLive.Index, :index

      live "/users", UserLive.Index, :index
      live "/users/new", UserLive.New, :new
      live "/users/:id", UserLive.Show, :show
      live "/users/:id/edit", UserLive.Edit, :edit
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", LedgerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: LedgerWeb.Telemetry
    end
  end
end
