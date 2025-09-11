defmodule LedgerWeb.Application do
  @moduledoc """
  The LedgerWeb application module.

  This module defines and supervises the web-specific processes of the Ledger application.
  It is separate from the main Ledger.Application module to keep web concerns isolated.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Start the Telemetry supervisor
      LedgerWeb.Telemetry,
      # Start the endpoint
      LedgerWeb.Endpoint
      # Add any additional web-specific supervisors here
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    Supervisor.init(children, strategy: :one_for_one)
  end

  def config_change(changed, _new, removed) do
    LedgerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
