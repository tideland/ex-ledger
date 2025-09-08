defmodule TidelandLedger.Amount do
  @moduledoc """
  Represents monetary amounts with exact precision for financial calculations.

  This module is the foundation of all financial calculations in the ledger system.
  Amounts are stored internally as integers representing the smallest currency unit
  (cents for EUR) to avoid floating-point precision errors. All arithmetic operations
  maintain exact precision and use banker's rounding when necessary.

  The module provides a complete set of operations for monetary calculations including
  arithmetic, comparison, formatting, and distribution of amounts across multiple
  recipients while ensuring no cents are lost.
  """

  alias Decimal, as: D

  @type t :: %__MODULE__{
          cents: integer(),
          currency: String.t()
        }

  @enforce_keys [:cents, :currency]
  defstruct [:cents, :currency]

  # Standard currency configurations
  # Currently only EUR is supported, but the structure allows for future expansion
  @currencies %{
    "EUR" => %{symbol: "€", decimal_places: 2, minor_unit: 100}
  }

  @default_currency "EUR"

  # Creation and parsing functions
  # These functions handle the various ways amounts can be created in the system

  @doc """
  Creates a new Amount from a decimal value.

  The decimal is converted to the minor currency unit (cents) using the
  currency's standard precision. Banker's rounding is applied if necessary.

  ## Examples

      iex> Amount.new(123.45)
      %Amount{cents: 12345, currency: "EUR"}

      iex> Amount.new(D.new("123.456"))
      %Amount{cents: 12346, currency: "EUR"}  # Banker's rounding applied
  """
  def new(decimal, currency \\ @default_currency)

  def new(%D{} = decimal, currency) do
    config = currency_config!(currency)

    # Convert to minor units and apply banker's rounding
    cents =
      decimal
      |> D.mult(config.minor_unit)
      |> D.round(0, :half_even)
      |> D.to_integer()

    %__MODULE__{cents: cents, currency: currency}
  end

  def new(number, currency) when is_number(number) do
    number
    |> D.new()
    |> new(currency)
  end

  @doc """
  Creates an Amount directly from cents.

  This is useful when working with imported data or database values
  that are already stored as integers.
  """
  def from_cents(cents, currency \\ @default_currency) when is_integer(cents) do
    %__MODULE__{cents: cents, currency: currency}
  end

  @doc """
  Parses an Amount from a string representation.

  Handles both German (1.234,56) and international (1234.56) number formats.
  The format is auto-detected based on the presence of commas and dots.

  ## Examples

      iex> Amount.parse("1.234,56")
      {:ok, %Amount{cents: 123456, currency: "EUR"}}

      iex> Amount.parse("1234.56")
      {:ok, %Amount{cents: 123456, currency: "EUR"}}
  """
  def parse(string, currency \\ @default_currency) when is_binary(string) do
    # Detect format by checking last occurrence of comma vs dot
    normalized =
      cond do
        # German format: 1.234,56
        String.match?(string, ~r/\d\.\d{3}[,\s]/) or String.match?(string, ~r/,\d{2}$/) ->
          string
          |> String.replace(".", "")
          |> String.replace(",", ".")

        # Already in international format or simple number
        true ->
          string
      end

    # Remove all whitespace and parse
    case normalized |> String.replace(" ", "") |> D.parse() do
      {:ok, decimal} -> {:ok, new(decimal, currency)}
      :error -> {:error, :invalid_format}
    end
  end

  @doc """
  Same as parse/2 but raises on error.
  """
  def parse!(string, currency \\ @default_currency) do
    case parse(string, currency) do
      {:ok, amount} -> amount
      {:error, reason} -> raise ArgumentError, "Invalid amount format: #{reason}"
    end
  end

  # Arithmetic operations
  # All operations maintain precision and handle currency validation

  @doc """
  Adds two amounts together.

  Both amounts must be in the same currency. The result maintains
  the exact sum without any rounding.
  """
  def add(
        %__MODULE__{cents: cents1, currency: curr} = _amount1,
        %__MODULE__{cents: cents2, currency: curr} = _amount2
      ) do
    %__MODULE__{cents: cents1 + cents2, currency: curr}
  end

  def add(%__MODULE__{currency: curr1}, %__MODULE__{currency: curr2}) do
    raise ArgumentError, "Cannot add amounts in different currencies: #{curr1} and #{curr2}"
  end

  @doc """
  Subtracts the second amount from the first.

  Both amounts must be in the same currency. The result can be negative,
  which is valid for accounting entries.
  """
  def subtract(
        %__MODULE__{cents: cents1, currency: curr} = _amount1,
        %__MODULE__{cents: cents2, currency: curr} = _amount2
      ) do
    %__MODULE__{cents: cents1 - cents2, currency: curr}
  end

  def subtract(%__MODULE__{currency: curr1}, %__MODULE__{currency: curr2}) do
    raise ArgumentError, "Cannot subtract amounts in different currencies: #{curr1} and #{curr2}"
  end

  @doc """
  Multiplies an amount by a factor.

  The factor can be any number (integer, float, or Decimal). The result
  is rounded using banker's rounding to maintain monetary precision.
  """
  def multiply(%__MODULE__{cents: cents, currency: currency}, factor) do
    new_cents =
      cents
      |> D.new()
      |> D.mult(convert_to_decimal(factor))
      |> D.round(0, :half_even)
      |> D.to_integer()

    %__MODULE__{cents: new_cents, currency: currency}
  end

  @doc """
  Divides an amount by a divisor.

  Uses banker's rounding for the result. For distributing amounts across
  multiple recipients, use distribute/2 instead to ensure no cents are lost.
  """
  def divide(%__MODULE__{cents: cents, currency: currency}, divisor) do
    new_cents =
      cents
      |> D.new()
      |> D.div(convert_to_decimal(divisor))
      |> D.round(0, :half_even)
      |> D.to_integer()

    %__MODULE__{cents: new_cents, currency: currency}
  end

  @doc """
  Negates an amount (changes its sign).

  This is useful for creating balancing entries in the ledger where
  one side must be the negative of the other.
  """
  def negate(%__MODULE__{cents: cents, currency: currency}) do
    %__MODULE__{cents: -cents, currency: currency}
  end

  @doc """
  Returns the absolute value of an amount.
  """
  def abs(%__MODULE__{cents: cents, currency: currency}) do
    %__MODULE__{cents: Kernel.abs(cents), currency: currency}
  end

  # Distribution functions
  # These ensure fair distribution without losing cents

  @doc """
  Distributes an amount across multiple parts.

  This function ensures that the sum of all parts exactly equals the original
  amount, with no cents lost due to rounding. Any remainder from division is
  distributed one cent at a time to the parts, starting from the first.

  ## Examples

      iex> Amount.distribute(Amount.new(100), 3)
      [
        %Amount{cents: 3334, currency: "EUR"},  # 33.34
        %Amount{cents: 3333, currency: "EUR"},  # 33.33
        %Amount{cents: 3333, currency: "EUR"}   # 33.33
      ]
  """
  def distribute(%__MODULE__{cents: cents, currency: currency}, parts) when parts > 0 do
    base_amount = div(cents, parts)
    remainder = rem(cents, parts)

    # Create the distribution list
    # The first 'remainder' parts get an extra cent
    Enum.map(1..parts, fn index ->
      part_cents = if index <= remainder, do: base_amount + 1, else: base_amount
      %__MODULE__{cents: part_cents, currency: currency}
    end)
  end

  @doc """
  Distributes an amount according to specified ratios.

  Ratios are normalized to sum to 1.0, and the amount is distributed
  proportionally. Any rounding remainder is added to the largest ratio
  to minimize relative error.

  ## Examples

      iex> Amount.distribute_by_ratio(Amount.new(100), [0.5, 0.3, 0.2])
      [
        %Amount{cents: 5000, currency: "EUR"},  # 50.00
        %Amount{cents: 3000, currency: "EUR"},  # 30.00
        %Amount{cents: 2000, currency: "EUR"}   # 20.00
      ]
  """
  def distribute_by_ratio(%__MODULE__{cents: cents, currency: currency}, ratios) do
    # Normalize ratios to sum to 1
    ratio_sum = Enum.sum(ratios)
    normalized_ratios = Enum.map(ratios, &(&1 / ratio_sum))

    # Calculate base distribution
    distributions =
      normalized_ratios
      |> Enum.map(fn ratio ->
        (cents * ratio)
        |> Float.round()
        |> trunc()
      end)

    # Calculate remainder and add to largest ratio
    distributed_sum = Enum.sum(distributions)
    remainder = cents - distributed_sum

    if remainder != 0 do
      # Find index of largest ratio
      max_index =
        normalized_ratios
        |> Enum.with_index()
        |> Enum.max_by(fn {ratio, _} -> ratio end)
        |> elem(1)

      # Add remainder to that position
      distributions
      |> List.update_at(max_index, &(&1 + remainder))
      |> Enum.map(&%__MODULE__{cents: &1, currency: currency})
    else
      Enum.map(distributions, &%__MODULE__{cents: &1, currency: currency})
    end
  end

  # Comparison functions
  # These enable amounts to be compared and sorted

  @doc """
  Compares two amounts.

  Returns :gt if first is greater, :lt if less, :eq if equal.
  Amounts must be in the same currency.
  """
  def compare(
        %__MODULE__{cents: cents1, currency: curr},
        %__MODULE__{cents: cents2, currency: curr}
      ) do
    cond do
      cents1 > cents2 -> :gt
      cents1 < cents2 -> :lt
      true -> :eq
    end
  end

  def compare(%__MODULE__{currency: curr1}, %__MODULE__{currency: curr2}) do
    raise ArgumentError, "Cannot compare amounts in different currencies: #{curr1} and #{curr2}"
  end

  @doc """
  Checks if an amount is zero.
  """
  def zero?(%__MODULE__{cents: 0}), do: true
  def zero?(%__MODULE__{}), do: false

  @doc """
  Checks if an amount is positive (greater than zero).
  """
  def positive?(%__MODULE__{cents: cents}), do: cents > 0

  @doc """
  Checks if an amount is negative (less than zero).
  """
  def negative?(%__MODULE__{cents: cents}), do: cents < 0

  # Formatting functions
  # These handle display of amounts in user interfaces

  @doc """
  Formats an amount as a string using the currency's standard format.

  For EUR, this produces strings like "1.234,56 €" using German formatting.
  Negative amounts are shown with a minus sign.
  """
  def to_string(%__MODULE__{cents: cents, currency: currency}) do
    config = currency_config!(currency)

    # Convert cents to decimal for formatting
    decimal =
      cents
      |> D.new()
      |> D.div(config.minor_unit)

    # Format with German number format for EUR
    formatted = format_decimal(decimal, config.decimal_places)

    # Add currency symbol
    if cents >= 0 do
      "#{formatted} #{config.symbol}"
    else
      # Ensure minus sign comes before the number
      formatted_positive = format_decimal(D.abs(decimal), config.decimal_places)
      "-#{formatted_positive} #{config.symbol}"
    end
  end

  @doc """
  Converts the amount to a Decimal value.

  This is useful for calculations that need to be done in the decimal domain
  or for exporting to systems that expect decimal values.
  """
  def to_decimal(%__MODULE__{cents: cents, currency: currency}) do
    config = currency_config!(currency)

    cents
    |> D.new()
    |> D.div(config.minor_unit)
  end

  # Sum function for collections
  # Efficiently sums a list of amounts

  @doc """
  Sums a list of amounts.

  All amounts must be in the same currency. Returns a zero amount in the
  common currency if the list is empty.

  ## Examples

      iex> Amount.sum([Amount.new(10), Amount.new(20), Amount.new(30)])
      %Amount{cents: 6000, currency: "EUR"}  # 60.00
  """
  def sum([]), do: zero()

  def sum([first | _] = amounts) do
    # Use the currency from the first amount
    currency = first.currency

    # Verify all amounts have the same currency and sum cents
    total_cents =
      Enum.reduce(amounts, 0, fn
        %__MODULE__{cents: cents, currency: ^currency}, acc ->
          acc + cents

        %__MODULE__{currency: other_currency}, _acc ->
          raise ArgumentError,
                "Cannot sum amounts in different currencies: #{currency} and #{other_currency}"
      end)

    %__MODULE__{cents: total_cents, currency: currency}
  end

  @doc """
  Returns a zero amount in the default currency.
  """
  def zero(currency \\ @default_currency) do
    %__MODULE__{cents: 0, currency: currency}
  end

  # Private helper functions
  # These support the public API with common functionality

  defp currency_config!(currency) do
    Map.get(@currencies, currency) ||
      raise ArgumentError, "Unsupported currency: #{currency}"
  end

  defp convert_to_decimal(value) when is_integer(value), do: D.new(value)
  defp convert_to_decimal(value) when is_float(value), do: D.from_float(value)
  defp convert_to_decimal(%D{} = value), do: value

  defp format_decimal(decimal, decimal_places) do
    # Format as string with proper decimal places
    string = D.to_string(decimal, :normal)

    # Split into integer and decimal parts
    {integer_part, decimal_part} =
      case String.split(string, ".") do
        [int] -> {int, String.duplicate("0", decimal_places)}
        [int, dec] -> {int, String.pad_trailing(dec, decimal_places, "0")}
      end

    # Format integer part with thousand separators
    formatted_integer =
      integer_part
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(".")
      |> String.reverse()

    # Combine with decimal part using comma as separator
    "#{formatted_integer},#{decimal_part}"
  end

  # Protocol implementations
  # These integrate Amount with Elixir's standard protocols

  defimpl String.Chars do
    def to_string(amount), do: TidelandLedger.Amount.to_string(amount)
  end
end
