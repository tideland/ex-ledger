defmodule LedgerWeb.Components do
  @moduledoc """
  Reusable UI components for the Ledger application.

  This module provides a set of Phoenix Components for building the Ledger UI,
  following the WUI design specifications.
  """

  use Phoenix.Component

  @doc """
  Renders a header with title.

  ## Examples
      <.header>
        Übersicht
      </.header>
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def header(assigns) do
    ~H"""
    <header class={["header", @class]}>
      <h1><%= render_slot(@inner_block) %></h1>
    </header>
    """
  end

  @doc """
  Renders a menu item in the left navigation.

  ## Examples
      <.menu_item href="/konten" active={@current_path == "/konten"}>
        Konten
      </.menu_item>
  """
  attr :href, :string, required: true
  attr :active, :boolean, default: false
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def menu_item(assigns) do
    ~H"""
    <a href={@href} class={["menu-item", @active && "active", @class]}>
      <%= render_slot(@inner_block) %>
    </a>
    """
  end

  @doc """
  Renders a form label.

  ## Examples
      <.label for="description">
        Beschreibung
      </.label>
  """
  attr :for, :string, required: true
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for}>
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Renders a text input field with label.

  ## Examples
      <.input field={@form[:description]} label="Beschreibung" />
  """
  attr :field, Phoenix.HTML.FormField, doc: "a form field struct"
  attr :label, :string, default: nil
  attr :type, :string, default: "text"
  attr :class, :string, default: nil
  attr :rest, :global

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> field.id end)
      |> assign_new(:name, fn -> field.name end)
      |> assign_new(:value, fn -> field.value end)
      |> assign_new(:errors, fn -> field.errors end)

    ~H"""
    <div class={["field", @errors != [] && "error", @class]}>
      <.label for={@id}><%= @label %></.label>
      <input type={@type} name={@name} id={@id} value={@value} class={["input", @errors != [] && "input-error"]} {@rest} />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Renders an error message.

  ## Examples
      <.error>Betrag muss positiv sein</.error>
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <span class={["error-message", @class]}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  @doc """
  Renders a button.

  ## Examples
      <.button>Speichern</.button>
      <.button class="secondary">Abbrechen</.button>
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button type={@type} class={["button", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a card section for the dashboard.

  ## Examples
      <.card title="Kontensalden">
        Content here
      </.card>
  """
  attr :title, :string, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true
  slot :actions, default: nil

  def card(assigns) do
    ~H"""
    <section class={["card", @class]}>
      <div class="card-header">
        <h2><%= @title %></h2>
        <div class="card-actions">
          <%= render_slot(@actions) %>
        </div>
      </div>
      <div class="card-content">
        <%= render_slot(@inner_block) %>
      </div>
    </section>
    """
  end

  @doc """
  Renders a table.

  ## Examples
      <.table id="accounts">
        <:col :let={account} label="Konto"><%= account.name %></:col>
        <:col :let={account} label="Saldo"><%= format_amount(account.balance) %></:col>
        <:row :for={account <- @accounts} id={account.id} />
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :class, :string, default: nil
  attr :row_click, JS, default: nil

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    ~H"""
    <div class={["table-container", @class]}>
      <table id={@id} class="table">
        <thead>
          <tr>
            <th :for={col <- @col}><%= col[:label] %></th>
            <th :if={@action != []}><span class="sr-only">Aktionen</span></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @rows} id={row.id} class="cursor-pointer" phx-click={@row_click && @row_click.(row)}>
            <td :for={col <- @col}>
              <%= render_slot(col, row) %>
            </td>
            <td :if={@action != []}>
              <div class="action-buttons">
                <div :for={action <- @action}>
                  <%= render_slot(action, row) %>
                </div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
