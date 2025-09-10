# Simple test script to validate our Decimal/Amount usage
alias TidelandLedger.Amount
alias Decimal, as: D

IO.puts("Testing Amount.new with Decimal vs Float:")

# Test with Decimal directly
decimal = D.new("123.45")
amount1 = Amount.new(decimal)
IO.puts("Amount from Decimal: #{inspect(amount1)}")

# Test with Float conversion - using Decimal.from_float since Decimal.new doesn't accept floats
decimal = D.new("123.45")
float_value = D.to_float(decimal)
amount2 = Amount.new(D.from_float(float_value))
IO.puts("Amount from Float (via Decimal.from_float): #{inspect(amount2)}")

# Test with direct integer
amount3 = Amount.new(12345)
IO.puts("Amount from direct integer: #{inspect(amount3)}")

# Test a template-like conversion
decimal = D.new("123.45")

to_amount = fn decimal ->
  decimal_value = D.to_float(decimal)
  Amount.new(D.from_float(decimal_value))
end

amount4 = to_amount.(decimal)
IO.puts("Amount via to_amount function: #{inspect(amount4)}")

# Test a template-like conversion with direct pass
to_amount_direct = fn decimal ->
  Amount.new(decimal)
end

amount5 = to_amount_direct.(decimal)
IO.puts("Amount via direct pass: #{inspect(amount5)}")

# Verify they're all the same
IO.puts(
  "\nAll amounts are equal: #{amount1 == amount2 && amount2 == amount3 && amount3 == amount4 && amount4 == amount5}"
)
