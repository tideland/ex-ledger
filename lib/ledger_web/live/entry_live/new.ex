defmodule LedgerWeb.EntryLive.New do
  @moduledoc """
  LiveView for creating new entries (Neue Buchung).

  This view provides a form for creating new bookkeeping entries
  with dynamic positions and real-time validation.
  """
  use LedgerWeb, :live_view

  # These aliases will be used when connected to real data
  # alias Ledger.Entries
  # alias Ledger.Entries.Entry
  # alias Ledger.Entries.Position
  # alias Ledger.Accounts
  # alias Ledger.Accounts.Account
  # alias Ledger.Templates

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Neue Buchung")
      |> assign(:current_path, "/buchungen/neu")
      |> assign(:entry, %{
        date: Date.utc_today(),
        document_number: "",
        description: "",
        positions: [
          %{id: "pos_1", account_id: nil, account_path: "", amount: nil},
          %{id: "pos_2", account_id: nil, account_path: "", amount: nil}
        ]
      })
      |> assign(:changeset, nil)
      |> assign(:templates, list_templates())
      |> assign(:selected_template, nil)
      |> assign(:template_versions, [])
      |> assign(:selected_version, nil)
      |> assign(:accounts, list_accounts())
      |> assign(:sum, Decimal.new(0))
      |> assign(:balanced, true)
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Neue Buchung")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="entry-new">
      <.header>Neue Buchung erstellen</.header>

      <.form :let={_f} for={%{}} phx-change="validate" phx-submit="save">
        <div class="entry-form">
          <div class="entry-form-header">
            <div class="field">
              <.label for="entry-date">Datum</.label>
              <div class="field">
                <label for="entry-date">Datum</label>
                <input type="date" name="date" id="entry-date" value={@entry.date} class="input" />
              </div>
            </div>

            <div class="field">
              <div class="field">
                <label for="entry-document-number">Belegnr.</label>
                <input
                  type="text"
                  name="document_number"
                  id="entry-document-number"
                  value={@entry.document_number}
                  class="input"
                />
              </div>
            </div>

            <div class="field full-width">
              <div class="field">
                <label for="entry-description">Beschreibung</label>
                <input type="text" name="description" id="entry-description" value={@entry.description} class="input" />
              </div>
            </div>

            <div class="field">
              <.label for="template-select">Vorlage</.label>
              <select id="template-select" name="template" phx-change="select-template">
                <option value="">Keine</option>
                <%= for template <- @templates do %>
                  <option value={template.id} selected={@selected_template == template.id}>
                    <%= template.name %>
                  </option>
                <% end %>
              </select>
            </div>

            <div class="field">
              <.label for="version-select">Version</.label>
              <select id="version-select" name="version" disabled={@selected_template == nil} phx-change="select-version">
                <option value="">Aktuelle</option>
                <%= for version <- @template_versions do %>
                  <option value={version.id} selected={@selected_version == version.id}>
                    <%= version.name %>
                  </option>
                <% end %>
              </select>
            </div>
          </div>

          <div class="entry-form-positions">
            <h3>Positionen:</h3>
            <div class="positions-header">
              <div class="position-account">Konto</div>
              <div class="position-amount">Betrag</div>
              <div class="position-actions"></div>
            </div>

            <%= for {position, index} <- Enum.with_index(@entry.positions) do %>
              <div class="position-row" id={"position-#{position.id}"}>
                <div class="position-account">
                  <div class="account-selector">
                    <input
                      name={"account_#{index}"}
                      type="text"
                      value={position.account_path}
                      placeholder="Vermögen : Bank : Girokonto"
                      phx-change="update-position"
                      phx-value-index={index}
                      phx-value-field="account"
                      autocomplete="off"
                      phx-focus="search-accounts"
                      phx-blur="hide-account-results"
                      phx-window-keydown="handle-account-keydown"
                      phx-value-is-current="true"
                      class="input"
                    />
                    <%= if (assigns[:account_search_results] || []) != [] &&
                           assigns[:current_search_index] == index do %>
                      <div class="account-search-results" id="account-search-results">
                        <%= for {account, i} <- Enum.with_index(@account_search_results) do %>
                          <div
                            class={"account-result #{if i == assigns[:selected_account_index], do: "selected"}"}
                            phx-click="select-account"
                            phx-value-path={account.path}
                            phx-value-id={account.id}
                            phx-value-index={index}
                          >
                            <%= account.path %>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
                <div class="position-amount">
                  <input
                    name={"amount_#{index}"}
                    type="text"
                    value={position.amount}
                    placeholder="+1.500,00 oder -1.500,00"
                    phx-change="update-position"
                    phx-value-index={index}
                    phx-value-field="amount"
                    phx-blur="format-amount"
                    class="input"
                  />
                </div>
                <div class="position-actions">
                  <button
                    type="button"
                    phx-click="remove-position"
                    phx-value-index={index}
                    class="button secondary"
                    disabled={length(@entry.positions) <= 2}
                  >
                    &times;
                  </button>
                </div>
              </div>
            <% end %>

            <div class="position-actions-row">
              <button type="button" phx-click="add-position" class="button secondary">
                + Position hinzufügen
              </button>
            </div>

            <div class="entry-sum">
              <div class="sum-label">Summe:</div>
              <div class={"sum-value #{if @balanced, do: "", else: "unbalanced"}"}>
                <%= format_amount(@sum) %>
              </div>
            </div>

            <%= if !@balanced do %>
              <div class="form-error">
                Die Buchung ist nicht ausgeglichen. Die Summe muss 0,00 € sein.
              </div>
            <% end %>
          </div>

          <div class="entry-form-actions">
            <button type="button" phx-click="cancel" class="button secondary">Abbrechen</button>
            <button type="submit" class="button" disabled={!@balanced || @loading}>Buchung speichern</button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    # In a real implementation, this would validate the entry form
    # For now, just update the entry in the socket

    entry = socket.assigns.entry
    # Would normally be a proper changeset
    changeset = nil

    {:noreply, assign(socket, entry: entry, changeset: changeset)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    # In a real implementation, this would save the entry
    # For now, just navigate back to the index

    {:noreply, push_navigate(socket, to: "/entries")}
  end

  @impl true
  def handle_event("cancel", _, socket) do
    {:noreply, push_navigate(socket, to: "/entries")}
  end

  @impl true
  def handle_event("add-position", _, socket) do
    positions = socket.assigns.entry.positions
    new_id = "pos_#{length(positions) + 1}"

    new_position = %{
      id: new_id,
      account_id: nil,
      account_path: "",
      amount: nil
    }

    updated_positions = positions ++ [new_position]
    updated_entry = Map.put(socket.assigns.entry, :positions, updated_positions)

    {:noreply, assign(socket, entry: updated_entry)}
  end

  @impl true
  def handle_event("format-amount", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    positions = socket.assigns.entry.positions
    position = Enum.at(positions, index)

    if position.amount && String.trim(position.amount) != "" do
      # Format the amount in German number format
      formatted_amount = format_amount_input(position.amount)

      updated_position = Map.put(position, :amount, formatted_amount)
      updated_positions = List.replace_at(positions, index, updated_position)
      updated_entry = Map.put(socket.assigns.entry, :positions, updated_positions)

      {:noreply, assign(socket, :entry, updated_entry)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("handle-account-keydown", %{"key" => key}, socket) do
    case key do
      "ArrowDown" ->
        selected_index = socket.assigns[:selected_account_index] || 0
        max_index = length(socket.assigns[:account_search_results] || []) - 1
        new_index = min(selected_index + 1, max_index)
        {:noreply, assign(socket, :selected_account_index, new_index)}

      "ArrowUp" ->
        selected_index = socket.assigns[:selected_account_index] || 0
        new_index = max(selected_index - 1, 0)
        {:noreply, assign(socket, :selected_account_index, new_index)}

      "Enter" ->
        if socket.assigns[:account_search_results] && socket.assigns[:selected_account_index] do
          results = socket.assigns.account_search_results
          selected_index = socket.assigns.selected_account_index

          if Enum.count(results) > 0 do
            selected_account = Enum.at(results, selected_index)
            position_index = socket.assigns.current_search_index

            {:noreply, select_account(socket, selected_account, position_index)}
          else
            {:noreply, socket}
          end
        else
          {:noreply, socket}
        end

      "Escape" ->
        {:noreply,
         socket
         |> assign(:account_search_results, [])
         |> assign(:selected_account_index, nil)
         |> assign(:current_search_index, nil)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("hide-account-results", _params, socket) do
    # Use a slight delay to allow for click events on results
    Process.send_after(self(), :clear_account_results, 200)
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove-position", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    positions = socket.assigns.entry.positions

    # Don't allow removing if only 2 positions remain
    if length(positions) <= 2 do
      {:noreply, socket}
    else
      updated_positions = List.delete_at(positions, index)
      updated_entry = Map.put(socket.assigns.entry, :positions, updated_positions)

      # Recalculate sum
      sum = calculate_sum(updated_positions)
      balanced = Decimal.eq?(sum, Decimal.new(0))

      {:noreply,
       socket
       |> assign(:entry, updated_entry)
       |> assign(:sum, sum)
       |> assign(:balanced, balanced)}
    end
  end

  @impl true
  def handle_event("search-accounts", %{"value" => search_term, "index" => index_str}, socket) do
    index = String.to_integer(index_str)

    search_results =
      if String.trim(search_term) == "" do
        []
      else
        filter_accounts(socket.assigns.accounts, search_term)
      end

    {:noreply,
     socket
     |> assign(:account_search_results, search_results)
     |> assign(:current_search_index, index)
     |> assign(:selected_account_index, 0)}
  end

  @impl true
  def handle_event("search-accounts", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    position = Enum.at(socket.assigns.entry.positions, index)
    search_term = position.account_path

    search_results =
      if String.trim(search_term) == "" do
        socket.assigns.accounts |> Enum.take(10)
      else
        filter_accounts(socket.assigns.accounts, search_term)
      end

    {:noreply,
     socket
     |> assign(:account_search_results, search_results)
     |> assign(:current_search_index, index)
     |> assign(:selected_account_index, 0)}
  end

  @impl true
  def handle_event("select-account", %{"path" => path, "id" => account_id, "index" => index_str}, socket) do
    index = String.to_integer(index_str)
    account = %{id: account_id, path: path}

    {:noreply, select_account(socket, account, index)}
  end

  @impl true
  def handle_event("select-template", %{"template" => template_id}, socket) do
    if template_id == "" do
      {:noreply,
       socket
       |> assign(:selected_template, nil)
       |> assign(:template_versions, [])
       |> assign(:selected_version, nil)}
    else
      # Fetch versions for the selected template
      # In a real implementation, this would come from the database
      versions = [
        %{id: "1", name: "v1"},
        %{id: "2", name: "v2"}
      ]

      latest_version = List.first(versions)

      # Apply the template
      # In a real implementation, this would populate the form with template data

      {:noreply,
       socket
       |> assign(:selected_template, template_id)
       |> assign(:template_versions, versions)
       |> assign(:selected_version, latest_version.id)}
    end
  end

  @impl true
  def handle_event("select-version", %{"version" => version_id}, socket) do
    # Apply the selected template version
    # In a real implementation, this would populate the form with template data

    {:noreply, assign(socket, :selected_version, version_id)}
  end

  @impl true
  def handle_event("update-position", %{"index" => index_str, "field" => field} = params, socket) do
    index = String.to_integer(index_str)
    positions = socket.assigns.entry.positions
    position = Enum.at(positions, index)

    updated_position =
      case field do
        "account" ->
          account_path = params[String.to_atom("account_#{index}")]
          # Would normally look up the account_id based on the path
          Map.merge(position, %{account_path: account_path})

        "amount" ->
          amount_str = params[String.to_atom("amount_#{index}")]
          # Would normally parse the amount properly
          amount = parse_amount(amount_str)
          Map.merge(position, %{amount: amount_str, amount_value: amount})
      end

    updated_positions = List.replace_at(positions, index, updated_position)
    updated_entry = Map.put(socket.assigns.entry, :positions, updated_positions)

    # Recalculate sum
    sum = calculate_sum(updated_positions)
    balanced = Decimal.eq?(sum, Decimal.new(0))

    {:noreply,
     socket
     |> assign(:entry, updated_entry)
     |> assign(:sum, sum)
     |> assign(:balanced, balanced)}
  end

  @impl true
  def handle_info(:clear_account_results, socket) do
    {:noreply,
     socket
     |> assign(:account_search_results, [])
     |> assign(:selected_account_index, nil)
     |> assign(:current_search_index, nil)}
  end

  # Helper functions

  defp format_amount_input(amount_str) do
    case parse_amount(amount_str) do
      nil ->
        amount_str

      amount ->
        # Format with German number format (1.234,56)
        sign = if Decimal.lt?(amount, Decimal.new(0)), do: "-", else: "+"

        # Format the amount with thousand separators
        {int_part, dec_part} =
          amount
          |> Decimal.abs()
          |> Decimal.to_string()
          |> then(fn str ->
            case String.split(str, ".") do
              [int] -> {int, "00"}
              [int, dec] -> {int, String.pad_trailing(dec, 2, "0")}
            end
          end)

        # Add thousand separators to the integer part
        formatted_int =
          int_part
          |> String.to_charlist()
          |> Enum.reverse()
          |> Enum.chunk_every(3)
          |> Enum.join(".")
          |> String.reverse()

        "#{sign}#{formatted_int},#{String.slice(dec_part, 0, 2)}"
    end
  end

  # Format_with_thousand_separator function removed as it's now inlined in format_amount_input

  defp list_templates do
    # This would be replaced with actual template data
    # For now, using placeholder data
    [
      %{id: "1", name: "Monatliche Miete"},
      %{id: "2", name: "Büromaterial"},
      %{id: "3", name: "Gehaltszahlung"}
    ]
  end

  defp list_accounts do
    # This would be replaced with actual account data
    # For now, using placeholder data
    [
      %{id: "1", path: "Vermögen : Bank : Girokonto"},
      %{id: "2", path: "Vermögen : Kasse"},
      %{id: "3", path: "Aufwand : Miete"},
      %{id: "4", path: "Aufwand : Büromaterial"},
      %{id: "5", path: "Aufwand : Gehälter"},
      %{id: "6", path: "Erträge : Verkauf"},
      %{id: "7", path: "Vermögen : Forderungen"},
      %{id: "8", path: "Verbindlichkeiten : Lieferanten"},
      %{id: "9", path: "Aufwand : Versicherungen"},
      %{id: "10", path: "Erträge : Dienstleistungen"},
      %{id: "11", path: "Aufwand : Reisekosten"},
      %{id: "12", path: "Aufwand : Telekommunikation"}
    ]
  end

  defp filter_accounts(accounts, search_term) do
    search_term = String.downcase(search_term)

    accounts
    |> Enum.filter(fn account ->
      String.contains?(String.downcase(account.path), search_term)
    end)
    |> Enum.sort_by(fn account ->
      # Sort by relevance - exact matches first, then by path length
      path = String.downcase(account.path)

      {
        # Whether it starts with the search term (lower is better)
        if(String.starts_with?(path, search_term), do: 0, else: 1),
        # Path length (shorter is better)
        String.length(account.path)
      }
    end)
    |> Enum.take(10)
  end

  defp select_account(socket, account, position_index) do
    positions = socket.assigns.entry.positions
    position = Enum.at(positions, position_index)

    updated_position =
      Map.merge(position, %{
        account_id: account.id,
        account_path: account.path
      })

    updated_positions = List.replace_at(positions, position_index, updated_position)
    updated_entry = Map.put(socket.assigns.entry, :positions, updated_positions)

    # Recalculate sum
    sum = calculate_sum(updated_positions)
    balanced = Decimal.eq?(sum, Decimal.new(0))

    socket
    |> assign(:entry, updated_entry)
    |> assign(:sum, sum)
    |> assign(:balanced, balanced)
    |> assign(:account_search_results, [])
    |> assign(:current_search_index, nil)
    |> assign(:selected_account_index, nil)
  end

  defp parse_amount(nil), do: nil
  defp parse_amount(""), do: nil

  defp parse_amount(amount_str) do
    # Parse German number format (1.234,56)
    try do
      # Remove thousand separators and convert comma to decimal point
      {sign, abs_str} =
        case String.first(amount_str) do
          "+" -> {1, String.slice(amount_str, 1..-1//1)}
          "-" -> {-1, String.slice(amount_str, 1..-1//1)}
          _ -> {1, amount_str}
        end

      clean_str =
        abs_str
        # Remove thousand separators
        |> String.replace(".", "")
        # Convert comma to decimal point
        |> String.replace(",", ".")

      # Parse as Decimal
      with {decimal, ""} <- Decimal.parse(clean_str) do
        if sign < 0 do
          Decimal.negate(decimal)
        else
          decimal
        end
      else
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  defp calculate_sum(positions) do
    # Sum all position amounts
    positions
    |> Enum.map(fn position ->
      case position do
        %{amount_value: value} when not is_nil(value) -> value
        %{amount: amount_str} -> parse_amount(amount_str)
        _ -> Decimal.new(0)
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end
end
