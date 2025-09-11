defmodule LedgerWeb.Application do
  @moduledoc """
  The LedgerWeb application module.

  This module defines and supervises the web-specific processes of the Ledger application.
  It is separate from the main Ledger.Application module to keep web concerns isolated.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      LedgerWeb.Telemetry,
      # Start the endpoint
      LedgerWeb.Endpoint
      # Add any additional web-specific supervisors here
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LedgerWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    LedgerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
