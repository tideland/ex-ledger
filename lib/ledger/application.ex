defmodule TidelandLedger.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Load TOML configuration if available
    TidelandLedger.Config.load_default_toml_config()

    children = [
      # Database and Repo
      TidelandLedger.Repo,

      # Phoenix PubSub for real-time features
      {Phoenix.PubSub, name: TidelandLedger.PubSub},

      # Finch HTTP client
      {Finch, name: TidelandLedger.Finch},

      # Phoenix Endpoint (web server) - commented out until web layer is implemented
      # TidelandLedgerWeb.Endpoint,

      # Background tasks and cleanup
      {Task.Supervisor, name: TidelandLedger.TaskSupervisor},

      # Session cleanup task (runs every hour)
      session_cleanup_child_spec()
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TidelandLedger.Supervisor]

    result = Supervisor.start_link(children, opts)

    # Ensure admin user exists after startup
    Task.Supervisor.start_child(TidelandLedger.TaskSupervisor, fn ->
      TidelandLedger.Auth.ensure_admin_user_exists()
    end)

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    # TidelandLedgerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Private helper to create session cleanup task
  defp session_cleanup_child_spec do
    # Run cleanup every hour
    # 1 hour in milliseconds
    cleanup_interval = 60 * 60 * 1000

    %{
      id: :session_cleanup,
      start: {Task, :start_link, [fn -> schedule_session_cleanup(cleanup_interval) end]},
      restart: :permanent
    }
  end

  defp schedule_session_cleanup(interval) do
    Process.sleep(interval)

    case TidelandLedger.Auth.cleanup_expired_sessions() do
      {:ok, count} when count > 0 ->
        require Logger
        Logger.info("Cleaned up #{count} expired sessions")

      _ ->
        :ok
    end

    # Schedule next cleanup
    schedule_session_cleanup(interval)
  end
end
