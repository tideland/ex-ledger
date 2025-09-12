defmodule LedgerWeb.EntryLive.Show do
  @moduledoc """
  LiveView for showing entry details (Buchung).

  This view displays the details of a specific entry and its positions.
  """
  use LedgerWeb, :live_view

  # These aliases will be used when connected to real data
  # alias Ledger.Entries
  # alias Ledger.Accounts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Buchung anzeigen")
      |> assign(:current_path, "/buchungen/#{id}")
      |> assign(:entry, get_entry(id))

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Buchung anzeigen")
     |> assign(:current_path, "/buchungen/#{id}")
     |> assign(:entry, get_entry(id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="entry-show">
      <.header>Buchung anzeigen</.header>

      <div class="header-actions">
        <.button phx-click="navigate" phx-value-to={"/entries/#{@entry.id}/edit"}>Bearbeiten</.button>
        <.button phx-click="navigate" phx-value-to="/entries" class="secondary">Zurück</.button>
      </div>

      <div class="entry-details">
        <div class="entry-meta">
          <div class="entry-meta-row">
            <div class="entry-meta-label">Datum:</div>
            <div class="entry-meta-value"><%= format_date(@entry.date) %></div>
          </div>

          <div class="entry-meta-row">
            <div class="entry-meta-label">Belegnr.:</div>
            <div class="entry-meta-value"><%= @entry.document_number %></div>
          </div>

          <div class="entry-meta-row">
            <div class="entry-meta-label">Beschreibung:</div>
            <div class="entry-meta-value"><%= @entry.description %></div>
          </div>
        </div>

        <div class="entry-positions">
          <h3>Positionen:</h3>
          <table class="positions-table">
            <thead>
              <tr>
                <th>Konto</th>
                <th>Betrag</th>
              </tr>
            </thead>
            <tbody>
              <%= for position <- @entry.positions do %>
                <tr>
                  <td><%= position.account_path %></td>
                  <td class="position-amount"><%= format_amount(position.amount) %></td>
                </tr>
              <% end %>
              <tr class="positions-sum-row">
                <td>Summe:</td>
                <td class="position-amount"><%= format_amount(Decimal.new(0)) %></td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="entry-actions">
          <button phx-click="delete" phx-confirm="Sind Sie sicher?" class="button danger">Buchung löschen</button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("navigate", %{"to" => to}, socket) do
    {:noreply, push_navigate(socket, to: to)}
  end

  @impl true
  def handle_event("delete", _, socket) do
    # In a real implementation, this would delete the entry
    # For now, just navigate back to the index
    {:noreply, push_navigate(socket, to: "/entries")}
  end

  # Helper functions

  defp get_entry(id) do
    # This would be replaced with actual entry data
    # For now, using placeholder data
    %{
      id: id,
      date: ~D[2023-01-15],
      document_number: "B2023-0001",
      description: "Miete Januar",
      positions: [
        %{
          id: "pos_1",
          account_id: "3",
          account_path: "Aufwand : Miete",
          amount: Decimal.new("1500.00")
        },
        %{
          id: "pos_2",
          account_id: "1",
          account_path: "Vermögen : Bank : Girokonto",
          amount: Decimal.new("-1500.00")
        }
      ]
    }
  end
end
