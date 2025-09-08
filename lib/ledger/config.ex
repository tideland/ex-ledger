defmodule TidelandLedger.Config do
  @moduledoc """
  Centralized configuration access for the Ledger application.

  This module provides a consistent interface to access configuration values
  from various sources (application config, environment variables, TOML files).
  All configuration access should go through this module to ensure consistency
  and make it easier to change configuration sources in the future.

  Configuration values can come from:
  1. Compile-time application config (config/config.exs)
  2. Runtime configuration (config/runtime.exs)
  3. TOML configuration files
  4. Environment variables (with LEDGER_ prefix)
  """

  # Account-related configuration
  # These settings control account management behavior

  @doc """
  Returns the number of days to check for recent transactions
  when deactivating an account.

  Default: 30 days
  """
  @spec recent_transaction_days() :: pos_integer()
  def recent_transaction_days do
    get_config([:accounts, :recent_transaction_days], 30)
  end

  @doc """
  Returns the maximum depth allowed for account hierarchies.

  Default: 6 levels
  """
  @spec max_account_depth() :: pos_integer()
  def max_account_depth do
    get_config([:accounts, :max_depth], 6)
  end

  # Amount-related configuration
  # These settings control monetary calculations

  @doc """
  Returns the default currency code.

  Default: "EUR"
  """
  @spec default_currency() :: String.t()
  def default_currency do
    get_config([:amount, :default_currency], "EUR")
  end

  @doc """
  Returns the number of decimal places for the default currency.

  Default: 2
  """
  @spec currency_precision() :: non_neg_integer()
  def currency_precision do
    get_config([:amount, :precision], 2)
  end

  # Transaction-related configuration
  # These settings control transaction processing

  @doc """
  Returns whether to allow backdated transactions.

  Default: true
  """
  @spec allow_backdated_transactions?() :: boolean()
  def allow_backdated_transactions? do
    get_config([:transactions, :allow_backdated], true)
  end

  @doc """
  Returns the maximum number of days a transaction can be backdated.

  Default: 365 days
  """
  @spec max_backdate_days() :: pos_integer()
  def max_backdate_days do
    get_config([:transactions, :max_backdate_days], 365)
  end

  @doc """
  Returns the maximum number of positions allowed in a single transaction.

  Default: 100
  """
  @spec max_transaction_positions() :: pos_integer()
  def max_transaction_positions do
    get_config([:transactions, :max_positions], 100)
  end

  # Period closing configuration
  # These settings control period management

  @doc """
  Returns whether period closing is enabled.

  Default: true
  """
  @spec period_closing_enabled?() :: boolean()
  def period_closing_enabled? do
    get_config([:periods, :closing_enabled], true)
  end

  @doc """
  Returns the types of periods that can be closed.

  Default: [:month, :quarter, :year]
  """
  @spec closable_period_types() :: [atom()]
  def closable_period_types do
    get_config([:periods, :closable_types], [:month, :quarter, :year])
  end

  # Database configuration
  # These settings control database behavior

  @doc """
  Returns the SQLite journal mode.

  Default: "WAL" for better concurrency
  """
  @spec sqlite_journal_mode() :: String.t()
  def sqlite_journal_mode do
    get_config([:database, :journal_mode], "WAL")
  end

  @doc """
  Returns the SQLite synchronous setting.

  Default: "NORMAL" for good balance of safety and performance
  """
  @spec sqlite_synchronous() :: String.t()
  def sqlite_synchronous do
    get_config([:database, :synchronous], "NORMAL")
  end

  @doc """
  Returns the SQLite busy timeout in milliseconds.

  Default: 5000 (5 seconds)
  """
  @spec sqlite_busy_timeout() :: pos_integer()
  def sqlite_busy_timeout do
    get_config([:database, :busy_timeout], 5000)
  end

  # Authentication configuration
  # These settings control the built-in authentication system

  @doc """
  Returns the password minimum length.

  Default: 12 characters
  """
  @spec password_min_length() :: pos_integer()
  def password_min_length do
    get_config([:auth, :password_min_length], 12)
  end

  @doc """
  Returns the session timeout in minutes.

  Default: 30 minutes
  """
  @spec session_timeout_minutes() :: pos_integer()
  def session_timeout_minutes do
    get_config([:auth, :session_timeout_minutes], 30)
  end

  @doc """
  Returns the maximum failed login attempts before lockout.

  Default: 5 attempts
  """
  @spec max_failed_attempts() :: pos_integer()
  def max_failed_attempts do
    get_config([:auth, :max_failed_attempts], 5)
  end

  @doc """
  Returns the account lockout duration in minutes.

  Default: 15 minutes
  """
  @spec lockout_duration_minutes() :: pos_integer()
  def lockout_duration_minutes do
    get_config([:auth, :lockout_duration_minutes], 15)
  end

  @doc """
  Returns the password hashing algorithm.

  Default: "argon2"
  """
  @spec password_algorithm() :: String.t()
  def password_algorithm do
    get_config([:auth, :password_algorithm], "argon2")
  end

  @doc """
  Returns whether sliding session expiration is enabled.

  Default: true
  """
  @spec session_sliding_expiration?() :: boolean()
  def session_sliding_expiration? do
    get_config([:auth, :session_sliding_expiration], true)
  end

  # Import/Export configuration
  # These settings control data import and export

  @doc """
  Returns the maximum file size for imports in bytes.

  Default: 10_485_760 (10 MB)
  """
  @spec max_import_file_size() :: pos_integer()
  def max_import_file_size do
    get_config([:import, :max_file_size], 10_485_760)
  end

  @doc """
  Returns the batch size for import processing.

  Default: 100 records
  """
  @spec import_batch_size() :: pos_integer()
  def import_batch_size do
    get_config([:import, :batch_size], 100)
  end

  @doc """
  Returns supported export formats.

  Default: [:csv, :json]
  """
  @spec export_formats() :: [atom()]
  def export_formats do
    get_config([:export, :formats], [:csv, :json])
  end

  # UI/UX configuration
  # These settings control user interface behavior

  @doc """
  Returns the number of items per page in lists.

  Default: 50
  """
  @spec items_per_page() :: pos_integer()
  def items_per_page do
    get_config([:ui, :items_per_page], 50)
  end

  @doc """
  Returns the session timeout in seconds.

  Default: 1800 (30 minutes)
  """
  @spec session_timeout() :: pos_integer()
  def session_timeout do
    get_config([:ui, :session_timeout], 1800)
  end

  @doc """
  Returns the default date format for display.

  Default: "%d.%m.%Y" (German format)
  """
  @spec date_format() :: String.t()
  def date_format do
    get_config([:ui, :date_format], "%d.%m.%Y")
  end

  @doc """
  Returns the default datetime format for display.

  Default: "%d.%m.%Y %H:%M" (German format)
  """
  @spec datetime_format() :: String.t()
  def datetime_format do
    get_config([:ui, :datetime_format], "%d.%m.%Y %H:%M")
  end

  # Private helper functions
  # These handle the actual configuration retrieval

  defp get_config(path, default) when is_list(path) do
    # First try environment variable
    env_var = build_env_var_name(path)

    case System.get_env(env_var) do
      nil ->
        # Then try application config
        get_app_config(path, default)

      value ->
        # Parse environment variable based on expected type
        parse_env_value(value, default)
    end
  end

  defp get_app_config([root | rest], default) do
    Application.get_env(:ledger, root, [])
    |> get_in_keyword(rest, default)
  end

  defp get_in_keyword(config, [], _default) when is_list(config), do: config
  defp get_in_keyword(config, [], default), do: default

  defp get_in_keyword(config, [key | rest], default) when is_list(config) do
    config
    |> Keyword.get(key, [])
    |> get_in_keyword(rest, default)
  end

  defp get_in_keyword(_config, _path, default), do: default

  defp build_env_var_name(path) do
    path
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.upcase/1)
    |> Enum.join("_")
    |> then(&"LEDGER_#{&1}")
  end

  defp parse_env_value(value, default) when is_boolean(default) do
    case String.downcase(value) do
      "true" -> true
      "false" -> false
      "1" -> true
      "0" -> false
      _ -> default
    end
  end

  defp parse_env_value(value, default) when is_integer(default) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp parse_env_value(value, default) when is_list(default) do
    # For lists, expect comma-separated values
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  rescue
    _ -> default
  end

  defp parse_env_value(value, _default), do: value

  # TOML configuration support
  # This will be implemented when TOML config files are added

  @doc """
  Loads configuration from a TOML file.

  This function is intended to be called during application startup
  to merge TOML configuration with existing application config.
  """
  @spec load_toml_config(String.t()) :: :ok | {:error, term()}
  def load_toml_config(path) do
    # TODO: Implement TOML configuration loading
    # This will use the :toml library to parse config files
    # and merge them with Application config
    :ok
  end
end
