defmodule LedgerWeb.LiveHelpers do
  @moduledoc """
  LiveView helper functions for use across LiveView modules.

  This module provides reusable helper functions and utilities
  for LiveViews in the Ledger application.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Initializes assigns common to all LiveViews.

  ## Examples

      def mount(_params, _session, socket) do
        socket = assign_defaults(socket)
        {:ok, socket}
      end
  """
  def assign_defaults(socket) do
    socket
  end

  @doc """
  Creates a simple modal dialog.

  ## Examples

      <.modal id="confirm-modal">
        <.header>Confirm</.header>
        <p>Are you sure you want to delete this item?</p>
        <.button phx-click={JS.push("delete")} class="danger">Delete</.button>
        <.button phx-click={JS.exec("data-cancel", to: "#confirm-modal")}>Cancel</.button>
      </.modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, :any, default: nil
  slot :inner_block, required: true

  def modal(assigns) do
    assigns = assign_new(assigns, :on_cancel, fn -> nil end)

    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={@on_cancel && JS.exec(@on_cancel, to: "##{@id}")}
      class="modal hidden"
    >
      <div id={"#{@id}-bg"} class="modal-bg" aria-hidden="true" />
      <div
        class="modal-content"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
      >
        <button phx-click="close_modal" phx-value-id={@id} type="button" class="modal-close" aria-label="close">
          &times;
        </button>
        <div id={"#{@id}-content"}>
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  JavaScript function to show a modal.
  """
  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.add_class("modal-open", to: "body")
    |> JS.remove_class("hidden", to: "##{id}")
    |> JS.focus_first(to: "##{id}-content")
  end

  @doc """
  JavaScript function to hide a modal.
  """
  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.remove_class("modal-open", to: "body")
    |> JS.add_class("hidden", to: "##{id}")
  end

  @doc """
  Formats a Decimal amount with German number formatting (1.234,56 €).

  ## Examples

      iex> format_amount(Decimal.new("1234.56"))
      "1.234,56 €"

      iex> format_amount(Decimal.new("-1234.56"))
      "-1.234,56 €"
  """
  def format_amount(amount) do
    # Format amount with German number formatting (1.234,56 €)
    amount_str =
      amount
      |> Decimal.abs()
      |> Decimal.to_string()
      |> String.replace(".", ",")

    sign = if Decimal.lt?(amount, Decimal.new(0)), do: "-", else: ""
    "#{sign}#{amount_str} €"
  end

  @doc """
  Formats a date in German format (DD.MM.YY).

  ## Examples

      iex> format_date(~D[2023-01-15])
      "15.01.23"
  """
  def format_date(date) do
    "#{date.day |> pad_zero()}.#{date.month |> pad_zero()}.#{date.year |> rem(100) |> pad_zero()}"
  end

  @doc """
  Formats a datetime in German format (DD.MM.YY HH:MM).

  ## Examples

      iex> format_datetime(~N[2023-01-15 14:30:00])
      "15.01.23 14:30"
  """
  def format_datetime(datetime) do
    date_part = format_date(datetime)
    time_part = "#{datetime.hour |> pad_zero()}:#{datetime.minute |> pad_zero()}"
    "#{date_part} #{time_part}"
  end

  defp pad_zero(number) when number < 10, do: "0#{number}"
  defp pad_zero(number), do: "#{number}"
end
