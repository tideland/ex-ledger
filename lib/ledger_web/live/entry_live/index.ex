defmodule LedgerWeb.EntryLive.Index do
  @moduledoc """
  LiveView for listing entries (Buchungen).

  This view displays all entries in the ledger system with options
  for filtering, sorting, and pagination.
  """
  use LedgerWeb, :live_view

  # These aliases will be used when connected to real data
  # alias Ledger.Entries
  # alias Ledger.Entries.Entry

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Buchungen")
      |> assign(:current_path, "/buchungen")
      |> assign(:entries, list_entries())
      |> assign(:filter, %{
        text: nil,
        date_from: nil,
        date_to: nil,
        account: nil
      })

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Buchungen")
    |> assign(:entry, nil)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="entries-index">
      <.header>Buchungen</.header>

      <div class="entry-controls">
        <.button phx-click="navigate" phx-value-to="/buchungen/neu">
          Neue Buchung
        </.button>

        <div class="filter-controls">
          <.form :let={f} for={%{}} as={:filter} phx-change="filter">
            <div class="filter-form">
              <div class="field">
                <.label for="filter-text">Suche</.label>
                <.input field={f[:text]} id="filter-text" type="text" placeholder="Beschreibung oder Belegnr." />
              </div>

              <div class="field">
                <.label for="filter-date-from">Von</.label>
                <.input field={f[:date_from]} id="filter-date-from" type="date" />
              </div>

              <div class="field">
                <.label for="filter-date-to">Bis</.label>
                <.input field={f[:date_to]} id="filter-date-to" type="date" />
              </div>

              <.button phx-click="reset-filter" class="secondary">Filter zurücksetzen</.button>
            </div>
          </.form>
        </div>
      </div>

      <.table id="entries" rows={@entries}>
        <:col :let={entry} label="Datum"><%= format_date(entry.date) %></:col>
        <:col :let={entry} label="Belegnr"><%= entry.document_number %></:col>
        <:col :let={entry} label="Beschreibung"><%= entry.description %></:col>
        <:col :let={entry} label="Betrag"><%= format_amount(entry.amount) %></:col>
        <:action :let={entry}>
          <.button phx-click="navigate" phx-value-to={"/buchungen/#{entry.id}"} class="secondary">Anzeigen</.button>
        </:action>
        <:action :let={entry}>
          <.button phx-click="navigate" phx-value-to={"/buchungen/#{entry.id}/bearbeiten"} class="secondary">
            Bearbeiten
          </.button>
        </:action>
      </.table>

      <%= if Enum.empty?(@entries) do %>
        <div class="empty-state">
          <p>Keine Buchungen vorhanden.</p>
          <p>
            <.button phx-click="navigate" phx-value-to="/buchungen/neu">
              Erste Buchung erstellen
            </.button>
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("navigate", %{"to" => to}, socket) do
    {:noreply, push_navigate(socket, to: to)}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter_params}, socket) do
    filter = %{
      text: filter_params["text"],
      date_from: parse_date(filter_params["date_from"]),
      date_to: parse_date(filter_params["date_to"]),
      account: filter_params["account"]
    }

    entries = list_entries(filter)

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:entries, entries)}
  end

  @impl true
  def handle_event("reset-filter", _, socket) do
    filter = %{
      text: nil,
      date_from: nil,
      date_to: nil,
      account: nil
    }

    entries = list_entries()

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:entries, entries)}
  end

  defp list_entries(filter \\ nil) do
    # This would be replaced with actual entry data
    # For now, using placeholder data
    entries = [
      %{
        id: "1",
        date: ~D[2023-01-15],
        document_number: "B2023-0001",
        description: "Miete Januar",
        amount: Decimal.new("-1500.00")
      },
      %{
        id: "2",
        date: ~D[2023-01-14],
        document_number: "B2023-0002",
        description: "Büromaterial",
        amount: Decimal.new("-125.50")
      },
      %{
        id: "3",
        date: ~D[2023-01-13],
        document_number: "B2023-0003",
        description: "Kundenzahlung",
        amount: Decimal.new("2000.00")
      },
      %{
        id: "4",
        date: ~D[2023-01-10],
        document_number: "B2023-0004",
        description: "Gehälter",
        amount: Decimal.new("-3500.00")
      },
      %{
        id: "5",
        date: ~D[2023-01-05],
        document_number: "B2023-0005",
        description: "Verkauf Produkt A",
        amount: Decimal.new("1250.75")
      }
    ]

    case filter do
      nil -> entries
      filter -> filter_entries(entries, filter)
    end
  end

  defp filter_entries(entries, %{text: text, date_from: date_from, date_to: date_to, account: account}) do
    entries
    |> filter_by_text(text)
    |> filter_by_date_range(date_from, date_to)
    |> filter_by_account(account)
  end

  defp filter_by_text(entries, nil), do: entries
  defp filter_by_text(entries, ""), do: entries

  defp filter_by_text(entries, text) do
    text = String.downcase(text)

    Enum.filter(entries, fn entry ->
      String.contains?(String.downcase(entry.description), text) ||
        String.contains?(String.downcase(entry.document_number), text)
    end)
  end

  defp filter_by_date_range(entries, nil, nil), do: entries

  defp filter_by_date_range(entries, date_from, nil) do
    Enum.filter(entries, fn entry -> Date.compare(entry.date, date_from) in [:gt, :eq] end)
  end

  defp filter_by_date_range(entries, nil, date_to) do
    Enum.filter(entries, fn entry -> Date.compare(entry.date, date_to) in [:lt, :eq] end)
  end

  defp filter_by_date_range(entries, date_from, date_to) do
    Enum.filter(entries, fn entry ->
      Date.compare(entry.date, date_from) in [:gt, :eq] && Date.compare(entry.date, date_to) in [:lt, :eq]
    end)
  end

  defp filter_by_account(entries, nil), do: entries
  defp filter_by_account(entries, ""), do: entries

  defp filter_by_account(entries, _account) do
    # In the future, this will filter entries by account
    # For now, just return all entries
    entries
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
