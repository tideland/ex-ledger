defmodule Ledger.EctoTypes.Amount do
  @moduledoc """
  Custom Ecto type for storing and retrieving Amount values.

  This type handles the conversion between our Amount struct and the database
  representation. Amounts are stored as integers (cents) in the database to
  maintain precision and avoid floating-point errors.

  The type also stores the currency code to ensure amounts are properly
  reconstructed when loaded from the database.
  """

  use Ecto.Type

  alias Ledger.Amount

  @impl true
  def type, do: :map

  @impl true
  def cast(%Amount{} = amount), do: {:ok, amount}

  def cast(%{"cents" => cents, "currency" => currency})
      when is_integer(cents) and is_binary(currency) do
    {:ok, Amount.from_cents(cents, currency)}
  end

  def cast(%{cents: cents, currency: currency}) when is_integer(cents) and is_binary(currency) do
    {:ok, Amount.from_cents(cents, currency)}
  end

  # Allow casting from numeric values using default currency
  def cast(value) when is_number(value) do
    {:ok, Amount.new(value)}
  end

  # Allow casting from string values (parsing required)
  def cast(value) when is_binary(value) do
    case Amount.parse(value) do
      {:ok, amount} -> {:ok, amount}
      {:error, _} -> :error
    end
  end

  def cast(_), do: :error

  @impl true
  def load(data) when is_map(data) do
    cents = Map.get(data, "cents") || Map.get(data, :cents)
    currency = Map.get(data, "currency") || Map.get(data, :currency) || "EUR"

    if is_integer(cents) do
      {:ok, Amount.from_cents(cents, currency)}
    else
      :error
    end
  end

  def load(_), do: :error

  @impl true
  def dump(%Amount{cents: cents, currency: currency}) do
    {:ok, %{cents: cents, currency: currency}}
  end

  def dump(_), do: :error

  @impl true
  def equal?(nil, nil), do: true
  def equal?(%Amount{} = a, %Amount{} = b), do: Amount.compare(a, b) == :eq
  def equal?(_, _), do: false

  @impl true
  def embed_as(_), do: :dump
end
