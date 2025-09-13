defmodule LedgerWeb.Router do
  use Phoenix.Router

  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LedgerWeb.Layouts, :root}
    plug :put_layout, html: {LedgerWeb.Layouts, :app}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Development routes
  if Application.compile_env(:tideland_ledger, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LedgerWeb.Telemetry
    end
  end

  scope "/", LedgerWeb do
    pipe_through :browser

    get "/", PageController, :home
  end
end
