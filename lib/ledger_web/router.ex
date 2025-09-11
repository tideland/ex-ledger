defmodule LedgerWeb.Router do
  use LedgerWeb, :router

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
  end

  # Add default assigns to all LiveViews

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LedgerWeb do
    pipe_through :browser

    live_session :default, on_mount: [{LedgerWeb.Router, :default}] do
      # LiveView routes
      live "/", DashboardLive, :index
      live "/buchungen", EntryLive.Index, :index
      live "/buchungen/neu", EntryLive.New, :new
      live "/buchungen/:id", EntryLive.Show, :show
      live "/buchungen/:id/bearbeiten", EntryLive.Edit, :edit

      live "/konten", AccountLive.Index, :index
      live "/konten/neu", AccountLive.New, :new
      live "/konten/:id", AccountLive.Show, :show
      live "/konten/:id/bearbeiten", AccountLive.Edit, :edit

      live "/vorlagen", TemplateLive.Index, :index
      live "/vorlagen/neu", TemplateLive.New, :new
      live "/vorlagen/:id", TemplateLive.Show, :show

      live "/berichte", ReportLive.Index, :index

      live "/benutzer", UserLive.Index, :index
      live "/benutzer/neu", UserLive.New, :new
      live "/benutzer/:id", UserLive.Show, :show
      live "/benutzer/:id/bearbeiten", UserLive.Edit, :edit
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
