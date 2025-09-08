defmodule TidelandLedger do
  @moduledoc """
  TidelandLedger keeps the contexts that define your domain and business logic.

  Contexts are also responsible for managing your data, regardless if it comes from the database,
  an external API or others.
  """

  @doc """
  Returns the version of the TidelandLedger application.
  """
  def version do
    Application.spec(:tideland_ledger, :vsn) |> to_string()
  end

  @doc """
  Returns build information for the TidelandLedger application.
  """
  def build_info do
    %{
      version: version(),
      git_sha: git_sha(),
      build_date: build_date(),
      elixir_version: System.version(),
      otp_version: System.otp_release()
    }
  end

  defp git_sha do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"]) do
      {sha, 0} -> String.trim(sha)
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end

  defp build_date do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
