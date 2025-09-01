defmodule Ledger.AmountTest do
  use ExUnit.Case, async: true
  alias Ledger.Amount
  alias Decimal, as: D

  describe "creation and parsing" do
    test "new/1 creates amount from integer" do
      amount = Amount.new(123)
      assert amount.cents == 12300
      assert amount.currency == "EUR"
    end

    test "new/1 creates amount from float" do
      amount = Amount.new(123.45)
      assert amount.cents == 12345
      assert amount.currency == "EUR"
    end

    test "new/1 creates amount from Decimal" do
      amount = Amount.new(D.new("123.45"))
      assert amount.cents == 12345
      assert amount.currency == "EUR"
    end

    test "new/1 applies banker's rounding" do
      # Banker's rounding rounds to nearest even number
      # 1.24
      assert Amount.new(1.235).cents == 124
      # 1.24 (rounds to even)
      assert Amount.new(1.245).cents == 124
      # 1.26 (rounds to even)
      assert Amount.new(1.255).cents == 126
      # 1.26
      assert Amount.new(1.265).cents == 126
    end

    test "from_cents/1 creates directly from cents" do
      amount = Amount.from_cents(12345)
      assert amount.cents == 12345
      assert amount.currency == "EUR"
    end

    test "parse/1 handles German format" do
      # Standard German format with thousand separator and comma
      {:ok, amount} = Amount.parse("1.234,56")
      assert amount.cents == 123_456

      # Without thousand separator
      {:ok, amount} = Amount.parse("1234,56")
      assert amount.cents == 123_456

      # With spaces as thousand separator
      {:ok, amount} = Amount.parse("1 234,56")
      assert amount.cents == 123_456
    end

    test "parse/1 handles international format" do
      {:ok, amount} = Amount.parse("1234.56")
      assert amount.cents == 123_456

      {:ok, amount} = Amount.parse("1,234.56")
      assert amount.cents == 123_456
    end

    test "parse/1 handles negative amounts" do
      {:ok, amount} = Amount.parse("-1.234,56")
      assert amount.cents == -123_456

      {:ok, amount} = Amount.parse("-1234.56")
      assert amount.cents == -123_456
    end

    test "parse/1 returns error for invalid format" do
      assert {:error, :invalid_format} = Amount.parse("not a number")
      assert {:error, :invalid_format} = Amount.parse("12.34.56")
    end

    test "parse!/1 raises on invalid format" do
      assert_raise ArgumentError, ~r/Invalid amount format/, fn ->
        Amount.parse!("invalid")
      end
    end
  end

  describe "arithmetic operations" do
    test "add/2 adds amounts in same currency" do
      amount1 = Amount.new(100.50)
      amount2 = Amount.new(50.25)
      result = Amount.add(amount1, amount2)

      # 150.75
      assert result.cents == 15075
      assert result.currency == "EUR"
    end

    test "add/2 raises for different currencies" do
      amount1 = Amount.from_cents(10000, "EUR")
      amount2 = Amount.from_cents(5000, "USD")

      assert_raise ArgumentError, ~r/different currencies/, fn ->
        Amount.add(amount1, amount2)
      end
    end

    test "subtract/2 subtracts amounts" do
      amount1 = Amount.new(100)
      amount2 = Amount.new(30)
      result = Amount.subtract(amount1, amount2)

      # 70.00
      assert result.cents == 7000
    end

    test "subtract/2 handles negative results" do
      amount1 = Amount.new(30)
      amount2 = Amount.new(100)
      result = Amount.subtract(amount1, amount2)

      # -70.00
      assert result.cents == -7000
    end

    test "multiply/2 multiplies by integer" do
      amount = Amount.new(10.50)
      result = Amount.multiply(amount, 3)

      # 31.50
      assert result.cents == 3150
    end

    test "multiply/2 multiplies by decimal with rounding" do
      amount = Amount.new(10)
      result = Amount.multiply(amount, 1.5)

      # 15.00
      assert result.cents == 1500
    end

    test "divide/2 divides amount" do
      amount = Amount.new(100)
      result = Amount.divide(amount, 4)

      # 25.00
      assert result.cents == 2500
    end

    test "divide/2 applies banker's rounding" do
      amount = Amount.new(100)

      # 100 / 3 = 33.333...
      result = Amount.divide(amount, 3)
      # 33.33
      assert result.cents == 3333
    end

    test "negate/1 changes sign" do
      amount = Amount.new(100)
      negated = Amount.negate(amount)

      assert negated.cents == -10000

      # Double negation returns to original
      double_negated = Amount.negate(negated)
      assert double_negated.cents == 10000
    end

    test "abs/1 returns absolute value" do
      positive = Amount.new(100)
      negative = Amount.new(-100)

      assert Amount.abs(positive).cents == 10000
      assert Amount.abs(negative).cents == 10000
    end
  end

  describe "distribution" do
    test "distribute/2 splits evenly when possible" do
      amount = Amount.new(100)
      parts = Amount.distribute(amount, 4)

      assert length(parts) == 4
      # Each gets 25.00
      assert Enum.all?(parts, &(&1.cents == 2500))
    end

    test "distribute/2 handles remainder distribution" do
      amount = Amount.new(100)
      parts = Amount.distribute(amount, 3)

      assert length(parts) == 3
      # First part gets the extra cent
      # 33.34
      assert Enum.at(parts, 0).cents == 3334
      # 33.33
      assert Enum.at(parts, 1).cents == 3333
      # 33.33
      assert Enum.at(parts, 2).cents == 3333

      # Sum equals original
      assert Amount.sum(parts).cents == 10000
    end

    test "distribute/2 handles small amounts" do
      amount = Amount.new(0.01)
      parts = Amount.distribute(amount, 3)

      # Only first part gets the cent
      assert Enum.at(parts, 0).cents == 1
      assert Enum.at(parts, 1).cents == 0
      assert Enum.at(parts, 2).cents == 0
    end

    test "distribute_by_ratio/2 distributes proportionally" do
      amount = Amount.new(100)
      parts = Amount.distribute_by_ratio(amount, [0.5, 0.3, 0.2])

      assert length(parts) == 3
      # 50.00
      assert Enum.at(parts, 0).cents == 5000
      # 30.00
      assert Enum.at(parts, 1).cents == 3000
      # 20.00
      assert Enum.at(parts, 2).cents == 2000
    end

    test "distribute_by_ratio/2 handles rounding remainder" do
      amount = Amount.new(100)
      # These ratios don't divide evenly
      parts = Amount.distribute_by_ratio(amount, [0.33, 0.33, 0.34])

      # Sum must equal original
      assert Amount.sum(parts).cents == 10000
    end

    test "distribute_by_ratio/2 normalizes ratios" do
      amount = Amount.new(100)
      # Ratios don't sum to 1.0
      parts = Amount.distribute_by_ratio(amount, [1, 2, 1])

      # 25.00 (1/4)
      assert Enum.at(parts, 0).cents == 2500
      # 50.00 (2/4)
      assert Enum.at(parts, 1).cents == 5000
      # 25.00 (1/4)
      assert Enum.at(parts, 2).cents == 2500
    end
  end

  describe "comparison" do
    test "compare/2 compares equal amounts" do
      amount1 = Amount.new(100)
      amount2 = Amount.new(100)

      assert Amount.compare(amount1, amount2) == :eq
    end

    test "compare/2 compares different amounts" do
      amount1 = Amount.new(100)
      amount2 = Amount.new(50)

      assert Amount.compare(amount1, amount2) == :gt
      assert Amount.compare(amount2, amount1) == :lt
    end

    test "zero?/1 checks for zero amount" do
      assert Amount.zero?(Amount.new(0))
      assert Amount.zero?(Amount.from_cents(0))
      refute Amount.zero?(Amount.new(0.01))
      refute Amount.zero?(Amount.new(-0.01))
    end

    test "positive?/1 and negative?/1" do
      positive = Amount.new(100)
      negative = Amount.new(-100)
      zero = Amount.new(0)

      assert Amount.positive?(positive)
      refute Amount.positive?(negative)
      refute Amount.positive?(zero)

      assert Amount.negative?(negative)
      refute Amount.negative?(positive)
      refute Amount.negative?(zero)
    end
  end

  describe "formatting" do
    test "to_string/1 formats positive amounts" do
      amount = Amount.new(1234.56)
      assert Amount.to_string(amount) == "1.234,56 €"
    end

    test "to_string/1 formats negative amounts" do
      amount = Amount.new(-1234.56)
      assert Amount.to_string(amount) == "-1.234,56 €"
    end

    test "to_string/1 handles zero" do
      amount = Amount.new(0)
      assert Amount.to_string(amount) == "0,00 €"
    end

    test "to_string/1 formats large numbers" do
      amount = Amount.new(1_234_567.89)
      assert Amount.to_string(amount) == "1.234.567,89 €"
    end

    test "String.Chars protocol implementation" do
      amount = Amount.new(100)
      assert to_string(amount) == "100,00 €"
    end

    test "to_decimal/1 converts to Decimal" do
      amount = Amount.new(123.45)
      decimal = Amount.to_decimal(amount)

      assert D.equal?(decimal, D.new("123.45"))
    end
  end

  describe "sum" do
    test "sum/1 adds multiple amounts" do
      amounts = [
        Amount.new(10),
        Amount.new(20),
        Amount.new(30)
      ]

      result = Amount.sum(amounts)
      # 60.00
      assert result.cents == 6000
    end

    test "sum/1 handles empty list" do
      result = Amount.sum([])
      assert result.cents == 0
      assert result.currency == "EUR"
    end

    test "sum/1 raises for mixed currencies" do
      amounts = [
        Amount.from_cents(1000, "EUR"),
        Amount.from_cents(2000, "USD")
      ]

      assert_raise ArgumentError, ~r/different currencies/, fn ->
        Amount.sum(amounts)
      end
    end
  end

  describe "zero" do
    test "zero/0 creates zero amount in default currency" do
      zero = Amount.zero()
      assert zero.cents == 0
      assert zero.currency == "EUR"
    end

    test "zero/1 creates zero amount in specified currency" do
      zero = Amount.zero("USD")
      assert zero.cents == 0
      assert zero.currency == "USD"
    end
  end

  describe "edge cases and precision" do
    test "handles very small amounts" do
      # Less than one cent
      amount = Amount.new(0.001)
      # Rounded down
      assert amount.cents == 0

      # Half cent
      amount = Amount.new(0.005)
      # Banker's rounding to even
      assert amount.cents == 0

      # 1.5 cents
      amount = Amount.new(0.015)
      # Banker's rounding to even
      assert amount.cents == 2
    end

    test "maintains precision in complex calculations" do
      # Simulate a complex financial calculation
      base = Amount.new(100)

      # Apply various operations
      result =
        base
        # Add 19% tax
        |> Amount.multiply(1.19)
        # Split three ways
        |> Amount.divide(3)
        # Recombine
        |> Amount.multiply(3)

      # Due to rounding, might not equal exactly 119.00
      # But should be very close (within 1 cent)
      assert abs(result.cents - 11900) <= 1
    end

    test "distribution never loses cents" do
      # Test with various amounts and part counts
      test_cases = [
        {100, 3},
        {100, 7},
        {1, 3},
        {999, 13}
      ]

      for {amount_value, parts} <- test_cases do
        amount = Amount.new(amount_value)
        distributed = Amount.distribute(amount, parts)
        sum = Amount.sum(distributed)

        assert sum.cents == amount.cents,
               "Distribution of #{amount_value} into #{parts} parts lost cents"
      end
    end
  end
end
