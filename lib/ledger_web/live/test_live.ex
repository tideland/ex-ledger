defmodule LedgerWeb.TestLive do
  use LedgerWeb, :live_view
  require Logger
  # Don't import these functions since they're not used in this module
  # import LedgerWeb.LiveHelpers, only: [format_date: 1, format_datetime: 1]

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("TestLive.mount called")

    socket =
      socket
      |> LedgerWeb.InitHooks.init_socket(page_title: "LiveView Test", current_path: "/test")
      |> assign(:count, 0)
      |> assign(:current_time, Time.utc_now())

    {:ok, socket}
  end

  @impl true
  def handle_event("increment", _, socket) do
    count = socket.assigns.count + 1
    Logger.info("TestLive.increment called, new count: #{count}")
    {:noreply, assign(socket, count: count)}
  end

  @impl true
  def handle_event("refresh_time", _, socket) do
    Logger.info("TestLive.refresh_time called")
    {:noreply, assign(socket, current_time: Time.utc_now())}
  end

  @impl true
  def render(assigns) do
    Logger.info("TestLive.render called")

    ~H"""
    <div style="padding: 20px; background-color: #f5f5f5; border: 1px solid #ddd; margin: 20px; border-radius: 5px;">
      <h1 style="color: #333;">LiveView Test Page</h1>

      <p>This is a simple test of LiveView functionality.</p>

      <div style="margin: 20px 0; padding: 10px; background-color: white; border: 1px solid #ccc;">
        <p>Counter: <span style="font-weight: bold; font-size: 1.5em;"><%= @count %></span></p>
        <button
          phx-click="increment"
          style="padding: 5px 10px; background-color: #3c5c76; color: white; border: none; cursor: pointer;"
        >
          Increment Counter
        </button>
      </div>

      <div style="margin: 20px 0; padding: 10px; background-color: white; border: 1px solid #ccc;">
        <p>Current time: <span style="font-weight: bold;"><%= @current_time %></span></p>
        <button
          phx-click="refresh_time"
          style="padding: 5px 10px; background-color: #3c5c76; color: white; border: none; cursor: pointer;"
        >
          Refresh Time
        </button>
      </div>

      <p style="margin-top: 20px;">
        <a href="/" style="color: #3c5c76;">Back to Dashboard</a>
      </p>

      <div style="margin-top: 20px; font-size: 0.8em; color: #666;">
        <p>Debug Info:</p>
        <ul>
          <li>Socket ID: <%= if assigns[:socket_id], do: assigns[:socket_id], else: "Not available" %></li>
          <li>Connection status: <span id="connection-status">Checking...</span></li>
          <li>Current path: <%= @current_path %></li>
          <li>Page title: <%= @page_title %></li>
          <li>Page loaded: <%= if assigns[:page_loaded_at], do: @page_loaded_at, else: "Unknown" %></li>
        </ul>
        <script>
          document.addEventListener("DOMContentLoaded", function() {
            const statusElement = document.getElementById("connection-status");
            if (window.liveSocket) {
              statusElement.textContent = window.liveSocket.isConnected() ? "Connected" : "Disconnected";
              console.log("LiveView socket found:", window.liveSocket);
            } else {
              statusElement.textContent = "No LiveView socket found";
              console.error("No LiveView socket found");
            }
          });
        </script>
      </div>
    </div>
    """
  end
end
