ExUnit.start()

# Set up database sandbox for tests
Ecto.Adapters.SQL.Sandbox.mode(TidelandLedger.Repo, :manual)

# Import factory functions into test environment
{:ok, _} = Application.ensure_all_started(:ex_machina)
