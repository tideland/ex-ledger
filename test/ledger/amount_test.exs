defmodule TidelandLedger.AmountTest do
  use ExUnit.Case, async: true
  doctest TidelandLedger.Amount

  alias TidelandLedger.Amount

  describe "new/2" do
    test "creates amount from integer" do
      amount = Amount.new(100)
      assert amount.cents == 10000
      assert amount.currency == "EUR"
    end

    test "creates amount from float with proper rounding" do
      amount = Amount.new(123.456)
      # banker's rounding
      assert amount.cents == 12346
    end

    test "creates amount from Decimal" do
      decimal = Decimal.new("123.45")
      amount = Amount.new(decimal)
      assert amount.cents == 12345
      assert amount.currency == "EUR"
    end

    test "supports different currencies" do
      amount = Amount.new(100, "USD")
      assert amount.cents == 10000
      assert amount.currency == "USD"
    end

    test "creates equivalent amounts from different input types" do
      decimal = Decimal.new("123.45")

      # Test with Decimal directly
      amount1 = Amount.new(decimal)

      # Test with Float conversion via Decimal.from_float
      float_value = Decimal.to_float(decimal)
      amount2 = Amount.new(Decimal.from_float(float_value))

      # Test with direct integer (12345 cents = 123.45)
      amount3 = Amount.new(12345)

      # Test conversion functions
      to_amount_via_float = fn d ->
        decimal_value = Decimal.to_float(d)
        Amount.new(Decimal.from_float(decimal_value))
      end
      amount4 = to_amount_via_float.(decimal)

      to_amount_direct = fn d -> Amount.new(d) end
      amount5 = to_amount_direct.(decimal)

      # All amounts should be equal
      assert amount1.cents == amount2.cents
      assert amount2.cents == amount3.cents
      assert amount3.cents == amount4.cents
      assert amount4.cents == amount5.cents
      assert amount1.cents == 12345
    end
  end

  describe "from_cents/2" do
    test "creates amount from cents" do
      amount = Amount.from_cents(12345)
      assert amount.cents == 12345
      assert amount.currency == "EUR"
    end
  end

  describe "parse/2" do
    test "parses German format" do
      {:ok, amount} = Amount.parse("1.234,56")
      assert amount.cents == 123_456
    end

    test "parses international format" do
      {:ok, amount} = Amount.parse("1234.56")
      assert amount.cents == 123_456
    end

    test "parses simple numbers" do
      {:ok, amount} = Amount.parse("100")
      assert amount.cents == 10000
    end

    test "returns error for invalid format" do
      assert {:error, :invalid_format} = Amount.parse("invalid")
    end
  end

  describe "arithmetic operations" do
    setup do
      %{
        amount1: Amount.new(100),
        amount2: Amount.new(50),
        amount3: Amount.new(75)
      }
    end

    test "adds amounts", %{amount1: a1, amount2: a2} do
      result = Amount.add(a1, a2)
      # 150.00
      assert result.cents == 15000
    end

    test "subtracts amounts", %{amount1: a1, amount2: a2} do
      result = Amount.subtract(a1, a2)
      # 50.00
      assert result.cents == 5000
    end

    test "multiplies amount by factor" do
      amount = Amount.new(100)
      result = Amount.multiply(amount, 1.5)
      # 150.00
      assert result.cents == 15000
    end

    test "divides amount" do
      amount = Amount.new(100)
      result = Amount.divide(amount, 2)
      # 50.00
      assert result.cents == 5000
    end

    test "negates amount" do
      amount = Amount.new(100)
      result = Amount.negate(amount)
      assert result.cents == -10000
    end

    test "returns absolute value" do
      amount = Amount.new(-100)
      result = Amount.abs(amount)
      assert result.cents == 10000
    end

    test "raises error when adding different currencies" do
      eur_amount = Amount.new(100, "EUR")
      usd_amount = Amount.new(100, "USD")

      assert_raise ArgumentError, fn ->
        Amount.add(eur_amount, usd_amount)
      end
    end
  end

  describe "distribution" do
    test "distributes amount evenly" do
      # 3.00
      amount = Amount.new(300)
      [part1, part2, part3] = Amount.distribute(amount, 3)

      # 1.00
      assert part1.cents == 10000
      # 1.00
      assert part2.cents == 10000
      # 1.00
      assert part3.cents == 10000
    end

    test "distributes amount with remainder" do
      # 1.00
      amount = Amount.new(100)
      [part1, part2, part3] = Amount.distribute(amount, 3)

      # First part gets the extra cent
      # 0.3334 -> 33.34
      assert part1.cents == 3334
      # 0.3333 -> 33.33
      assert part2.cents == 3333
      # 0.3333 -> 33.33
      assert part3.cents == 3333

      # Verify total is preserved
      total = Amount.add(part1, Amount.add(part2, part3))
      assert total.cents == amount.cents
    end

    test "distributes by ratio" do
      # 1.00
      amount = Amount.new(100)
      ratios = [0.5, 0.3, 0.2]
      [part1, part2, part3] = Amount.distribute_by_ratio(amount, ratios)

      # 50.00
      assert part1.cents == 5000
      # 30.00
      assert part2.cents == 3000
      # 20.00
      assert part3.cents == 2000

      # Verify total is preserved
      total = Amount.sum([part1, part2, part3])
      assert total.cents == amount.cents
    end
  end

  describe "comparison" do
    test "compares amounts correctly" do
      amount1 = Amount.new(100)
      amount2 = Amount.new(50)
      amount3 = Amount.new(100)

      assert Amount.compare(amount1, amount2) == :gt
      assert Amount.compare(amount2, amount1) == :lt
      assert Amount.compare(amount1, amount3) == :eq
    end

    test "zero? predicate" do
      assert Amount.zero?(Amount.new(0))
      refute Amount.zero?(Amount.new(1))
    end

    test "positive? predicate" do
      assert Amount.positive?(Amount.new(1))
      refute Amount.positive?(Amount.new(0))
      refute Amount.positive?(Amount.new(-1))
    end

    test "negative? predicate" do
      assert Amount.negative?(Amount.new(-1))
      refute Amount.negative?(Amount.new(0))
      refute Amount.negative?(Amount.new(1))
    end
  end

  describe "sum/1" do
    test "sums empty list" do
      result = Amount.sum([])
      assert Amount.zero?(result)
    end

    test "sums single amount" do
      amount = Amount.new(100)
      result = Amount.sum([amount])
      assert result.cents == amount.cents
    end

    test "sums multiple amounts" do
      amounts = [Amount.new(100), Amount.new(200), Amount.new(300)]
      result = Amount.sum(amounts)
      # 600.00
      assert result.cents == 60000
    end

    test "raises error for mixed currencies" do
      amounts = [Amount.new(100, "EUR"), Amount.new(100, "USD")]

      assert_raise ArgumentError, fn ->
        Amount.sum(amounts)
      end
    end
  end

  describe "formatting" do
    test "formats positive amount" do
      amount = Amount.new(1234.56)
      assert Amount.to_string(amount) == "1.234,56 €"
    end

    test "formats negative amount" do
      amount = Amount.new(-1234.56)
      assert Amount.to_string(amount) == "-1.234,56 €"
    end

    test "formats zero amount" do
      amount = Amount.new(0)
      assert Amount.to_string(amount) == "0,00 €"
    end
  end

  describe "to_decimal/1" do
    test "converts to decimal" do
      amount = Amount.new(123.45)
      decimal = Amount.to_decimal(amount)
      assert Decimal.equal?(decimal, Decimal.new("123.45"))
    end
  end

  describe "zero/1" do
    test "creates zero amount with default currency" do
      zero = Amount.zero()
      assert zero.cents == 0
      assert zero.currency == "EUR"
    end

    test "creates zero amount with specified currency" do
      zero = Amount.zero("USD")
      assert zero.cents == 0
      assert zero.currency == "USD"
    end
  end
end
