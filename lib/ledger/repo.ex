defmodule TidelandLedger.Repo do
  use Ecto.Repo,
    otp_app: :tideland_ledger,
    adapter: Ecto.Adapters.SQLite3

  @doc """
  Dynamically loads the repository url from the TIDELAND_LEDGER_DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("TIDELAND_LEDGER_DATABASE_URL"))}
  end
end
