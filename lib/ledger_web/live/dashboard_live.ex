defmodule LedgerWeb.DashboardLive do
  @moduledoc """
  LiveView for the dashboard (Übersicht) page.

  This is the main entry point of the application, showing a summary
  of account balances and recent entries.
  """
  use LedgerWeb, :live_view

  # These aliases will be used when connected to real data
  # alias Ledger.Accounts
  # alias Ledger.Entries

  @impl true
  def mount(_params, _session, socket) do
    require Logger
    Logger.info("DashboardLive.mount called")

    socket =
      socket
      |> assign(:page_title, "Übersicht")
      |> assign(:current_path, "/")
      |> assign(:account_balances, fetch_account_balances())
      |> assign(:recent_entries, fetch_recent_entries())

    Logger.info("DashboardLive.mount completed")
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    require Logger
    Logger.info("DashboardLive.render called")

    ~H"""
    <div class="dashboard">
      <.header>Übersicht</.header>

      <div class="dashboard-grid">
        <.card title="Kontensalden">
          <:actions>
            <.button phx-click="navigate" phx-value-to="/konten" class="secondary">Alle Konten anzeigen</.button>
          </:actions>

          <div class="account-balances">
            <%= if Enum.empty?(@account_balances) do %>
              <p>Keine Konten vorhanden.</p>
            <% else %>
              <%= for account <- @account_balances do %>
                <div class="account-balance">
                  <div class="account-name"><%= account.name %></div>
                  <div class="account-amount"><%= format_amount(account.balance) %></div>
                </div>
              <% end %>
            <% end %>
          </div>
        </.card>

        <.card title="Letzte Buchungen">
          <:actions>
            <.button phx-click="navigate" phx-value-to="/buchungen" class="secondary">Alle Buchungen anzeigen</.button>
          </:actions>

          <div class="recent-entries">
            <%= if Enum.empty?(@recent_entries) do %>
              <p>Keine Buchungen vorhanden.</p>
            <% else %>
              <%= for entry <- @recent_entries do %>
                <div class="recent-entry" phx-click="view-entry" phx-value-id={entry.id}>
                  <div class="entry-date"><%= format_date(entry.date) %></div>
                  <div class="entry-description"><%= entry.description %></div>
                  <div class="entry-amount"><%= format_amount(entry.amount) %></div>
                </div>
              <% end %>
            <% end %>
          </div>
        </.card>
      </div>

      <.card title="Schnellaktionen">
        <div class="quick-actions">
          <.button phx-click="navigate" phx-value-to="/buchungen/neu">Neue Buchung</.button>
          <.button phx-click="navigate" phx-value-to="/vorlagen">Vorlage anwenden</.button>
          <.button phx-click="navigate" phx-value-to="/berichte">Bericht erstellen</.button>
        </div>
      </.card>
    </div>
    """
  end

  @impl true
  def handle_event("navigate", %{"to" => to}, socket) do
    require Logger
    Logger.info("DashboardLive.handle_event navigate to: #{to}")
    {:noreply, push_navigate(socket, to: to)}
  end

  @impl true
  def handle_event("view-entry", %{"id" => id}, socket) do
    require Logger
    Logger.info("DashboardLive.handle_event view-entry id: #{id}")
    {:noreply, push_navigate(socket, to: "/buchungen/#{id}")}
  end

  # Helper functions

  defp fetch_account_balances do
    # This would be replaced with actual account data
    # For now, using placeholder data
    [
      %{id: "1", name: "Bank: Girokonto", balance: Decimal.new("12500.00")},
      %{id: "2", name: "Kasse", balance: Decimal.new("250.00")},
      %{id: "3", name: "Forderungen", balance: Decimal.new("5000.00")}
    ]
  end

  defp fetch_recent_entries do
    # This would be replaced with actual entry data
    # For now, using placeholder data
    [
      %{id: "1", date: ~D[2023-01-15], description: "Miete", amount: Decimal.new("-1500.00")},
      %{id: "2", date: ~D[2023-01-14], description: "Material", amount: Decimal.new("-125.50")},
      %{id: "3", date: ~D[2023-01-13], description: "Zahlung", amount: Decimal.new("2000.00")}
    ]
  end

  # Helper functions for this LiveView are now in LiveHelpers
end
