defmodule LedgerWeb.InitHooks do
  @moduledoc """
  Hooks for initializing LiveView socket connections.

  This module provides hooks that are executed during the LiveView lifecycle
  to ensure proper initialization and configuration of sockets.
  """

  import Phoenix.Component
  import Phoenix.LiveView
  require Logger

  @doc """
  Hook that runs when a LiveView is mounted.

  This hook handles common initialization tasks for all LiveViews:
  - Sets the current path in assigns
  - Adds debugging information
  - Ensures proper socket configuration
  """
  def on_mount(:default, _params, _session, socket) do
    Logger.debug("InitHooks.on_mount(:default) called for #{inspect(socket.view)}")

    socket =
      socket
      |> assign(:current_path, socket.assigns[:current_path] || "/")
      |> assign(:socket_id, socket.id)
      |> assign(:page_loaded_at, DateTime.utc_now())

    # Set return value to continue the mount
    {:cont, socket}
  end

  # Separate function head for the debug hook to avoid @doc redefining warning
  def on_mount(:debug, _params, _session, socket) do
    Logger.info("MOUNT DEBUG - LiveView #{inspect(socket.view)} mounted with id: #{socket.id}")

    socket =
      socket
      |> assign(:debug_mode, true)
      |> push_event("debug:init", %{view: inspect(socket.view), id: socket.id})

    # Set return value to continue the mount
    {:cont, socket}
  end

  @doc """
  Helper function to initialize sockets with common values.
  Can be called directly from mount functions in LiveViews.
  """
  def init_socket(socket, opts \\ []) do
    default_title = opts[:page_title] || "Tideland Ledger"
    current_path = opts[:current_path] || "/"

    socket
    |> assign(:page_title, default_title)
    |> assign(:current_path, current_path)
    |> assign(:socket_initialized, true)
  end
end
